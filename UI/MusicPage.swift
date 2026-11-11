import SwiftUI

/// The full "listening room": big artwork, scrubber, transport, PC volume and sources.
struct MusicPage: View {
    @Environment(Store.self) private var store

    var body: some View {
        GeometryReader { g in
            let landscape = g.size.width > g.size.height
            ZStack {
                Backdrop()
                    .frame(width: g.size.width, height: g.size.height)
                if let m = store.media {
                    if landscape {
                        HStack(spacing: 40) {
                            ArtStage(side: min(g.size.height - 190, g.size.width * 0.36))
                            Controls(media: m)
                                .frame(maxWidth: 440)
                        }
                        .padding(.horizontal, 56)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        VStack(spacing: 44) {
                            ArtStage(side: min(g.size.width - 200, g.size.height * 0.40))
                            Controls(media: m)
                                .frame(maxWidth: 520)
                        }
                        .padding(40)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    NothingPlaying()
                }
            }
            .frame(width: g.size.width, height: g.size.height)
        }
    }
}

/// Very soft wash of the artwork's own colour behind everything (imagery role, kept quiet
/// so the gold stays in charge).
struct Backdrop: View {
    @Environment(Store.self) private var store

    private var open: Bool { Theme.style == .glass || Theme.style == .cyber || Theme.style == .molten }

    var body: some View {
        ZStack {
            (open ? Color.clear : Theme.canvas)
                .overlay {
                    if let img = store.art, Theme.style != .paper {
                        Image(uiImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .blur(radius: 70)
                            .opacity(0.22)
                            .transition(.opacity)
                    }
                }
                .clipped()
            RadialGradient(colors: [store.artTint.opacity(Theme.style == .paper ? 0 : 0.16), .clear], center: .init(x: 0.28, y: 0.5),
                           startRadius: 10, endRadius: 620)
            LinearGradient(colors: [Theme.canvas.opacity(0.0), Theme.canvas.opacity(open ? 0.35 : 0.75)], startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.8), value: store.artKey)
    }
}

/// The artwork as a physical sleeve: it leans slowly in 3D, glows in its own colour, and a
/// record turns behind it while the music plays.
struct ArtStage: View {
    @Environment(Store.self) private var store
    var side: CGFloat
    @State private var lean = false

    var body: some View {
        let playing = store.media?.isPlaying ?? false
        let fx = store.settings.effects
        let angle: Double = fx ? (lean ? 9 : -9) : 0
        VStack(spacing: 0) {
            ZStack {
                Vinyl(tint: store.artTint, playing: playing && fx)
                    .frame(width: side * 0.92, height: side * 0.92)
                    .offset(x: playing ? side * 0.30 : side * 0.06)
                    .animation(.spring(response: 0.9, dampingFraction: 0.8), value: playing)
                Artwork(size: side)
                    .shadow(color: store.artTint.opacity(Theme.style == .paper ? 0.25 : 0.55), radius: 50, y: 18)
                    .overlay(
                        Theme.box
                            .strokeBorder(Theme.gold.opacity(0.35), lineWidth: 1)
                            .padding(-8)
                    )
            }
            .scaleEffect(playing ? 1 : 0.94)
            .rotation3DEffect(.degrees(angle), axis: (x: 0.12, y: 1, z: 0), perspective: 0.55)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: playing)
            .animation(.easeInOut(duration: 7).repeatForever(autoreverses: true), value: lean)
            // Reflection on the floor
            Artwork(size: side)
                .scaleEffect(x: 1, y: -1)
                .frame(height: side * 0.16, alignment: .top)
                .clipped()
                .mask(LinearGradient(colors: [.white.opacity(0.18), .clear], startPoint: .top, endPoint: .bottom))
                .padding(.top, 14)
                .scaleEffect(playing ? 1 : 0.94)
                .allowsHitTesting(false)
        }
        .padding(.trailing, side * 0.16)
        .onAppear { lean = true }
    }
}

struct Controls: View {
    @Environment(Store.self) private var store
    var media: MediaInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .symbolEffect(.variableColor.iterative, options: .repeating, isActive: media.isPlaying)
                    Eyebrow("Playing on \(store.current?.name ?? "PC") · \(media.app)")
                }
                .foregroundStyle(Theme.gold)
                .font(Theme.d.text(12, .semibold))

