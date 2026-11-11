import SwiftUI

/// A quiet nightstand view: a huge gold clock, the PC's vital signs on one line, and the song.
struct ClockPage: View {
    @Environment(Store.self) private var store

    var body: some View {
        GeometryReader { g in
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                let c = Fmt.clock(ctx.date, h24: store.settings.clock24)
                let size = min(g.size.width * 0.25, g.size.height * 0.42, 250)
                VStack(spacing: 0) {
                    Spacer(minLength: 20)
                    Eyebrow(Fmt.dateLine(ctx.date))
                        .padding(.bottom, 6)
                    HStack(alignment: .firstTextBaseline, spacing: size * 0.08) {
                        BigNumber(value: c.hm, size: size, solid: true)
                        VStack(alignment: .leading, spacing: size * 0.08) {
                            Text(c.s)
                                .font(.display(size * 0.16, weight: .regular).monospacedDigit())
                                .foregroundStyle(Theme.gold)
                                .contentTransition(.numericText())
                            if !c.ampm.isEmpty {
                                Text(c.ampm)
                                    .font(Theme.d.text(size * 0.1, .semibold))
                                    .tracking(2)
                                    .foregroundStyle(Theme.text3)
                            }
                        }
                    }
                    .animation(.smooth(duration: 0.4), value: c.s)
                    Vitals()
                        .padding(.top, 18)
                    Spacer(minLength: 20)
                    if store.media != nil {
                        NowPlayingStrip()
                            .frame(maxWidth: 640)
                            .padding(.bottom, 28)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 32)
                .opacity(store.isNight ? 0.6 : 1)
            }
        }
    }
}

/// CPU · GPU · temperature · download, as a single gold-ruled line.
struct Vitals: View {
    @Environment(Store.self) private var store

    var body: some View {
        let s = store.snap ?? Snapshot()
        let f = store.settings.fahrenheit
        HStack(spacing: 0) {
            item("CPU", Fmt.pct(s.cpu.load) + "%")
            divider
            item("GPU", Fmt.pct(s.gpus.first?.load) + "%")
            divider
            item("CPU temp", Fmt.temp(s.cpu.temp, fahrenheit: f), color: Theme.levelColor(max(0, Fmt.level(s.cpu.temp, .cpu))))
            divider
            item("Memory", Fmt.pct(s.mem.pct) + "%")
            divider
            item("Down", Fmt.bitsText(s.net.rx))
        }
    }

    private var divider: some View {
        Rectangle().fill(Theme.hairline).frame(width: 1, height: 30).padding(.horizontal, 22)
    }

    private func item(_ label: String, _ value: String, color: Color = Theme.ivory) -> some View {
        VStack(spacing: 5) {
            Eyebrow(label, color: Theme.text3)
            Text(value)
                .font(Theme.d.text(19, .medium).monospacedDigit())
                .foregroundStyle(color == Theme.signal ? Theme.ivory : color)
                .contentTransition(.numericText())
        }
        .fixedSize()
    }
}

struct NowPlayingStrip: View {
    @Environment(Store.self) private var store

    var body: some View {
        if let m = store.media {
            HStack(spacing: 16) {
                Artwork(size: 58)
                VStack(alignment: .leading, spacing: 3) {
                    Text(m.title).font(Theme.d.text(16, .semibold)).foregroundStyle(Theme.ivory).lineLimit(1)
                    Text(m.artist).font(.ui).foregroundStyle(Theme.gold).lineLimit(1)
                    SongProgress(showTimes: false).padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                RingButton(symbol: "backward.fill", size: 40, enabled: m.can.prev) { store.mediaAction("prev") }
                RingButton(symbol: m.isPlaying ? "pause.fill" : "play.fill", size: 50, filled: true) { store.mediaAction("toggle") }
                RingButton(symbol: "forward.fill", size: 40, enabled: m.can.next) { store.mediaAction("next") }
            }
            .padding(14)
            .overlay(Theme.box.strokeBorder(Theme.hairline, lineWidth: 1))
        }
    }
}
