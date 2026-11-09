import SwiftUI

struct OverviewPage: View {
    @Environment(Store.self) private var store

    var body: some View {
        GeometryReader { g in
            let pad: CGFloat = 16
            let gap = Theme.gap
            let w = g.size.width - pad * 2
            let h = g.size.height - pad * 2
            if store.snap == nil {
                Waiting()
            } else if g.size.width > g.size.height {
                // Landscape (the iPad on a stand)
                let r1 = (h - gap * 2) * 0.44
                let r2 = (h - gap * 2) * 0.26
                let r3 = h - gap * 2 - r1 - r2
                VStack(spacing: gap) {
                    HStack(spacing: gap) {
                        CPUHero().frame(width: (w - gap * 2) * 0.46)
                        GPUCard().frame(width: (w - gap * 2) * 0.25)
                        NowPlayingCard()
                    }
                    .frame(height: r1)
                    HStack(spacing: gap) {
                        MemoryCard()
                        NetworkCard()
                        DiskCard()
                        TempsCard()
                    }
                    .frame(height: r2)
                    HStack(spacing: gap) {
                        ProcessesCard().frame(width: (w - gap * 2) * 0.40)
                        DrivesCard()
                        SystemCard()
                    }
                    .frame(height: r3)
                }
                .padding(pad)
            } else {
                // Portrait
                ScrollView {
                    VStack(spacing: gap) {
                        CPUHero().frame(height: 290)
                        HStack(spacing: gap) {
                            GPUCard()
                            NowPlayingCard()
                        }
                        .frame(height: 270)
                        HStack(spacing: gap) { MemoryCard(); NetworkCard() }.frame(height: 176)
                        HStack(spacing: gap) { DiskCard(); TempsCard() }.frame(height: 176)
                        HStack(spacing: gap) {
                            ProcessesCard()
                            VStack(spacing: gap) { DrivesCard(); SystemCard() }
                        }
                        .frame(height: 400)
                    }
                    .padding(pad)
                }
                .scrollIndicators(.hidden)
            }
        }
    }
}

struct Waiting: View {
    @Environment(Store.self) private var store

    var body: some View {
        VStack(spacing: 18) {
            ProgressView().tint(Theme.gold).controlSize(.large)
            Eyebrow("Connecting to " + (store.current?.name ?? "your PC"))
            Text(store.current?.address ?? "")
                .font(.small.monospacedDigit())
                .foregroundStyle(Theme.text3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Shared bits

/// Small "LABEL / value unit" stack used under big numbers.
struct MiniStat: View {
    var label: String
    var value: String
    var unit: String
    var color: Color = Theme.ivory

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Eyebrow(label, color: Theme.text3)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 20, weight: .medium).monospacedDigit())
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
                Text(unit)
                    .font(.small)
                    .foregroundStyle(Theme.text3)
            }
        }
    }
}

/// A tiny history line with a soft gold fill (decorative gradient role).
struct Sparkline: View {
    var values: [Double?]
    var maxValue: Double? = nil
    var color: Color = Theme.gold
    var fill = true

    var body: some View {
        Canvas { ctx, size in
            let pts = values.enumerated().compactMap { i, v -> (Int, Double)? in v.map { (i, $0) } }
            guard pts.count > 1 else { return }
            let top = maxValue ?? max(1, (pts.map { $0.1 }.max() ?? 1) * 1.15)
            let step = size.width / CGFloat(max(1, values.count - 1))
            func p(_ i: Int, _ v: Double) -> CGPoint {
                CGPoint(x: CGFloat(i) * step, y: size.height - CGFloat(min(v, top) / top) * (size.height - 2) - 1)
            }
            var line = Path()
            line.move(to: p(pts[0].0, pts[0].1))
            for q in pts.dropFirst() { line.addLine(to: p(q.0, q.1)) }
            if fill {
                var area = line
                area.addLine(to: CGPoint(x: p(pts[pts.count - 1].0, 0).x, y: size.height))
                area.addLine(to: CGPoint(x: p(pts[0].0, 0).x, y: size.height))
                area.closeSubpath()
                ctx.fill(area, with: .linearGradient(
                    Gradient(colors: [Theme.ember.opacity(0.30), Theme.ember.opacity(0)]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            }
            ctx.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: 1.4, lineJoin: .round))
        }
    }
}

extension Store {
    func recent(_ seconds: Int, _ kp: KeyPath<Sample, Double?>) -> [Double?] {
        samples.suffix(seconds).map { $0[keyPath: kp] }
    }
}

// MARK: - Processor

struct CPUHero: View {
    @Environment(Store.self) private var store

