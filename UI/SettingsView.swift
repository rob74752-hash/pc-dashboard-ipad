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
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                            ForEach(StyleID.allCases) { s in
                                StyleTile(style: s, accent: store.settings.accent, selected: store.settings.style == s) {
                                    withAnimation(.easeInOut(duration: 0.3)) { store.binding(\.style).wrappedValue = s }
                                }
                            }
                        }
                        Text("Colour").font(.uiMedium).foregroundStyle(Theme.ivory).padding(.top, 6)
                        HStack(spacing: 0) {
                            ForEach(AccentID.allCases) { a in
                                Swatch(accent: a, selected: store.settings.accent == a) {
                                    withAnimation(.easeInOut(duration: 0.3)) { store.binding(\.accent).wrappedValue = a }
                                }
                                .frame(maxWidth: .infinity)
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
                        toggle("Shimmer", "The slow light that moves across the metal numbers in the Gilded style. Turn off to save battery.", store.binding(\.effects))
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
            .background(StyleBackground(design: Design.make(store.settings.style, store.settings.accent)))
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

/// A small live sample of a style, drawn with that style's own colours and type.
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
                    StyleBackground(design: d)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(style == .gilded ? "PROCESSOR" : style == .terminal ? "▸ processor" : "Processor")
                            .font(d.text(style == .gilded ? 8 : 10, style == .gilded ? .semibold : .regular))
                            .tracking(style == .gilded ? 1.2 : 0)
                            .foregroundStyle(style == .terminal ? d.accent : d.label)
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text("42")
                                .font(d.display(34))
                                .tracking(style == .gilded ? -1.4 : -0.6)
                                .foregroundStyle(style == .gilded
                                                 ? AnyShapeStyle(LinearGradient(colors: [d.numeral, d.accent], startPoint: .top, endPoint: .bottom))
                                                 : AnyShapeStyle(d.numeral))
                            Text("%").font(d.display(11, weight: .regular)).foregroundStyle(d.accent)
                        }
                        miniMeter(d)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background { miniCard(d) }
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
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScale())
    }

    @ViewBuilder private func miniCard(_ d: Design) -> some View {
        switch style {
        case .paper:
            Rectangle().fill(d.canvas).overlay(alignment: .top) { Rectangle().fill(d.ink).frame(height: 1) }
        case .glass:
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(d.hairline, lineWidth: 1))
                .environment(\.colorScheme, .dark)
        default:
            RoundedRectangle(cornerRadius: min(d.radius, 6), style: .continuous).fill(d.cardFill)
                .overlay(RoundedRectangle(cornerRadius: min(d.radius, 6), style: .continuous).strokeBorder(d.hairline, lineWidth: 1))
        }
    }

    @ViewBuilder private func miniMeter(_ d: Design) -> some View {
        if style == .terminal {
            HStack(spacing: 2) {
                ForEach(0..<10, id: \.self) { i in Rectangle().fill(i < 6 ? d.signal : d.track).frame(height: 5) }
            }
        } else {
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(d.track)
                    Capsule().fill(d.signal).frame(width: g.size.width * 0.6)
                }
            }
            .frame(height: 3)
        }
    }
}

struct Swatch: View {
    var accent: AccentID
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [Color(hex: accent.hexes.hi), accent.swatch, Color(hex: accent.hexes.deep)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 34, height: 34)
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
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScale())
    }
}
