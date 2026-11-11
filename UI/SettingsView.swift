import SwiftUI

struct SettingsView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    section("Look") {
                        Text("Style").font(.uiMedium).foregroundStyle(Theme.ivory)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 16) {
                            ForEach(StyleID.allCases) { s in
                                StyleTile(style: s, accent: store.settings.style == s ? store.settings.accent : .auto,
                                          selected: store.settings.style == s) {
                                    // Each look arrives in its own colour; pick another below any time.
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        if store.settings.style != s { store.settings.accent = .auto }
                                        store.binding(\.style).wrappedValue = s
                                    }
                                }
                            }
                        }
                        Text("Colour").font(.uiMedium).foregroundStyle(Theme.ivory).padding(.top, 6)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 14) {
                            ForEach(AccentID.allCases) { a in
                                Swatch(accent: a, style: store.settings.style, selected: store.settings.accent == a) {
                                    withAnimation(.easeInOut(duration: 0.3)) { store.binding(\.accent).wrappedValue = a }
                                }
                            }
                        }
                    }
                    section("This PC") {
                        if let pc = store.current {
                            infoRow("Name", pc.name)
                            infoRow("Address", pc.address)
                            infoRow("Status", statusText)
                            infoRow("Temperature sensors", (store.snap?.hasLhm ?? false) ? "Connected" : "Not running")
                            infoRow("Music", store.apiVersion >= 2 ? "Available" : "Update PC Dashboard on the PC")
                            HStack(spacing: 10) {
                                pill("Switch PC", filled: true) { dismiss(); store.showConnect = true }
                                pill("Forget", filled: false) { dismiss(); store.forget(pc) }
                            }
                            .padding(.top, 6)
                        }
                    }
                    section("Display") {
                        choice("Temperature", options: [("°C", false), ("°F", true)], value: store.binding(\.fahrenheit))
                        choice("Clock", options: [("12-hour", false), ("24-hour", true)], value: store.binding(\.clock24))
                        toggle("Keep the screen on", "Stops the iPad from locking while the dashboard is open.", store.binding(\.keepAwake))
                        toggle("Dim at night", "Lowers the brightness from 10 PM to 7 AM.", store.binding(\.nightDim))
                        toggle("Motion and 3D", "The turning objects, solid 3D numbers, moving light and glitches. Turn off for a still, cooler-running screen.", store.binding(\.effects))
                    }
                    section("When you're not touching it") {
                        choice("Rest on", options: [("Stay put", "off"), ("Clock", "clock"), ("Core", "core")], value: store.binding(\.idlePage))
                        Text("After three minutes untouched, the iPad settles on that page.")
                            .font(.small).foregroundStyle(Theme.text3)
                        toggle("Tour the pages", "Moves to the next page every 20 seconds until you touch the screen.", store.binding(\.cyclePages))
                    }
                    section("Charts") {
                        choice("Show the last", options: [("1 min", 1), ("5 min", 5), ("15 min", 15), ("30 min", 30)],
                               value: store.binding(\.historyMinutes))
                        Text("The iPad keeps up to 30 minutes of history while the app is open.")
                            .font(.small).foregroundStyle(Theme.text3)
                    }
                    section("About") {
                        Text("Reads your PC through the PC Dashboard folder on the PC (port 8090). Music comes from Windows' media controls, so it works with Spotify, Apple Music, browsers, Media Player and most other players.")
                            .font(.small)
                            .foregroundStyle(Theme.text2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(28)
                // Rebuild with the new look as soon as a style or colour is picked.
                .id(store.settings.style.rawValue + "." + store.settings.accent.rawValue)
            }
            .scrollIndicators(.hidden)
            .background(StyleBackground(design: Design.make(store.settings.style, store.settings.accent), live: false))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.canvas, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(Theme.d.text(16, .semibold))
                        .foregroundStyle(Theme.gold)
                }
            }
        }
        .tint(Theme.gold)
    }

    private var statusText: String {
        switch store.link {
        case .live: return "Live"
        case .offline: return "Can't reach it"
        case .starting: return "Starting up"
        default: return "Connecting"
        }
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow(title)
            VStack(alignment: .leading, spacing: 16) { content() }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(Theme.hairline, lineWidth: 1))
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.ui).foregroundStyle(Theme.text2)
            Spacer()
            Text(value).font(.uiMedium.monospacedDigit()).foregroundStyle(Theme.ivory).lineLimit(1)
        }
    }

    private func toggle(_ title: String, _ detail: String, _ value: Binding<Bool>) -> some View {
        Toggle(isOn: value) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.uiMedium).foregroundStyle(Theme.ivory)
                Text(detail).font(.small).foregroundStyle(Theme.text3)
            }
        }
        .tint(Theme.gold)
    }

    private func choice<T: Equatable>(_ title: String, options: [(String, T)], value: Binding<T>) -> some View {
        HStack {
            Text(title).font(.uiMedium).foregroundStyle(Theme.ivory)
            Spacer()
            HStack(spacing: 0) {
                ForEach(Array(options.enumerated()), id: \.offset) { _, o in
                    let on = value.wrappedValue == o.1
                    Button { value.wrappedValue = o.1 } label: {
                        Text(o.0)
                            .font(Theme.d.text(13, .semibold))
                            .foregroundStyle(on ? Theme.onFill : Theme.text2)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(on ? Theme.fill : Color.clear)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
            .overlay(RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(Theme.hairline, lineWidth: 1))
        }
    }

    private func pill(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.d.text(14, .semibold))
                .foregroundStyle(filled ? Theme.onFill : Theme.gold)
                .padding(.horizontal, 18)
                .frame(height: 38)
                .background(filled ? Theme.fill : Color.clear, in: RoundedRectangle(cornerRadius: Theme.radius))
                .overlay(RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(filled ? Color.clear : Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(PressScale())
    }
}

/// A small sample of a style, drawn with that style's own colours and type.
struct StyleTile: View {
    var style: StyleID
    var accent: AccentID
    var selected: Bool
    var action: () -> Void

    var body: some View {
        let d = Design.make(style, accent)
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    StyleBackground(design: d, live: false)
                    VStack(alignment: .leading, spacing: 6) {
                        label(d)
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            number(d)
                            Text("%").font(d.display(11, weight: .regular)).foregroundStyle(style == .molten || style == .apex ? d.ink3 : d.accent)
                        }
                        miniMeter(d)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background { miniCard(d) }
                    .overlay(alignment: .bottomTrailing) { emblem(d).padding(9) }
                    .padding(10)
                }
                .frame(height: 118)
                .environment(\.colorScheme, d.dark ? .dark : .light)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(selected ? Theme.gold : Theme.hairline, lineWidth: selected ? 2 : 1))
                VStack(alignment: .leading, spacing: 2) {
                    Text(style.name).font(Theme.d.text(14, .semibold)).foregroundStyle(selected ? Theme.gold : Theme.ivory)
                    Text(style.blurb).font(Theme.d.text(11)).foregroundStyle(Theme.text3).lineLimit(2)
                        .frame(maxWidth: .infinity, minHeight: 28, alignment: .topLeading)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScale())
    }

    @ViewBuilder private func label(_ d: Design) -> some View {
        switch style {
        case .gilded:
            Text("PROCESSOR").font(d.text(8, .semibold)).tracking(1.2).foregroundStyle(d.label)
        case .terminal:
            Text("▸ processor").font(d.text(10)).foregroundStyle(d.accent)
        case .apex:
            Text("PROCESSOR").font(.system(size: 7.5, weight: .medium).width(.expanded)).tracking(0.6).foregroundStyle(d.label)
        case .cyber:
            Text("▪ PROCESSOR").font(d.text(8, .semibold)).tracking(1.6).foregroundStyle(d.label)
        case .molten:
            Text("Processor").font(d.text(10, .bold)).foregroundStyle(d.label)
        case .reactor:
            Text("Processor").font(d.text(10, .semibold)).foregroundStyle(d.label)
        default:
            Text("Processor").font(d.text(10)).foregroundStyle(d.label)
        }
    }

    @ViewBuilder private func number(_ d: Design) -> some View {
        let base = Text("42").font(d.display(34))
        switch style {
        case .gilded:
            base.tracking(-1.4)
                .foregroundStyle(LinearGradient(colors: [d.numeral, d.accent], startPoint: .top, endPoint: .bottom))
                .background { base.tracking(-1.4).foregroundStyle(d.side).offset(x: 1.2, y: 2) }
        case .molten:
            base.tracking(-1)
                .foregroundStyle(LinearGradient(colors: [.white, Color(hex: 0x8E8E8E)], startPoint: .top, endPoint: .bottom))
                .background { base.tracking(-1).foregroundStyle(d.side).offset(x: 1.2, y: 2) }
        case .cyber:
            base.foregroundStyle(d.numeral)
                .background { base.foregroundStyle(d.second).offset(x: -1.5) }
                .background { base.foregroundStyle(Theme.critical).offset(x: 1.5) }
        case .reactor:
            base.foregroundStyle(LinearGradient(colors: [.white, d.accent], startPoint: .top, endPoint: .bottom))
                .shadow(color: d.glow, radius: 6)
        case .terminal, .glass:
            base.tracking(-0.6).foregroundStyle(d.numeral).shadow(color: d.glow, radius: 5)
        default:
            base.tracking(-0.6).foregroundStyle(d.numeral)
        }
    }

    /// A tiny stand-in for the look's 3D object.
    @ViewBuilder private func emblem(_ d: Design) -> some View {
        switch style {
        case .gilded, .paper:
            ZStack {
                Ellipse().stroke(d.accent, lineWidth: 1.5).frame(width: 26, height: 10)
                Ellipse().stroke(d.accent.opacity(0.7), lineWidth: 1.5).frame(width: 10, height: 26)
                Circle().fill(d.accent).frame(width: 6, height: 6)
            }
            .frame(width: 28, height: 28)
        case .glass:
            Circle()
                .fill(RadialGradient(colors: [d.accent, d.deco.opacity(0.5), .clear], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 18))
                .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1))
                .frame(width: 26, height: 26)
        case .terminal:
            Text(" .:=.\n:=#@=\n '=:'").font(.system(size: 6.5, design: .monospaced)).foregroundStyle(d.accent).fixedSize()
        case .reactor:
            ZStack {
                ForEach(0..<4, id: \.self) { i in
                    Ellipse().stroke(d.deco, lineWidth: 1).frame(width: 28, height: 11).rotationEffect(.degrees(Double(i) * 45))
                }
                Circle().fill(Color.black).frame(width: 9, height: 9)
            }
            .frame(width: 28, height: 28)
            .shadow(color: d.deco, radius: 4)
        case .molten:
            ZStack {
                Circle().stroke(d.accent, lineWidth: 4).frame(width: 15, height: 15).offset(x: -5, y: 3)
                Circle().stroke(d.accent.opacity(0.85), lineWidth: 4).frame(width: 15, height: 15).offset(x: 5, y: 3)
                Circle().stroke(d.accent.opacity(0.7), lineWidth: 4).frame(width: 15, height: 15).offset(y: -5)
            }
            .frame(width: 30, height: 28)
        case .apex:
            ZStack {
                Circle().trim(from: 0.125, to: 0.875).stroke(d.ink3, lineWidth: 2).rotationEffect(.degrees(90))
                Rectangle().fill(d.accent).frame(width: 2, height: 11).offset(y: -5).rotationEffect(.degrees(48))
            }
            .frame(width: 26, height: 26)
        case .cyber:
            ZStack {
                Hexagon().stroke(d.second, lineWidth: 1)
                Hexagon().stroke(d.label, lineWidth: 1).padding(6).rotationEffect(.degrees(30))
            }
            .frame(width: 26, height: 26)
        }
    }

    @ViewBuilder private func miniCard(_ d: Design) -> some View {
        switch style {
        case .paper:
            Rectangle().fill(d.canvas).overlay(alignment: .top) { Rectangle().fill(d.ink).frame(height: 1) }
        case .glass:
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.white.opacity(0.25), lineWidth: 1))
                .environment(\.colorScheme, .dark)
        case .reactor:
            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(d.cardFill)
        case .apex:
            Rectangle().fill(d.cardFill).overlay(alignment: .top) { Rectangle().fill(d.accent).frame(height: 2) }
        case .cyber:
            Plate(radius: 0, cut: 8).fill(d.cardFill)
                .overlay(Plate(radius: 0, cut: 8).strokeBorder(d.hairline, lineWidth: 1))
        case .molten:
            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(d.cardFill)
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(d.hairline, lineWidth: 1))
        default:
            RoundedRectangle(cornerRadius: min(d.radius, 6), style: .continuous).fill(d.cardFill)
                .overlay(RoundedRectangle(cornerRadius: min(d.radius, 6), style: .continuous).strokeBorder(d.hairline, lineWidth: 1))
        }
    }

    @ViewBuilder private func miniMeter(_ d: Design) -> some View {
        if style == .terminal || style == .cyber {
            HStack(spacing: 2) {
                ForEach(0..<10, id: \.self) { i in Rectangle().fill(i < 6 ? d.signal : d.track).frame(height: 5) }
            }
            .frame(width: 70)
        } else {
            ZStack(alignment: .leading) {
                Capsule().fill(d.track).frame(width: 70, height: 3)
                Capsule().fill(d.signal).frame(width: 42, height: 3)
            }
        }
    }
}

struct Swatch: View {
    var accent: AccentID
    var style: StyleID
    var selected: Bool
    var action: () -> Void

    var body: some View {
        let h = accent.hexes(style)
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [Color(hex: h.hi), Color(hex: h.main), Color(hex: h.deep)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 34, height: 34)
                    if accent == .auto {
                        Image(systemName: "sparkle")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.7))
                    }
                    Circle()
                        .strokeBorder(selected ? Theme.ivory : Color.clear, lineWidth: 2)
                        .frame(width: 44, height: 44)
                }
                .frame(width: 46, height: 46)
                Text(accent.name)
                    .font(Theme.d.text(11, selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Theme.ivory : Theme.text3)
                    .lineLimit(1)
                    .fixedSize()
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScale())
    }
}