    var body: some View {
        let s = store.snap ?? Snapshot()
        let f = store.settings.fahrenheit
        let level = Fmt.level(s.cpu.temp, .cpu)
        Card(title: "Processor", trailing: Interpret.shortCPU(s.cpu.name)) {
            HStack(alignment: .bottom, spacing: 22) {
                VStack(alignment: .leading, spacing: 14) {
                    BigNumber(value: Fmt.pct(s.cpu.load), unit: "%", size: 92)
                    HStack(spacing: 26) {
                        MiniStat(label: "Clock", value: Fmt.ghz(s.cpu.mhz), unit: "GHz")
                        MiniStat(label: "Temp", value: Fmt.tempValue(s.cpu.temp, fahrenheit: f).map { String($0) } ?? "--",
                                 unit: f ? "°F" : "°C", color: level >= 2 ? Theme.levelColor(level) : Theme.ivory)
                        MiniStat(label: "Power", value: Fmt.watts(s.cpu.power), unit: "W")
                    }
                }
                .layoutPriority(1)
                CoreBars(cores: s.cpu.cores)
                    .frame(maxWidth: 220)
            }
            Sparkline(values: store.recent(120, \.cpu), maxValue: 100)
                .frame(maxHeight: .infinity)
                .frame(minHeight: 30)
        }
    }
}

/// One thin bar per CPU thread, like organ pipes.
struct CoreBars: View {
    var cores: [Double]

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            GeometryReader { g in
                let n = max(1, cores.count)
                let gap: CGFloat = n > 24 ? 2 : 3
                let bw = max(2, (g.size.width - gap * CGFloat(n - 1)) / CGFloat(n))
                HStack(alignment: .bottom, spacing: gap) {
                    ForEach(Array(cores.enumerated()), id: \.offset) { _, v in
                        ZStack(alignment: .bottom) {
                            Rectangle().fill(Theme.track)
                            Rectangle()
                                .fill(v >= 90 ? Theme.aged : Theme.gold)
                                .frame(height: max(1, g.size.height * CGFloat(v / 100)))
                        }
                        .frame(width: bw)
                    }
                }
                .animation(.smooth(duration: 0.7), value: cores)
            }
            Eyebrow("\(cores.count) threads", color: Theme.text3)
        }
        .frame(height: 118)
    }
}

// MARK: - Graphics

struct GPUCard: View {
    @Environment(Store.self) private var store

    var body: some View {
        let s = store.snap ?? Snapshot()
        let f = store.settings.fahrenheit
        if let g = s.gpus.first {
            let level = Fmt.level(g.temp, .gpu)
            Card(title: "Graphics", trailing: g.short) {
                BigNumber(value: Fmt.pct(g.load), unit: "%", size: 60)
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text("Video memory").font(.small).foregroundStyle(Theme.text2)
                        Spacer()
                        Text("\(Fmt.gb(g.vram)) / \(Fmt.gb(g.vramTotal, digits: 0)) GB")
                            .font(.small.monospacedDigit()).foregroundStyle(Theme.ivory)
                    }
                    Meter(value: (g.vram ?? 0) / max(1, g.vramTotal ?? 1) * 100)
                }
                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
                    GridRow {
                        MiniStat(label: "Temp", value: Fmt.tempValue(g.temp, fahrenheit: f).map { String($0) } ?? "--",
                                 unit: f ? "°F" : "°C", color: level >= 2 ? Theme.levelColor(level) : Theme.ivory)
                        MiniStat(label: "Power", value: Fmt.watts(g.power), unit: "W")
                    }
                    GridRow {
                        MiniStat(label: "Clock", value: g.clock.map { String(Int($0)) } ?? "--", unit: "MHz")
                        MiniStat(label: "Hot spot", value: Fmt.tempValue(g.hot, fahrenheit: f).map { String($0) } ?? "--", unit: f ? "°F" : "°C")
                    }
                }
                if s.gpus.count > 1 {
                    let g2 = s.gpus[1]
                    StatRow(label: g2.short, value: Fmt.pct(g2.load), unit: "%")
                }
            }
        } else {
            Card(title: "Graphics") {
                Text("No graphics card reported").font(.ui).foregroundStyle(Theme.text3)
            }
        }
    }
}

// MARK: - Music (small)

struct Artwork: View {
    @Environment(Store.self) private var store
    var size: CGFloat?

