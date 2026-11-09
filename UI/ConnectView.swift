import SwiftUI

/// First launch, and the PC switcher: PCs found on the network, saved PCs, or type an address.
struct ConnectView: View {
    @Environment(Store.self) private var store
    @State private var discovery = Discovery()
    @State private var address = ""
    @State private var checking = false
    @State private var error: String?
    @FocusState private var typing: Bool

    var body: some View {
        GeometryReader { g in
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    found
                    manual
                    help
                }
                .frame(maxWidth: 620)
                .padding(.horizontal, 40)
                .padding(.vertical, 48)
                .frame(maxWidth: .infinity, minHeight: g.size.height)
            }
            .scrollIndicators(.hidden)
        }
        .background(StyleBackground())
        .overlay(alignment: .topTrailing) {
            if store.current != nil {
                Button { store.showConnect = false } label: {
                    Image(systemName: "xmark")
                        .font(Theme.d.text(15, .semibold))
                        .foregroundStyle(Theme.gold)
                        .frame(width: 44, height: 44)
                        .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(24)
            }
        }
        .onAppear {
            if store.demo {
                discovery.found = [.init(name: "STUDIO-PC", address: "192.168.4.26:8090"),
                                   .init(name: "LAPTOP", address: "192.168.4.31:8090")]
            } else {
                discovery.start()
            }
        }
        .onDisappear { discovery.stop() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Mark().frame(width: 30, height: 30)
                Eyebrow("PC Dashboard")
            }
            Text(store.current == nil ? "Connect to your PC" : "Switch PC")
                .font(Theme.d.text(40, .semibold))
                .tracking(-1)
                .foregroundStyle(Theme.ivory)
            Text("On the PC, double-click **Start PC Dashboard.cmd**. It shows up below by itself, as long as the iPad is on the same Wi-Fi.")
                .font(Theme.d.text(16))
                .foregroundStyle(Theme.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var rows: [Discovery.Found] {
        var list = discovery.found
        for pc in store.pcs where !list.contains(where: { $0.address == pc.address }) {
            list.append(.init(name: pc.name, address: pc.address))
        }
        return list
    }

    private var found: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Eyebrow("On your network")
                Spacer()
                if discovery.scanning {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small).tint(Theme.gold)
                        Text("Looking… \(Int(discovery.progress * 100))%")
                            .font(.small.monospacedDigit())
                            .foregroundStyle(Theme.text3)
                    }
                } else if !store.demo {
                    Button("Look again") { discovery.start() }
                        .font(Theme.d.text(13, .semibold))
                        .foregroundStyle(Theme.gold)
                }
            }
            VStack(spacing: 0) {
                if rows.isEmpty {
                    HStack(spacing: 14) {
                        Image(systemName: "desktopcomputer")
                            .font(Theme.d.text(22, .light))
                            .foregroundStyle(Theme.gold)
                        Text(discovery.scanning ? "Searching for PCs running PC Dashboard…" : "No PCs found yet.")
                            .font(.ui)
                            .foregroundStyle(Theme.text2)
                        Spacer()
                    }
                    .padding(18)
                }
                ForEach(Array(rows.enumerated()), id: \.element.id) { i, f in
                    if i > 0 { Rectangle().fill(Theme.hairline).frame(height: 1) }
                    PCRow(found: f, saved: store.pcs.contains { $0.address == f.address },
                          current: store.current?.address == f.address) {
                        store.connect(SavedPC(name: f.name, address: f.address))
                    } forget: {
                        store.forget(SavedPC(name: f.name, address: f.address))
                    }
                }
            }
            .overlay(RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(Theme.hairline, lineWidth: 1))
            .animation(.easeInOut(duration: 0.25), value: rows)

            if discovery.localNetworkBlocked {
                Label {
                    Text("The iPad is blocking the search. Turn on **Settings › Privacy & Security › Local Network › PC Dashboard**, then tap Look again.")
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                }
                .font(.small)
                .foregroundStyle(Theme.hot)
            }
        }
    }

    private var manual: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow("Or type the address")
            HStack(spacing: 10) {
                TextField("", text: $address, prompt: Text("192.168.1.20").foregroundStyle(Theme.text3))
                    .font(Theme.d.text(17, .medium).monospacedDigit())
                    .foregroundStyle(Theme.ivory)
                    .keyboardType(.numbersAndPunctuation)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($typing)
                    .submitLabel(.go)
                    .onSubmit(connectTyped)
                    .padding(.horizontal, 16)
                    .frame(height: 50)
                    .overlay(RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(typing ? Theme.gold : Theme.hairline, lineWidth: 1))
                Button(action: connectTyped) {
                    Group {
                        if checking { ProgressView().tint(Theme.onFill) } else { Text("Connect").font(Theme.d.text(15, .semibold)) }
                    }
                    .foregroundStyle(Theme.onFill)
                    .frame(width: 120, height: 50)
                    .background(Theme.fill, in: RoundedRectangle(cornerRadius: Theme.radius))
                }
                .buttonStyle(PressScale())
                .disabled(address.isEmpty || checking)
                .opacity(address.isEmpty ? 0.5 : 1)
            }
            if let error {
                Text(error).font(.small).foregroundStyle(Theme.critical)
            }
            Text("It's the address the PC Dashboard window shows, like http://192.168.1.20:8090.")
                .font(.small)
                .foregroundStyle(Theme.text3)
        }
    }

    private var help: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow("If it doesn't appear", color: Theme.text3)
            Text("Make sure the PC Dashboard window is open on the PC. If Windows asked about the network, allow it, or run **Allow through firewall.cmd** in the PC Dashboard folder once.")
                .font(.small)
                .foregroundStyle(Theme.text3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func connectTyped() {
        guard let addr = API.normalize(address) else { error = "That doesn't look like an address."; return }
        error = nil
        checking = true
        Task {
            let host = await API.hello(addr, allowOld: true)
            checking = false
            if let host {
                store.connect(SavedPC(name: host, address: addr))
            } else {
                error = "Nothing answered at \(addr). Check the address and that PC Dashboard is running."
            }
        }
    }
}

struct PCRow: View {
    var found: Discovery.Found
    var saved: Bool
    var current: Bool
    var connect: () -> Void
    var forget: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "desktopcomputer")
                .font(Theme.d.text(22, .light))
                .foregroundStyle(Theme.gold)
                .frame(width: 34)
            VStack(alignment: .leading, spacing: 3) {
                Text(found.name.uppercased())
                    .font(Theme.d.text(15, .semibold))
                    .tracking(1.4)
                    .foregroundStyle(Theme.ivory)
                Text(found.address)
                    .font(.small.monospacedDigit())
                    .foregroundStyle(Theme.text3)
            }
            Spacer()
            if current {
                Eyebrow("Connected")
            }
            Button(action: connect) {
                Text(current ? "Open" : "Connect")
                    .font(Theme.d.text(14, .semibold))
                    .foregroundStyle(Theme.onFill)
                    .padding(.horizontal, 18)
                    .frame(height: 38)
                    .background(Theme.fill, in: RoundedRectangle(cornerRadius: Theme.radius))
            }
            .buttonStyle(PressScale())
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .contextMenu {
            if saved {
                Button("Forget this PC", systemImage: "trash", role: .destructive, action: forget)
            }
        }
    }
}