                Text(media.title.isEmpty ? "Unknown title" : media.title)
                    .font(Theme.d.text(34, .semibold))
                    .tracking(-0.8)
                    .foregroundStyle(Theme.ivory)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.opacity)
                Text(media.artist)
                    .font(Theme.d.text(22, .regular))
                    .foregroundStyle(Theme.gold)
                    .lineLimit(1)
                if !media.album.isEmpty {
                    Text(media.album)
                        .font(Theme.d.text(15))
                        .foregroundStyle(Theme.text3)
                        .lineLimit(1)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: media.title)

            Scrubber(canSeek: media.can.seek)

            HStack(spacing: 0) {
                RingButton(symbol: "shuffle", size: 44, enabled: media.can.shuffle, active: media.shuffle == true) {
                    store.mediaAction("shuffle", ["on": media.shuffle == true ? "0" : "1"])
                }
                Spacer()
                RingButton(symbol: "backward.fill", size: 60, enabled: media.can.prev) { store.mediaAction("prev") }
                Spacer().frame(width: 22)
                RingButton(symbol: media.isPlaying ? "pause.fill" : "play.fill", size: 84, filled: true,
                           enabled: media.can.toggle || media.can.play || media.can.pause) { store.mediaAction("toggle") }
                Spacer().frame(width: 22)
                RingButton(symbol: "forward.fill", size: 60, enabled: media.can.next) { store.mediaAction("next") }
                Spacer()
                RingButton(symbol: repeatSymbol, size: 44, enabled: media.can.repeatMode,
                           active: (media.repeatMode ?? "none") != "none") {
                    store.mediaAction("repeat", ["mode": nextRepeat])
                }
            }

            VolumeBar()

            if media.sessions.count > 1 { Sources(media: media) }
        }
    }

    private var repeatSymbol: String { media.repeatMode == "track" ? "repeat.1" : "repeat" }
    private var nextRepeat: String {
        switch media.repeatMode ?? "none" {
        case "none": return "list"
        case "list": return "track"
        default: return "none"
        }
    }
}

/// Drag to seek. While dragging, the knob grows and the time follows your finger.
struct Scrubber: View {
    @Environment(Store.self) private var store
    var canSeek: Bool
    @State private var drag: Double?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
            let dur = store.media?.dur
            let pos = drag ?? store.position(at: ctx.date) ?? 0
            VStack(spacing: 8) {
                GeometryReader { g in
                    let frac = CGFloat(dur.map { pos / max(1, $0) } ?? 0)
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.track).frame(height: drag == nil ? 3 : 5)
                        Capsule().fill(Theme.gleam).frame(width: max(3, g.size.width * frac), height: drag == nil ? 3 : 5)
                        Circle()
                            .fill(Theme.aged)
                            .frame(width: drag == nil ? 10 : 18, height: drag == nil ? 10 : 18)
                            .shadow(color: Theme.gold.opacity(0.6), radius: drag == nil ? 0 : 8)
                            .offset(x: g.size.width * frac - (drag == nil ? 5 : 9))
                            .opacity(canSeek ? 1 : 0)
                    }
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            guard canSeek, let dur else { return }
                            drag = Double(max(0, min(1, v.location.x / max(1, g.size.width)))) * dur
                        }
                        .onEnded { _ in
                            if let d = drag { store.mediaAction("seek", ["t": String(format: "%.1f", d)]) }
                            drag = nil
                        })
                    .animation(.snappy(duration: 0.2), value: drag == nil)
                }
                .frame(height: 22)
                HStack {
                    Text(Fmt.duration(dur == nil ? nil : pos))
                    Spacer()
                    Text(dur.map { "-" + Fmt.duration(max(0, $0 - pos)) } ?? "LIVE")
                }
                .font(Theme.d.text(12, .medium).monospacedDigit())
                .foregroundStyle(drag == nil ? Theme.text3 : Theme.gold)
            }
        }
    }
}