    var body: some View {
        ZStack {
            if let img = store.art {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity)
            } else {
                ZStack {
                    Theme.raised
                    Image(systemName: "music.note")
                        .font(.system(size: (size ?? 120) * 0.32, weight: .light))
                        .foregroundStyle(Theme.gold.opacity(0.7))
                }
                .transition(.opacity)
            }
        }
        .frame(width: size, height: size)
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
        .id(store.artKey ?? "none")
    }
}

/// Hairline progress for the current song, ticking between updates from the PC.
struct SongProgress: View {
    @Environment(Store.self) private var store
    var showTimes = true

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
            let pos = store.position(at: ctx.date)
            let dur = store.media?.dur
            VStack(spacing: 6) {
                Meter(value: (pos ?? 0) / max(1, dur ?? 1) * 100, height: 2)
                if showTimes {
                    HStack {
                        Text(Fmt.duration(pos))
                        Spacer()
                        Text(dur.map { "-" + Fmt.duration(max(0, $0 - (pos ?? 0))) } ?? "")
                    }
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(Theme.text3)
                }
            }
            .opacity(dur == nil ? 0 : 1)
        }
    }
}

struct NowPlayingCard: View {
    @Environment(Store.self) private var store

    var body: some View {
        let m = store.media
        Card(title: "Now playing", trailing: m?.app) {
            if let m {
                Button { store.page = .music } label: {
                    HStack(alignment: .center, spacing: 14) {
                        Artwork(size: 84)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(m.title.isEmpty ? "Unknown title" : m.title)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Theme.ivory)
                                .lineLimit(2)
                            Text(m.artist)
                                .font(.ui)
                                .foregroundStyle(Theme.gold)
                                .lineLimit(1)
                            if !m.album.isEmpty {
                                Text(m.album).font(.small).foregroundStyle(Theme.text3).lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
                SongProgress()
                HStack(spacing: 18) {
                    Spacer()
                    RingButton(symbol: "backward.fill", size: 42, enabled: m.can.prev) { store.mediaAction("prev") }
                    RingButton(symbol: m.isPlaying ? "pause.fill" : "play.fill", size: 54, filled: true,
                               enabled: m.can.toggle || m.can.play || m.can.pause) { store.mediaAction("toggle") }
                    RingButton(symbol: "forward.fill", size: 42, enabled: m.can.next) { store.mediaAction("next") }
                    Spacer()
                }
            } else {
                NothingPlaying(compact: true)
            }
        }
    }
}

struct NothingPlaying: View {
    @Environment(Store.self) private var store
    var compact = false

    var body: some View {
        VStack(spacing: compact ? 10 : 16) {
            Image(systemName: store.apiVersion < 2 ? "arrow.down.circle" : "music.note")
                .font(.system(size: compact ? 28 : 44, weight: .ultraLight))
                .foregroundStyle(Theme.gold)
            Text(store.apiVersion < 2 ? "Update PC Dashboard on your PC" : "Nothing playing")
                .font(compact ? .uiMedium : .system(size: 20, weight: .medium))
                .foregroundStyle(Theme.ivory)
            Text(store.apiVersion < 2
                 ? "Copy the new PC Dashboard folder to your PC to see and control music here."
                 : "Play something on your PC (Spotify, a browser, Media Player…) and it shows up here.")
                .font(.small)
                .foregroundStyle(Theme.text3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Second row

struct MemoryCard: View {
    @Environment(Store.self) private var store

    var body: some View {
        let mem = (store.snap ?? Snapshot()).mem
        Card(title: "Memory", trailing: "\(Fmt.gb(mem.total, digits: 0)) GB") {
            BigNumber(value: Fmt.pct(mem.pct), unit: "%", size: 40)
            Meter(value: mem.pct ?? 0)
            Spacer(minLength: 0)
            StatRow(label: "In use", value: Fmt.gb(mem.used), unit: "GB")
        }
    }
}

struct NetworkCard: View {
    @Environment(Store.self) private var store

    var body: some View {
        let n = (store.snap ?? Snapshot()).net
        let down = Fmt.bits(n.rx)
        let up = Fmt.bits(n.tx)
        Card(title: "Network", trailing: n.ping.map { "\(Int($0)) ms" }) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "arrow.down").font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.gold)
                BigNumber(value: down.0, unit: down.1, size: 30)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "arrow.up").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.text3)
                Text(up.0 + " " + up.1)
                    .font(.system(size: 14, weight: .medium).monospacedDigit())
                    .foregroundStyle(Theme.text2)
                    .contentTransition(.numericText())
            }
            Sparkline(values: store.recent(90, \.rx))
                .frame(maxHeight: .infinity)
        }
    }
}

