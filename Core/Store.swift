import SwiftUI
import UIKit
import Observation

struct SavedPC: Codable, Identifiable, Hashable {
    var id: String { address }
    var name: String
    var address: String
}

struct AppSettings: Codable, Equatable {
    var fahrenheit = false
    var clock24 = false
    var keepAwake = true
    var effects = true
    var nightDim = false
    var historyMinutes = 5
    var style: StyleID = .gilded
    var accent: AccentID = .auto
    var cyclePages = false
    var idlePage = "off"   // "off", "clock" or "core": where to rest after a few minutes untouched

    init() {}
    // Older saved settings simply miss the newer keys.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fahrenheit = c.val(Bool.self, .fahrenheit) ?? false
        clock24 = c.val(Bool.self, .clock24) ?? false
        keepAwake = c.val(Bool.self, .keepAwake) ?? true
        effects = c.val(Bool.self, .effects) ?? true
        nightDim = c.val(Bool.self, .nightDim) ?? false
        historyMinutes = c.val(Int.self, .historyMinutes) ?? 5
        style = c.val(StyleID.self, .style) ?? .gilded
        accent = c.val(AccentID.self, .accent) ?? .auto
        cyclePages = c.val(Bool.self, .cyclePages) ?? false
        idlePage = c.val(String.self, .idlePage) ?? "off"
    }
}

enum LinkState: Equatable { case idle, connecting, starting, live, offline }

enum Page: String, CaseIterable, Identifiable {
    case overview, core, performance, music, clock
    var id: String { rawValue }
    var title: String {
        switch self {
        case .overview: return "Overview"
        case .core: return "Core"
        case .performance: return "Performance"
        case .music: return "Music"
        case .clock: return "Clock"
        }
    }
}

/// Something worth noting that happened on the PC (shown in the event log).
struct LogEvent: Identifiable {
    enum Kind { case info, good, warn, alert, music }
    var id = UUID()
    var t: Date
    var kind: Kind
    var text: String

    var symbol: String {
        switch kind {
        case .info: return "circle.fill"
        case .good: return "checkmark.circle.fill"
        case .warn: return "exclamationmark.triangle.fill"
        case .alert: return "flame.fill"
        case .music: return "music.note"
        }
    }
}

/// The highest value seen since the app was opened.
struct Peak {
    var value: Double
    var at: Date
}

struct Peaks {
    var cpu: Peak?
    var gpu: Peak?
    var tcpu: Peak?
    var tgpu: Peak?
    var rx: Peak?
    var power: Peak?

    static func raise(_ p: inout Peak?, _ v: Double?, _ at: Date) {
        guard let v, v.isFinite else { return }
        if let old = p, old.value >= v { return }
        p = Peak(value: v, at: at)
    }
}

/// One line that sums up how the PC is doing.
struct Health {
    var score: Int
    var word: String
    var level: Int   // 0 fine, 1 busy, 2 hot, 3 critical
}

/// Everything the screens show, kept live by polling the PC once a second.
@MainActor @Observable
final class Store {
    var settings: AppSettings
    var pcs: [SavedPC]
    var current: SavedPC?
    var link: LinkState = .idle
    var snap: Snapshot?
    var media: MediaInfo?
    var audio: AudioInfo?
    var apiVersion = 2
    var samples: [Sample] = []
    var art: UIImage?
    var artKey: String?
    var artTint: Color = Theme.ember
    var page: Page = .overview
    var showSettings = false
    var showConnect = false
    var volumeDragging = false
    var events: [LogEvent] = []
    var peaks = Peaks()
    var energyWh = 0.0
    var settingsInline = false   // screenshots only: show Settings as a full page

    let demo: Bool

    @ObservationIgnored private var poll: Task<Void, Never>?
    @ObservationIgnored private var failures = 0
    @ObservationIgnored private var offset: Double = 0 // PC clock minus iPad clock, ms
    @ObservationIgnored private var lastTime: Double = 0
    @ObservationIgnored private var mediaHold = Date.distantPast
    @ObservationIgnored private var volumeHold = Date.distantPast
    @ObservationIgnored private var lastVolumeSend = Date.distantPast
    @ObservationIgnored private var artLoading: String?
    @ObservationIgnored private var dimmedFrom: CGFloat?
    @ObservationIgnored private var nightTimer: Timer?
    @ObservationIgnored private var demoFeed: DemoFeed?
    @ObservationIgnored private var lastTouch = Date()
    @ObservationIgnored private var lastCycle = Date()
    @ObservationIgnored private var rested = false
    @ObservationIgnored private var houseTimer: Timer?
    @ObservationIgnored private var busyFor = 0
    @ObservationIgnored private var flagged: Set<String> = []
    @ObservationIgnored private var lastSampleAt: Date?