/// The PC's speaker volume.
struct VolumeBar: View {
    @Environment(Store.self) private var store

    var body: some View {
        if let a = store.audio {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 14) {
                    Button { store.toggleMute() } label: {
                        Image(systemName: icon(a))
                            .font(Theme.d.text(16, .medium))
                            .foregroundStyle(a.muted ? Theme.text3 : Theme.gold)
                            .frame(width: 28)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.plain)
                    GoldSlider(value: a.muted ? 0 : a.level) { v, final in
                        store.volumeDragging = !final
                        store.setVolume(v, final: final)
                    }
                    Text(a.muted ? "Muted" : "\(Int(a.level.rounded()))")
                        .font(Theme.d.text(13, .semibold).monospacedDigit())
                        .foregroundStyle(Theme.ivory)
                        .frame(width: 48, alignment: .trailing)
                        .contentTransition(.numericText())
                }
                if let d = a.device {
                    Text("PC volume · " + d)
                        .font(.small)
                        .foregroundStyle(Theme.text3)
                        .lineLimit(1)
                        .padding(.leading, 42)
                }
            }
        }
    }

    private func icon(_ a: AudioInfo) -> String {
        if a.muted || a.level < 1 { return "speaker.slash.fill" }
        if a.level < 34 { return "speaker.wave.1.fill" }
        if a.level < 67 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}

/// A thin gold slider, 0...100. onChange(value, isFinal).
struct GoldSlider: View {
    var value: Double
    var onChange: (Double, Bool) -> Void
    @State private var dragging = false

    var body: some View {
        GeometryReader { g in
            let frac = CGFloat(max(0, min(100, value)) / 100)
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track).frame(height: dragging ? 6 : 4)
                Capsule().fill(Theme.signal).frame(width: max(4, g.size.width * frac), height: dragging ? 6 : 4)
                Circle().fill(Theme.aged)
                    .frame(width: dragging ? 20 : 14, height: dragging ? 20 : 14)
                    .offset(x: g.size.width * frac - (dragging ? 10 : 7))
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { v in
                    dragging = true
                    onChange(Double(max(0, min(1, v.location.x / max(1, g.size.width)))) * 100, false)
                }
                .onEnded { v in
                    dragging = false
                    onChange(Double(max(0, min(1, v.location.x / max(1, g.size.width)))) * 100, true)
                })
            .animation(.snappy(duration: 0.2), value: dragging)
        }
        .frame(height: 28)
    }
}

/// When several apps are playing, pick which one the iPad controls.
struct Sources: View {
    @Environment(Store.self) private var store
    var media: MediaInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow("Sources", color: Theme.text3)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    chip(title: "Automatic", sub: nil, on: !media.pinned) { store.selectSource(nil) }
                    ForEach(media.sessions) { s in
                        chip(title: s.app, sub: s.title.isEmpty ? nil : s.title, on: media.pinned && media.id == s.id,
                             playing: s.playing) { store.selectSource(s.id) }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private func chip(title: String, sub: String?, on: Bool, playing: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if playing {
                    Image(systemName: "waveform")
                        .font(Theme.d.text(11, .semibold))
                        .symbolEffect(.variableColor.iterative, options: .repeating)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(Theme.d.text(13, .semibold))
                    if let sub { Text(sub).font(Theme.d.text(11)).opacity(0.7).lineLimit(1) }
                }
            }
            .foregroundStyle(on ? Theme.onFill : Theme.ivory)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: 220, alignment: .leading)
            .background(on ? Theme.fill : Color.clear, in: Theme.box)
            .overlay(Theme.box.strokeBorder(on ? Color.clear : Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