struct DiskCard: View {
    @Environment(Store.self) private var store

    var body: some View {
        let d = (store.snap ?? Snapshot()).disk
        let rd = Fmt.byteRate(d.read)
        let wr = Fmt.byteRate(d.write)
        Card(title: "Disk", trailing: d.active.map { "\(Int($0.rounded()))% busy" }) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Eyebrow("Read", color: Theme.text3)
                BigNumber(value: rd.0, unit: rd.1, size: 30)
            }
            StatRow(label: "Write", value: wr.0, unit: wr.1)
            Sparkline(values: store.recent(90, \.rd))
                .frame(maxHeight: .infinity)
        }
    }
}

struct TempsCard: View {
    @Environment(Store.self) private var store

    var body: some View {
        let s = store.snap ?? Snapshot()
        let f = store.settings.fahrenheit
        Card(title: "Temperatures", trailing: f ? "°F" : "°C") {
            if s.temps.isEmpty {
                Text(s.hasLhm ? "No temperature sensors found." : "Start LibreHardwareMonitor on the PC to see temperatures.")
                    .font(.small)
                    .foregroundStyle(Theme.text3)
                    .frame(maxHeight: .infinity, alignment: .top)
            } else {
                VStack(spacing: 9) {
                    ForEach(s.temps.prefix(3)) { t in
                        let level = Fmt.level(t.celsius, t.kind)
                        VStack(spacing: 5) {
                            HStack {
                                Text(t.name).font(.small).foregroundStyle(Theme.text2).lineLimit(1)
                                Spacer()
                                Text(Fmt.temp(t.celsius, fahrenheit: f))
                                    .font(.system(size: 14, weight: .semibold).monospacedDigit())
                                    .foregroundStyle(level >= 1 ? Theme.levelColor(level) : Theme.ivory)
                                    .contentTransition(.numericText())
                            }
                            Meter(value: min(100, t.celsius), color: Theme.levelColor(level), height: 2)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Third row

struct ProcessesCard: View {
    @Environment(Store.self) private var store

    var body: some View {
        let procs = (store.snap ?? Snapshot()).procs
        Card(title: "Busiest apps", trailing: "CPU · memory") {
            VStack(spacing: 8) {
                ForEach(procs.prefix(6)) { p in
                    HStack(spacing: 12) {
                        Text(p.name)
                            .font(.ui)
                            .foregroundStyle(Theme.ivory)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Meter(value: min(100, p.cpu * 4), height: 2).frame(width: 64)
                        Text(String(format: "%.1f%%", p.cpu))
                            .font(.system(size: 13, weight: .medium).monospacedDigit())
                            .foregroundStyle(Theme.gold)
                            .frame(width: 52, alignment: .trailing)
                        Text(Fmt.bytes(p.mem))
                            .font(.small.monospacedDigit())
                            .foregroundStyle(Theme.text3)
                            .frame(width: 64, alignment: .trailing)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct DrivesCard: View {
    @Environment(Store.self) private var store

    var body: some View {
        let drives = (store.snap ?? Snapshot()).disk.drives
        Card(title: "Drives") {
            VStack(spacing: 12) {
                ForEach(drives.prefix(3)) { d in
                    VStack(spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(d.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.gold)
                            Text(d.label).font(.small).foregroundStyle(Theme.text3).lineLimit(1)
                            Spacer()
                            Text(Fmt.bytes(d.free) + " free").font(.small.monospacedDigit()).foregroundStyle(Theme.text2)
                        }
                        Meter(value: d.usedPct, color: d.usedPct > 90 ? Theme.hot : Theme.gold, height: 2)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

struct SystemCard: View {
    @Environment(Store.self) private var store

    var body: some View {
        let s = store.snap ?? Snapshot()
        Card(title: "System", trailing: s.os) {
            VStack(spacing: 9) {
                StatRow(label: "Up for", value: Fmt.uptime(s.uptime))
                if let p = s.power { StatRow(label: "Power draw", value: Fmt.watts(p), unit: "W") }
                ForEach(s.fans.prefix(2)) { f in
                    StatRow(label: f.name, value: String(Int(f.rpm)), unit: "RPM")
                }
                if let b = s.battery {
                    StatRow(label: b.plugged ? "Battery (charging)" : "Battery", value: String(Int(b.pct)), unit: "%")
                }
            }
            Spacer(minLength: 0)
        }
    }
}