    private static let settingsKey = "settings.v1", pcsKey = "pcs.v1", currentKey = "current.v1"

    init() {
        let args = ProcessInfo.processInfo.arguments
        demo = args.contains("-demo")
        let d = UserDefaults.standard
        settings = (d.data(forKey: Self.settingsKey)).flatMap { try? JSONDecoder().decode(AppSettings.self, from: $0) } ?? AppSettings()
        pcs = (d.data(forKey: Self.pcsKey)).flatMap { try? JSONDecoder().decode([SavedPC].self, from: $0) } ?? []
        if let addr = d.string(forKey: Self.currentKey) { current = pcs.first { $0.address == addr } }
        if demo { startDemo(args) }
        Theme.apply(settings)
    }

    // MARK: Settings

    func binding<T>(_ kp: WritableKeyPath<AppSettings, T>) -> Binding<T> {
        Binding(get: { self.settings[keyPath: kp] }, set: { v in
            self.settings[keyPath: kp] = v
            self.saveSettings()
        })
    }

    func saveSettings() {
        if !demo, let data = try? JSONEncoder().encode(settings) { UserDefaults.standard.set(data, forKey: Self.settingsKey) }
        Theme.apply(settings)
        applySystem()
    }

    private func savePCs() {
        guard !demo else { return }
        if let data = try? JSONEncoder().encode(pcs) { UserDefaults.standard.set(data, forKey: Self.pcsKey) }
        UserDefaults.standard.set(current?.address, forKey: Self.currentKey)
    }

