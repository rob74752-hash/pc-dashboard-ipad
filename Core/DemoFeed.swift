import UIKit

/// Believable fake data for screenshots (-demo). Never used when a real PC is connected.
@MainActor
final class DemoFeed {
    var musicOn = true
    var hot = false

    private var timer: Timer?
    private let start = Date()
    private var media = MediaInfo()
    private var track = 0
    private var audio = AudioInfo(level: 42, muted: false, device: "Speakers (Realtek Audio)")

    private let tracks: [(title: String, artist: String, album: String, dur: Double)] = [
        ("Gilded Hours", "Marlowe Vance", "Late Light", 214),
        ("Brass & Velvet", "The Ondes", "Salon Nights", 247),
        ("Afterglow Avenue", "Sienna Cole", "City of Lamps", 199),
    ]

    func start(_ store: Store) {
        loadTrack(store, pos: 71)
        tick(store)
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self, weak store] _ in
            Task { @MainActor in
                guard let self, let store else { return }
                self.tick(store)
            }
        }
    }

    func prefill(_ store: Store) {
        let now = Date()
        for i in stride(from: 1800, to: 0, by: -1) {
            let t = now.addingTimeInterval(-Double(i))
            store.record(snapshot(t.timeIntervalSince(start)), at: t, live: false)
        }
        // A little believable history for the event log.
        store.energyWh = 412
        store.log(.good, "Connected to STUDIO-PC", at: now.addingTimeInterval(-1680))
        store.log(.warn, "Processor flat out at 97%", at: now.addingTimeInterval(-1130))
        store.log(.warn, "RTX 4070 SUPER reached 86°", at: now.addingTimeInterval(-1090))
        store.log(.good, "RTX 4070 SUPER cooled down", at: now.addingTimeInterval(-860))
        store.log(.good, "Processor load back to normal", at: now.addingTimeInterval(-840))
    }

    private func tick(_ store: Store) {
        let t = Date().timeIntervalSince(start)
        if musicOn, media.isPlaying, let pos = store.position(at: Date()), let dur = media.dur, pos >= dur - 0.5 {
            track = (track + 1) % tracks.count
            loadTrack(store, pos: 0)
        }
        store.demoApply(snapshot(t), media: musicOn ? media : nil, audio: audio)
    }

    func mediaAction(_ action: String, _ query: [String: String], store: Store) {
        let now = Date().timeIntervalSince1970 * 1000
        switch action {
        case "toggle":
            if let p = store.position(at: Date()) { media.pos = p }
            media.updated = now
            media.status = media.isPlaying ? "paused" : "playing"
        case "next":
            track = (track + 1) % tracks.count
            loadTrack(store, pos: 0)
        case "prev":
            if (store.position(at: Date()) ?? 0) > 3 { media.pos = 0; media.updated = now } else {
                track = (track + tracks.count - 1) % tracks.count
                loadTrack(store, pos: 0)
            }
        case "seek":
            media.pos = Double(query["t"] ?? "") ?? 0
            media.updated = now
        case "shuffle":
            media.shuffle = query["on"] == "1"
        case "repeat":
            media.repeatMode = query["mode"]
        default:
            break
        }
        store.demoApply(snapshot(Date().timeIntervalSince(start)), media: media, audio: audio)
    }

    private func loadTrack(_ store: Store, pos: Double) {
        let tr = tracks[track]
        var m = MediaInfo()
        m.id = "Spotify.exe"
        m.app = "Spotify"
        m.title = tr.title
        m.artist = tr.artist
        m.album = tr.album
        m.status = "playing"
        m.pos = pos
        m.dur = tr.dur
        m.updated = Date().timeIntervalSince1970 * 1000
        m.art = "demo\(track)"
        m.shuffle = false
        m.repeatMode = "list"
        m.can = {
            var c = MediaCaps()
            c.play = true; c.pause = true; c.toggle = true; c.next = true; c.prev = true
            c.seek = true; c.shuffle = true; c.repeatMode = true
            return c
        }()
        m.sessions = [
            MediaSessionInfo(id: "Spotify.exe", app: "Spotify", title: tr.title, artist: tr.artist, playing: true),
            MediaSessionInfo(id: "chrome.exe", app: "Chrome", title: "Lo-fi beats to focus to", artist: "YouTube", playing: false),
        ]
        media = m
        store.demoSetArt(Self.cover(track), key: m.art)
    }

    // MARK: Fake hardware

    private func wave(_ t: Double, _ period: Double, _ phase: Double = 0) -> Double { sin(t / period * 2 * .pi + phase) }

    func snapshot(_ t: Double) -> Snapshot {
        var s = Snapshot()
        s.host = "STUDIO-PC"
        s.os = "Windows 11 Pro"
        s.time = Date().timeIntervalSince1970 * 1000
        s.uptime = (3 * 86400 + 4 * 3600 + 17 * 60 + t) * 1000
        s.hasLhm = true

        let base: Double = 24 + 12 * wave(t, 41) + 8 * wave(t, 9, 1) + 5 * wave(t, 3.1, 2)
        let load: Double = max(2, min(100, base + (hot ? 60 : 0)))
        var cpu = CPUInfo()
        cpu.name = "AMD Ryzen 7 7800X3D 8-Core Processor"
        cpu.load = load
        cpu.mhz = 4720 + 160 * wave(t, 13)
        var cores: [Double] = []
        for i in 0..<16 {
            let d = Double(i)
            let swing: Double = 22 * wave(t, 5 + d * 0.7, d)
            let idle: Double = i > 11 ? 14 : 0
            cores.append(max(0, min(100, load + swing - idle)))
        }
        cpu.cores = cores
        cpu.nCores = 8
        cpu.nThreads = 16
        cpu.temp = hot ? 96 : 61 + 6 * wave(t, 60) + load * 0.08
        cpu.power = 58 + load * 0.6
        s.cpu = cpu

        let gl = max(0, min(100, 58 + 22 * wave(t, 23, 0.5) + 6 * wave(t, 4)))
        s.gpus = [GPUInfo(id: "g0", name: "NVIDIA GeForce RTX 4070 SUPER", short: "RTX 4070 SUPER", load: gl,
                          vram: (7.2 + 0.5 * wave(t, 70)) * 1_073_741_824, vramTotal: 12 * 1_073_741_824,
                          temp: hot ? 88 : 64 + gl * 0.06, hot: hot ? 101 : 76 + gl * 0.07, clock: 2610 + 40 * wave(t, 7),
                          power: 96 + gl * 1.3, fan: 1180 + gl * 6)]

        s.mem = MemInfo(used: (18.4 + 0.6 * wave(t, 90)) * 1_073_741_824, total: 32 * 1_073_741_824,
                        commit: 24 * 1_073_741_824, commitLimit: 37 * 1_073_741_824)
        s.disk = DiskInfo(read: max(0, 38e6 + 30e6 * wave(t, 11)), write: max(0, 9e6 + 8e6 * wave(t, 17, 1)),
                          active: max(1, 7 + 6 * wave(t, 11)),
                          drives: [DriveInfo(name: "C:", label: "System", size: 1_000_202_039_296, free: 412_316_860_416),
                                   DriveInfo(name: "D:", label: "Games", size: 2_000_398_934_016, free: 731_291_942_912)],
                          temp: 44)
        s.net = NetInfo(rx: max(0, 6.2e6 + 5.5e6 * wave(t, 19) + 1.2e6 * wave(t, 3)), tx: max(0, 4.1e5 + 3e5 * wave(t, 13, 2)),
                        ping: 14 + 3 * wave(t, 8), ip: "192.168.4.26")
        s.fans = [FanInfo(name: "CPU Fan", rpm: 1160 + load * 4), FanInfo(name: "System Fan #1", rpm: 840),
                  FanInfo(name: "GPU Fan", rpm: 1180 + gl * 6)]
        s.temps = [TempItem(name: "CPU", celsius: cpu.temp ?? 0, kind: .cpu),
                   TempItem(name: "RTX 4070 SUPER", celsius: s.gpus[0].temp ?? 0, kind: .gpu),
                   TempItem(name: "SSD", celsius: 44 + 2 * wave(t, 80), kind: .storage)]
        s.power = (cpu.power ?? 0) + (s.gpus[0].power ?? 0)
        s.procs = [
            ProcInfo(name: "chrome", cpu: 6.4 + 2 * wave(t, 6), mem: 2.9e9),
            ProcInfo(name: "Code", cpu: 3.1 + wave(t, 5), mem: 1.4e9),
            ProcInfo(name: "Spotify", cpu: 1.8, mem: 4.3e8),
            ProcInfo(name: "Discord", cpu: 1.2, mem: 6.1e8),
            ProcInfo(name: "explorer", cpu: 0.6, mem: 2.2e8),
            ProcInfo(name: "OneDrive", cpu: 0.4, mem: 1.6e8),
            ProcInfo(name: "dwm", cpu: 0.3, mem: 1.1e8),
        ]
        return s
    }

    /// Simple abstract album covers so screenshots have art without using anyone's artwork.
    static func cover(_ i: Int) -> UIImage {
        let size = CGSize(width: 600, height: 600)
        let palettes: [[UIColor]] = [
            [UIColor(red: 0.10, green: 0.06, blue: 0.03, alpha: 1), UIColor(red: 0.85, green: 0.55, blue: 0.25, alpha: 1), UIColor(red: 0.98, green: 0.86, blue: 0.55, alpha: 1)],
            [UIColor(red: 0.05, green: 0.06, blue: 0.10, alpha: 1), UIColor(red: 0.42, green: 0.18, blue: 0.22, alpha: 1), UIColor(red: 0.93, green: 0.73, blue: 0.52, alpha: 1)],
            [UIColor(red: 0.03, green: 0.08, blue: 0.08, alpha: 1), UIColor(red: 0.20, green: 0.42, blue: 0.40, alpha: 1), UIColor(red: 0.95, green: 0.80, blue: 0.48, alpha: 1)],
        ]
        let p = palettes[i % palettes.count]
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [p[0].cgColor, p[1].cgColor] as CFArray, locations: [0.35, 1])!
            cg.drawLinearGradient(grad, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: size.height), options: [])
            // a low sun
            let sun = CGRect(x: 150, y: 250, width: 300, height: 300)
            cg.setFillColor(p[2].cgColor)
            cg.fillEllipse(in: sun)
            // horizon bands cut through it
            cg.setFillColor(p[1].withAlphaComponent(0.95).cgColor)
            for k in 0..<7 {
                let y = 430 + CGFloat(k) * 18
                cg.fill(CGRect(x: 0, y: y, width: size.width, height: CGFloat(3 + k * 2)))
            }
            cg.setFillColor(p[0].withAlphaComponent(0.85).cgColor)
            cg.fill(CGRect(x: 0, y: 560, width: size.width, height: 40))
        }
    }
}
