import SwiftUI

struct SettingsView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
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
                        toggle("Gold shimmer", "The slow light that moves across the big numbers. Turn off to save battery.", store.binding(\.effects))
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
            }
            .scrollIndicators(.hidden)
            .background(Theme.canvas)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.canvas, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .semibold))
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
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(on ? Color.black : Theme.text2)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(on ? Theme.gold : Color.clear)
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
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(filled ? Color.black : Theme.gold)
                .padding(.horizontal, 18)
                .frame(height: 38)
                .background(filled ? Theme.gold : Color.clear, in: RoundedRectangle(cornerRadius: Theme.radius))
                .overlay(RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(filled ? Color.clear : Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(PressScale())
    }
}