    /// Keep the screen on, and dim it overnight if asked.
    func applySystem() {
        UIApplication.shared.isIdleTimerDisabled = settings.keepAwake
        nightTimer?.invalidate()
        nightTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkNight() }
        }
        checkNight()
        houseTimer?.invalidate()
        houseTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.housekeeping() }
        }
    }

    /// Any touch on the screen counts as "someone is using it".
    func touched() {
        lastTouch = Date()
        lastCycle = Date()
        rested = false
    }

    /// Cycle through the pages, or settle on a resting page, when nobody is touching the iPad.
    private func housekeeping() {
        guard !demo, current != nil, !showSettings, !showConnect else { return }
        let idle = Date().timeIntervalSince(lastTouch)
        if settings.cyclePages {
            if idle > 20, Date().timeIntervalSince(lastCycle) > 20 {
                lastCycle = Date()
                let all = Page.allCases
                if let i = all.firstIndex(of: page) { page = all[(i + 1) % all.count] }
            }
        } else if settings.idlePage != "off", !rested, idle > 180, let p = Page(rawValue: settings.idlePage) {
            rested = true
            if page != p { page = p }
        }
    }

    func log(_ kind: LogEvent.Kind, _ text: String, at date: Date = Date()) {
        events.append(LogEvent(t: date, kind: kind, text: text))
        if events.count > 40 { events.removeFirst(events.count - 40) }
    }

    private func checkNight() {
        let hour = Calendar.current.component(.hour, from: Date())
        let night = settings.nightDim && (hour >= 22 || hour < 7)
        if night, dimmedFrom == nil {
            dimmedFrom = UIScreen.main.brightness
            UIScreen.main.brightness = 0.08
        } else if !night, let b = dimmedFrom {
            UIScreen.main.brightness = b
            dimmedFrom = nil
        }
    }

    var isNight: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return settings.nightDim && (hour >= 22 || hour < 7)
    }

    // MARK: PCs

    func connect(_ pc: SavedPC) {
        if let i = pcs.firstIndex(where: { $0.address == pc.address }) { pcs[i] = pc } else { pcs.append(pc) }
        current = pc
        savePCs()
        snap = nil; media = nil; audio = nil; samples = []; art = nil; artKey = nil
        lastTime = 0; failures = 0
        events = []; peaks = Peaks(); energyWh = 0; flagged = []; busyFor = 0; lastSampleAt = nil
        link = .connecting
        showConnect = false
        startPolling()
    }

    func forget(_ pc: SavedPC) {
        pcs.removeAll { $0.address == pc.address }
        if current?.address == pc.address {
            current = nil
            poll?.cancel()
            link = .idle
            snap = nil; media = nil; audio = nil
        }
        savePCs()
    }

    func scenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            applySystem()
            startPolling()
        case .background:
            poll?.cancel()
            poll = nil
            if let b = dimmedFrom { UIScreen.main.brightness = b; dimmedFrom = nil }
        default:
            break
        }
    }

    func startPolling() {
        guard !demo, let pc = current else { return }
        poll?.cancel()
        if link == .idle { link = .connecting }
        poll = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.tick(pc)
                let wait: UInt64 = self.link == .offline ? 2_000_000_000 : 1_000_000_000
                try? await Task.sleep(nanoseconds: wait)
            }
        }
    }

    private func tick(_ pc: SavedPC) async {
        let t0 = Date().timeIntervalSince1970 * 1000
        do {
            let p = try await API.stats(pc.address)
            guard !Task.isCancelled, current?.address == pc.address else { return }
            let t1 = Date().timeIntervalSince1970 * 1000
            if let now = p.now { offset = now - (t0 + t1) / 2 }
            failures = 0
            apiVersion = p.api
            guard p.ready else { link = .starting; return }
            apply(p)
        } catch {
            guard !Task.isCancelled else { return }
            failures += 1
            if failures >= 3 {
                if link != .offline { log(.alert, "Lost contact with " + pc.name) }
                link = .offline
            }
        }
    }

    private func apply(_ p: API.Payload) {
        snap = p.snap
        if link != .live {
            log(.good, (link == .offline ? "Back in contact with " : "Connected to ") + p.snap.host)
        }
        link = .live
        if p.snap.host != current?.name, var pc = current, !p.snap.host.isEmpty {
            pc.name = p.snap.host
            current = pc
            if let i = pcs.firstIndex(where: { $0.address == pc.address }) { pcs[i] = pc }
            savePCs()
        }
        if p.time != lastTime {
            lastTime = p.time
            record(p.snap)
        }
        if Date() > mediaHold { setMedia(p.media) }
        if Date() > volumeHold, !volumeDragging { audio = p.audio }
    }

    /// `live` is false while the demo back-fills old history, so that doesn't count as news.
    func record(_ s: Snapshot, at date: Date = Date(), live: Bool = true) {
        samples.append(Sample(t: date, cpu: s.cpu.load, gpu: s.gpus.first?.load, mem: s.mem.pct,
                              rx: s.net.rx, tx: s.net.tx, rd: s.disk.read, wr: s.disk.write,
                              tcpu: s.cpu.temp, tgpu: s.gpus.first?.temp))
        if samples.count > 1800 { samples.removeFirst(samples.count - 1800) }

        Peaks.raise(&peaks.cpu, s.cpu.load, date)
        Peaks.raise(&peaks.gpu, s.gpus.first?.load, date)
        Peaks.raise(&peaks.tcpu, s.cpu.temp, date)
        Peaks.raise(&peaks.tgpu, s.gpus.first?.temp, date)
        Peaks.raise(&peaks.rx, s.net.rx, date)
        Peaks.raise(&peaks.power, s.power, date)
        guard live else { return }

        // Energy: watts times the time since the last reading.
        if let p = s.power, let before = lastSampleAt {
            let dt = min(5, max(0, date.timeIntervalSince(before)))
            energyWh += p * dt / 3600
        }
        lastSampleAt = date
        notice(s)
    }

    /// Say something once when it starts (and once when it clears), not every second.
    private func flag(_ key: String, on: Bool, _ kind: LogEvent.Kind, _ text: String, cleared: String? = nil) {
        if on, !flagged.contains(key) {
            flagged.insert(key)
            log(kind, text)
        } else if !on, flagged.contains(key) {
            flagged.remove(key)
            if let cleared { log(.good, cleared) }
        }
    }

    /// Turn changes in the readings into lines in the event log.
    private func notice(_ s: Snapshot) {
        let cpu = s.cpu.load ?? 0
        let mem = s.mem.pct ?? 0
        if cpu >= 90 { busyFor += 1 } else if cpu < 70 { busyFor = 0 }
        flag("cpu", on: busyFor >= 8, .warn, "Processor flat out at " + Fmt.pct(cpu) + "%",
             cleared: "Processor load back to normal")
        flag("mem", on: mem >= 90, .warn, "Memory nearly full (" + Fmt.pct(mem) + "%)", cleared: "Memory freed up")
        for t in s.temps {
            let level = Fmt.level(t.celsius, t.kind)
            flag("hot." + t.name, on: level >= 2, level >= 3 ? .alert : .warn,
                 t.name + " reached " + Fmt.temp(t.celsius, fahrenheit: settings.fahrenheit),
                 cleared: t.name + " cooled down")
        }
        for d in s.disk.drives {
            flag("full." + d.name, on: d.usedPct >= 95, .warn, "Drive " + d.name + " is almost full")
        }
    }

    /// One line that sums up how the PC is doing.
    var health: Health {
        guard let s = snap else { return Health(score: 0, word: "Waiting for the PC", level: 0) }
        if link == .offline { return Health(score: 0, word: "Out of contact", level: 3) }
        let cpu = s.cpu.load ?? 0
        let mem = s.mem.pct ?? 0
        let worst = s.temps.map { Fmt.level($0.celsius, $0.kind) }.max() ?? 0
        let heat: [Double] = [0, 8, 22, 45]
        var score = 100.0
        score -= max(0, cpu - 60) * 0.5
        score -= max(0, mem - 70) * 0.6
        score -= heat[max(0, min(3, worst))]
        if s.disk.drives.contains(where: { $0.usedPct >= 95 }) { score -= 6 }
        let sc = Int(max(0, min(100, score)).rounded())
        if worst >= 3 { return Health(score: sc, word: "Critical heat", level: 3) }
        if worst == 2 { return Health(score: sc, word: "Running hot", level: 2) }
        if cpu >= 85 { return Health(score: sc, word: "Under heavy load", level: 1) }
        if mem >= 90 { return Health(score: sc, word: "Memory nearly full", level: 1) }
        if cpu >= 50 { return Health(score: sc, word: "Working hard", level: 0) }
        return Health(score: sc, word: "All systems nominal", level: 0)
    }

    /// The last `minutes` of history, thinned to at most `maxPoints` for drawing.
    func history(minutes: Int, maxPoints: Int = 240) -> [Sample] {
        let cutoff = Date().addingTimeInterval(-Double(minutes) * 60)
        let recent = samples.filter { $0.t >= cutoff }
        guard recent.count > maxPoints else { return recent }
        let step = Double(recent.count) / Double(maxPoints)
        return (0..<maxPoints).map { recent[min(recent.count - 1, Int(Double($0) * step))] }
    }

    // MARK: Music

    private func setMedia(_ m: MediaInfo?) {
        let trackChanged = m?.id != media?.id || m?.title != media?.title || m?.artist != media?.artist
        if trackChanged, let m, !m.title.isEmpty { logTrack(m) }
        if media != m { media = m }
        guard let key = m?.art else {
            if m == nil || trackChanged { art = nil; artKey = nil }
            return
        }
        guard key != artKey, key != artLoading, let pc = current else { return }
        artLoading = key
        Task {
            let result = await API.art(pc.address, key: key)
            self.artLoading = nil
            guard self.media?.art == key, let result else { return }
            withAnimation(.easeInOut(duration: 0.6)) {
                self.art = result.image
                self.artKey = key
                self.artTint = Color(result.tint)
            }
        }
    }

    var serverNow: Double { Date().timeIntervalSince1970 * 1000 + offset }

    /// Where the song is right now (the PC only reports position now and then).
    func position(at date: Date) -> Double? {
        guard let m = media, let pos = m.pos, let dur = m.dur, dur > 0 else { return nil }
        var p = pos
        if m.isPlaying, let upd = m.updated {
            let now = date.timeIntervalSince1970 * 1000 + offset
            p += max(0, now - upd) / 1000 * m.rate
        }
        return min(dur, max(0, p))
    }

    func mediaAction(_ action: String, _ query: [String: String] = [:]) {
        guard var m = media else { return }
        // Show the result straight away; the PC's answer replaces it a moment later.
        switch action {
        case "toggle":
            let now = position(at: Date())
            m.status = m.isPlaying ? "paused" : "playing"
            if let now { m.pos = now; m.updated = serverNow }
        case "seek":
            if let t = Double(query["t"] ?? "") { m.pos = t; m.updated = serverNow }
        case "shuffle":
            m.shuffle = query["on"] == "1"
        case "repeat":
            m.repeatMode = query["mode"]
        default:
            break
        }
        media = m
        mediaHold = Date().addingTimeInterval(2)
        if demo { demoFeed?.mediaAction(action, query, store: self); return }
        guard let pc = current else { return }
        Task {
            let reply: MediaReply? = try? await API.post(pc.address, "/api/media/" + action, query)
            if let reply {
                if let now = reply.now { self.offset = now - Date().timeIntervalSince1970 * 1000 }
                self.mediaHold = Date().addingTimeInterval(action == "next" || action == "prev" ? 0.6 : 0.3)
                if reply.media != nil { self.setMedia(reply.media) }
            } else {
                self.mediaHold = .distantPast
            }
        }
    }

    func selectSource(_ id: String?) {
        mediaAction("select", ["id": id ?? "auto"])
    }

    func setVolume(_ level: Double, final: Bool) {
        let v = max(0, min(100, level))
        if audio == nil { audio = AudioInfo(level: v, muted: false, device: nil) }
        audio?.level = v
        if v > 0 { audio?.muted = false }
        volumeHold = Date().addingTimeInterval(1.5)
        guard final || Date().timeIntervalSince(lastVolumeSend) > 0.12 else { return }
        lastVolumeSend = Date()
        guard !demo, let pc = current else { return }
        Task {
            let reply: AudioReply? = try? await API.post(pc.address, "/api/volume", ["level": String(Int(v.rounded()))])
            if final, let a = reply?.audio, !self.volumeDragging { self.audio = a }
        }
    }

    func toggleMute() {
        guard let a = audio else { return }
        audio?.muted = !a.muted
        volumeHold = Date().addingTimeInterval(1.5)
        guard !demo, let pc = current else { return }
        Task {
            let reply: AudioReply? = try? await API.post(pc.address, "/api/volume", ["mute": a.muted ? "0" : "1"])
            if let r = reply?.audio { self.audio = r }
        }
    }

    // MARK: Alerts

    /// The most urgent temperature warning, if anything is critically hot.
    var heatAlert: String? {
        guard let s = snap else { return nil }
        let worst = s.temps.max { Fmt.level($0.celsius, $0.kind) < Fmt.level($1.celsius, $1.kind) }
        guard let w = worst, Fmt.level(w.celsius, w.kind) >= 3 else { return nil }
        return "\(w.name) is at \(Fmt.temp(w.celsius, fahrenheit: settings.fahrenheit))"
    }

    // MARK: Demo (screenshots and trying the app without a PC)

    private func startDemo(_ args: [String]) {
        let feed = DemoFeed()
        demoFeed = feed
        current = SavedPC(name: "STUDIO-PC", address: "192.168.4.26:8090")
        pcs = [current!, SavedPC(name: "LAPTOP", address: "192.168.4.31:8090")]
        if let i = args.firstIndex(of: "-page"), i + 1 < args.count, let p = Page(rawValue: args[i + 1]) { page = p }
        if args.contains("-fahrenheit") { settings.fahrenheit = true }
        if let i = args.firstIndex(of: "-style"), i + 1 < args.count, let s = StyleID(rawValue: args[i + 1]) { settings.style = s }
        if let i = args.firstIndex(of: "-accent"), i + 1 < args.count, let a = AccentID(rawValue: args[i + 1]) { settings.accent = a }
        if args.contains("-nomusic") { feed.musicOn = false }
        if args.contains("-hot") { feed.hot = true }
        feed.prefill(self)
        feed.start(self)
        if args.contains("-settings") { showSettings = true }
        if args.contains("-settingspage") { settingsInline = true }
        if args.contains("-connect") { showConnect = true }
        if args.contains("-offline") { link = .offline }
    }

    /// Used by the demo feed.
    func demoApply(_ s: Snapshot, media m: MediaInfo?, audio a: AudioInfo?) {
        snap = s
        if link != .offline { link = .live }
        record(s)
        if Date() > mediaHold {
            if let m, m.title != media?.title, !m.title.isEmpty { logTrack(m) }
            media = m
        }
        if Date() > volumeHold, !volumeDragging { audio = a }
    }

    private func logTrack(_ m: MediaInfo) {
        log(.music, m.artist.isEmpty ? "Now playing: " + m.title : "Now playing: " + m.title + " by " + m.artist)
    }

    func demoSetArt(_ image: UIImage?, key: String?) {
        art = image
        artKey = key
        if let image, let c = API.averageColor(image) { artTint = Color(c) }
    }
}
