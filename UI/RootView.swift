import SwiftUI

struct RootView: View {
    @Environment(Store.self) private var store

    var body: some View {
        @Bindable var store = store
        Group {
            if store.current == nil || store.showConnect {
                ConnectView()
                    .transition(.opacity)
            } else {
                Dashboard()
                    .transition(.opacity)
            }
        }
        // Changing style or colour rebuilds every view with the new look.
        .id(store.settings.style.rawValue + "." + store.settings.accent.rawValue)
        .animation(.easeInOut(duration: 0.35), value: store.current == nil || store.showConnect)
        .background(StyleBackground(design: Design.make(store.settings.style, store.settings.accent)))
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .sheet(isPresented: $store.showSettings) {
            SettingsView()
                .environment(store)
                .presentationDetents([.large])
                .preferredColorScheme(store.settings.style == .paper ? .light : .dark)
        }
        .onAppear { store.applySystem() }
    }
}

/// Top bar + the current page.
struct Dashboard: View {
    @Environment(Store.self) private var store

    var body: some View {
        VStack(spacing: 0) {
            TopBar()
            StatusBanner()
            ZStack {
                switch store.page {
                case .overview: OverviewPage()
                case .performance: PerformancePage()
                case .music: MusicPage()
                case .clock: ClockPage()
                }
            }
            .id(store.page)
            .transition(.opacity.combined(with: .scale(scale: 0.99)))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if Theme.style == .glass { GlassNav().padding(.bottom, 14).padding(.top, 6) }
            }
        }
        .animation(.easeInOut(duration: 0.28), value: store.page)
        // A hardware keyboard works too: space plays/pauses, arrows skip, 1-4 change page.
        .background {
            Group {
                Button("") { store.mediaAction("toggle") }.keyboardShortcut(.space, modifiers: [])
                Button("") { store.mediaAction("next") }.keyboardShortcut(.rightArrow, modifiers: .command)
                Button("") { store.mediaAction("prev") }.keyboardShortcut(.leftArrow, modifiers: .command)
                ForEach(Array(Page.allCases.enumerated()), id: \.offset) { i, p in
                    Button("") { store.page = p }.keyboardShortcut(KeyEquivalent(Character(String(i + 1))), modifiers: .command)
                }
            }
            .opacity(0)
            .accessibilityHidden(true)
        }
    }
}

struct TopBar: View {
    @Environment(Store.self) private var store

    var body: some View {
        HStack(spacing: 0) {
            Button { store.showConnect = true } label: {
                HStack(spacing: 10) {
                    Mark().frame(width: 18, height: 18)
                    Text((store.current?.name ?? "PC").uppercased())
                        .font(Theme.d.text(13, .semibold))
                        .tracking(2)
                        .foregroundStyle(Theme.ivory)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(Theme.d.text(10, .bold))
                        .foregroundStyle(Theme.gold)
                }
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .hoverEffect(.highlight)
            .frame(maxWidth: .infinity, alignment: .leading)

            if Theme.style != .glass {
                HStack(spacing: 4) {
                    ForEach(Page.allCases) { p in
                        NavLink(title: p.title, active: store.page == p) { store.page = p }
                    }
                }
                .fixedSize()
            }

            HStack(spacing: 18) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 18) {
                        LinkDot()
                        TimelineView(.periodic(from: .now, by: 1)) { ctx in
                            let c = Fmt.clock(ctx.date, h24: store.settings.clock24)
                            Text(c.hm + (c.ampm.isEmpty ? "" : " " + c.ampm))
                                .font(Theme.d.text(13, .medium).monospacedDigit())
                                .foregroundStyle(Theme.text2)
                                .fixedSize()
                        }
                    }
                    LinkDot()
                }
                Button { store.showSettings = true } label: {
                    Image(systemName: "gearshape")
                        .font(Theme.d.text(16, .regular))
                        .foregroundStyle(Theme.gold)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .hoverEffect(.highlight)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .frame(height: 56)
        .overlay(alignment: .bottom) {
            if Theme.style != .glass { Rectangle().fill(Theme.hairline).frame(height: 1) }
        }
    }
}

/// Glass style: the pages live in a floating frosted pill at the bottom (from Dimension).
struct GlassNav: View {
    @Environment(Store.self) private var store

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Page.allCases) { p in
                NavLink(title: p.title, active: store.page == p) { store.page = p }
            }
        }
        .padding(5)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
    }
}

/// LIVE / CONNECTING / OFFLINE with a breathing dot.
struct LinkDot: View {
    @Environment(Store.self) private var store
    @State private var pulse = false

    private var word: String {
        switch store.link {
        case .live: return "LIVE"
        case .offline: return "OFFLINE"
        case .starting: return "STARTING"
        default: return "CONNECTING"
        }
    }

    private var color: Color {
        switch store.link {
        case .live: return Theme.gold
        case .offline: return Theme.critical
        default: return Theme.text2
        }
    }

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .opacity(store.link == .live ? (pulse ? 1 : 0.35) : 1)
                .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulse)
            Text(word)
                .font(Theme.d.text(10.5, .semibold))
                .tracking(1.6)
                .foregroundStyle(color)
        }
        .onAppear { pulse = true }
    }
}

/// Offline / heat warning strip under the top bar.
struct StatusBanner: View {
    @Environment(Store.self) private var store

    var body: some View {
        Group {
            if store.link == .offline {
                banner(icon: "wifi.exclamationmark", text: "Can't reach \(store.current?.name ?? "the PC"). Is PC Dashboard running on it?", color: Theme.critical)
            } else if store.link == .starting {
                banner(icon: "hourglass", text: "The PC is starting up its sensors…", color: Theme.gold)
            } else if let heat = store.heatAlert {
                banner(icon: "thermometer.high", text: heat + ". Check its cooling.", color: Theme.critical)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, store.link == .offline || store.link == .starting || store.heatAlert != nil ? 10 : 0)
        .animation(.easeInOut(duration: 0.3), value: store.link)
    }

    private func banner(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).symbolEffect(.pulse, options: .repeating)
            Text(text).lineLimit(1)
        }
        .font(Theme.d.text(13, .medium))
        .foregroundStyle(color)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(Theme.canvas.opacity(0.92), in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.55), lineWidth: 1))
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

/// The app's mark: a gold ring gauge, open at the bottom, with one lit segment.
struct Mark: View {
    var body: some View {
        Canvas { ctx, size in
            let r = min(size.width, size.height) / 2 - 1.5
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            var ring = Path()
            ring.addArc(center: c, radius: r, startAngle: .degrees(130), endAngle: .degrees(50), clockwise: false)
            ctx.stroke(ring, with: .color(Theme.gold.opacity(0.45)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            var lit = Path()
            lit.addArc(center: c, radius: r, startAngle: .degrees(130), endAngle: .degrees(300), clockwise: false)
            ctx.stroke(lit, with: .color(Theme.gold), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
            let dot = CGRect(x: c.x - 1.8, y: c.y - 1.8, width: 3.6, height: 3.6)
            ctx.fill(Path(ellipseIn: dot), with: .color(Theme.aged))
        }
    }
}
