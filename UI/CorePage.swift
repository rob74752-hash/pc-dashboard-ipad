import SwiftUI

/// The showpiece: the look's 3D object, large, turning faster the harder the PC works, with
/// the six numbers that matter around it and one line that says how the PC is doing.
struct CorePage: View {
    @Environment(Store.self) private var store

    var body: some View {
        GeometryReader { g in
            if store.snap == nil {
                Waiting()
            } else if g.size.width > g.size.height {
                landscape(g.size)
            } else {
                portrait(g.size)
            }
        }
    }

    private func landscape(_ size: CGSize) -> some View {
        let side = max(160, min(size.height - 190, size.width * 0.44))
        return VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
                VStack(alignment: .leading, spacing: 26) {
                    CoreStat(kind: .cpu)
                    CoreStat(kind: .gpu)
                    CoreStat(kind: .memory)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                centre(side)
                VStack(alignment: .leading, spacing: 26) {
                    CoreStat(kind: .temp)
                    CoreStat(kind: .power)
                    CoreStat(kind: .network)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 26)
            }
            .frame(maxHeight: .infinity)
            pulse
        }
        .padding(.horizontal, 34)
        .padding(.top, 14)
        .padding(.bottom, 18)
    }

    private func portrait(_ size: CGSize) -> some View {
        let side = max(160, min(size.width - 160, size.height * 0.40))
        return ScrollView {
            VStack(spacing: 26) {
                centre(side)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 26), GridItem(.flexible(), spacing: 26)], spacing: 26) {
                    CoreStat(kind: .cpu)
                    CoreStat(kind: .temp)
                    CoreStat(kind: .gpu)
                    CoreStat(kind: .power)
                    CoreStat(kind: .memory)
                    CoreStat(kind: .network)
                }
                pulse
            }
            .padding(30)
        }
        .scrollIndicators(.hidden)
    }

    /// The object with the verdict under it.
    private func centre(_ side: CGFloat) -> some View {
        let h = store.health
        let tone: Color = h.level >= 3 ? Theme.critical : (h.level == 2 ? Theme.hot : Theme.ivory)
        return VStack(spacing: 10) {
            ZStack {
                HeroObject()
                    .frame(width: side, height: side)
                if Theme.style == .apex {
                    VStack(spacing: 2) {
                        BigNumber(value: Fmt.pct(store.snap?.cpu.load), size: side * 0.26)
                        Eyebrow("Processor load %", color: Theme.text3)
                    }
                    .offset(y: side * 0.20)
                }
                if Theme.style == .cyber {
                    CornerBrackets(color: Theme.label.opacity(0.8), length: 18)
                        .frame(width: side * 0.96, height: side * 0.96)
                }
            }
            .frame(width: side, height: side)
            VStack(spacing: 6) {
                Text(Theme.style == .cyber || Theme.style == .apex ? h.word.uppercased() : h.word)
                    .font(wordFont)
                    .tracking(Theme.style == .cyber ? 3 : (Theme.style == .gilded ? 0.5 : 0))
                    .foregroundStyle(tone)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.opacity)
                HStack(spacing: 8) {
                    Eyebrow("Health", color: Theme.text3)
                    Text("\(h.score)")
                        .font(Theme.d.text(15, .semibold).monospacedDigit())
                        .foregroundStyle(Theme.gold)
                        .contentTransition(.numericText())
                    Meter(value: Double(h.score), color: h.level >= 2 ? tone : nil, height: 3)
                        .frame(width: 90)
                }
            }
            .animation(.easeInOut(duration: 0.4), value: h.word)
        }
    }

    private var wordFont: Font {
        switch Theme.style {
        case .apex: return .system(size: 30, weight: .bold).width(.compressed)
        case .cyber: return Theme.d.text(19, .bold)
        case .reactor: return .system(size: 26, weight: .semibold)
        case .molten: return .system(size: 26, weight: .bold)
        case .paper: return .system(size: 26, weight: .light)
        default: return Theme.d.text(22, .semibold)
        }
    }

    /// The last two minutes of processor load, as one long line across the bottom.
    private var pulse: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Eyebrow("Processor, last two minutes", color: Theme.text3)
                Spacer()
                Text(store.current?.name ?? "")
                    .font(.small)
                    .foregroundStyle(Theme.text3)
            }
            Sparkline(values: store.recent(120, \.cpu), maxValue: 100)
                .frame(height: 46)
        }
    }
}

/// One of the six numbers around the object.
struct CoreStat: View {
    enum Kind { case cpu, gpu, memory, temp, power, network }
    @Environment(Store.self) private var store
    var kind: Kind

    var body: some View {
        let s = store.snap ?? Snapshot()
        let f = store.settings.fahrenheit
        VStack(alignment: .leading, spacing: 7) {
            switch kind {
            case .cpu:
                Eyebrow("Processor")
                BigNumber(value: Fmt.pct(s.cpu.load), unit: "%", size: 48)
                Meter(value: s.cpu.load ?? 0)
                note(Fmt.ghz(s.cpu.mhz) + " GHz")
            case .gpu:
                let g = s.gpus.first
                Eyebrow("Graphics")
                BigNumber(value: Fmt.pct(g?.load), unit: "%", size: 48)
                Meter(value: g?.load ?? 0)
                note(Fmt.gb(g?.vram) + " of " + Fmt.gb(g?.vramTotal, digits: 0) + " GB video memory")
            case .memory:
                Eyebrow("Memory")
                BigNumber(value: Fmt.pct(s.mem.pct), unit: "%", size: 48)
                Meter(value: s.mem.pct ?? 0)
                note(Fmt.gb(s.mem.used) + " of " + Fmt.gb(s.mem.total, digits: 0) + " GB in use")
            case .temp:
                let level = Fmt.level(s.cpu.temp, .cpu)
                Eyebrow("Processor heat")
                BigNumber(value: Fmt.tempValue(s.cpu.temp, fahrenheit: f).map { String($0) } ?? "--", unit: f ? "°F" : "°C",
                          size: 48, color: level >= 2 ? Theme.levelColor(level) : nil)
                Meter(value: min(100, s.cpu.temp ?? 0), color: level >= 1 ? Theme.levelColor(level) : nil)
                note("Graphics " + Fmt.temp(s.gpus.first?.temp, fahrenheit: f))
            case .power:
                Eyebrow("Power draw")
                BigNumber(value: Fmt.watts(s.power), unit: "W", size: 48)
                Meter(value: min(100, (s.power ?? 0) / 6))
                note(energyLine)
            case .network:
                let down = Fmt.bits(s.net.rx)
                Eyebrow("Download")
                BigNumber(value: down.0, unit: down.1, size: 48)
                Sparkline(values: store.recent(60, \.rx), fill: false)
                    .frame(height: 14)
                    .padding(.vertical, -5.5)
                note("Up " + Fmt.bitsText(s.net.tx))
            }
        }
        .frame(maxWidth: 230, alignment: .leading)
    }

    private var energyLine: String {
        let e = Fmt.energy(store.energyWh)
        return e.0 + " " + e.1 + " used so far"
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.small.monospacedDigit())
            .foregroundStyle(Theme.text3)
            .lineLimit(1)
    }
}
