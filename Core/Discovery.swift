import Foundation
import Network
import Observation

/// Finds PCs running PC Dashboard: Bonjour first (the PC announces itself), then a quick
/// sweep of the local network for anything answering on port 8090 (covers PCs whose
/// firewall blocks Bonjour, or older Windows).
@MainActor @Observable
final class Discovery {
    struct Found: Identifiable, Hashable {
        var id: String { address }
        var name: String
        var address: String
    }

    var found: [Found] = []
    var scanning = false
    var progress: Double = 0
    var localNetworkBlocked = false

    @ObservationIgnored private var browser: NWBrowser?
    @ObservationIgnored private var scanTask: Task<Void, Never>?
    @ObservationIgnored private var resolving = Set<String>()

    func start() {
        stop()
        startBrowser()
        scan()
    }

    func stop() {
        browser?.cancel()
        browser = nil
        scanTask?.cancel()
        scanTask = nil
        scanning = false
    }

    func add(_ f: Found) {
        if let i = found.firstIndex(where: { $0.address == f.address }) {
            found[i] = f
        } else {
            found.append(f)
            found.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }

    // MARK: Bonjour

    private func startBrowser() {
        let params = NWParameters()
        params.includePeerToPeer = false
        let b = NWBrowser(for: .bonjourWithTXTRecord(type: "_pcdash._tcp", domain: nil), using: params)
        b.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .waiting(let error), .failed(let error):
                    if case .dns(let code) = error, code == -65570 { self?.localNetworkBlocked = true } // kDNSServiceErr_PolicyDenied
                    else if case .waiting = state { self?.localNetworkBlocked = true }
                case .ready:
                    self?.localNetworkBlocked = false
                default:
                    break
                }
            }
        }
        b.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in self?.handle(results) }
        }
        b.start(queue: .main)
        browser = b
    }

    private func handle(_ results: Set<NWBrowser.Result>) {
        for r in results {
            guard case let .service(name, _, _, _) = r.endpoint else { continue }
            var ips: [String] = []
            var port = API.defaultPort
            if case let .bonjour(txt) = r.metadata {
                ips = (txt["ips"] ?? "").split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                if let p = Int(txt["port"] ?? "") { port = p }
            }
            guard !resolving.contains(name) else { continue }
            resolving.insert(name)
            let endpoint = r.endpoint
            Task {
                await self.resolve(name: name, ips: ips, port: port, endpoint: endpoint)
                self.resolving.remove(name)
            }
        }
    }

    private func resolve(name: String, ips: [String], port: Int, endpoint: NWEndpoint) async {
        // The PC lists its network addresses; use the first one this iPad can reach.
        for ip in ips {
            let address = "\(ip):\(port)"
            if let host = await API.hello(address) { add(Found(name: host, address: address)); return }
        }
        if let ip = await Discovery.resolveIPv4(endpoint) {
            let address = "\(ip):\(port)"
            if let host = await API.hello(address) { add(Found(name: host, address: address)) }
        }
    }

    /// Opens a throwaway connection to a Bonjour service just to learn its IPv4 address.
    nonisolated static func resolveIPv4(_ endpoint: NWEndpoint) async -> String? {
        let params = NWParameters.tcp
        if let ip = params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options { ip.version = .v4 }
        let conn = NWConnection(to: endpoint, using: params)
        return await withCheckedContinuation { (cont: CheckedContinuation<String?, Never>) in
            let lock = NSLock()
            var done = false
            func finish(_ v: String?) {
                lock.lock(); defer { lock.unlock() }
                if done { return }
                done = true
                conn.cancel()
                cont.resume(returning: v)
            }
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if case let .hostPort(host, _)? = conn.currentPath?.remoteEndpoint, case let .ipv4(a) = host {
                        finish("\(a)".split(separator: "%").first.map { String($0) })
                    } else { finish(nil) }
                case .failed, .cancelled:
                    finish(nil)
                default:
                    break
                }
            }
            conn.start(queue: .global())
            DispatchQueue.global().asyncAfter(deadline: .now() + 3) { finish(nil) }
        }
    }

    // MARK: Network sweep

    func scan() {
        scanTask?.cancel()
        let hosts = Subnet.candidates()
        guard !hosts.isEmpty else { scanning = false; return }
        scanning = true
        progress = 0
        scanTask = Task {
            var done = 0
            await withTaskGroup(of: Found?.self) { group in
                var index = 0
                let width = 48
                while index < min(width, hosts.count) {
                    let h = hosts[index]
                    group.addTask { await Discovery.probe(h) }
                    index += 1
                }
                while let result = await group.next() {
                    if Task.isCancelled { group.cancelAll(); break }
                    done += 1
                    self.progress = Double(done) / Double(hosts.count)
                    if let f = result { self.add(f) }
                    if index < hosts.count {
                        let h = hosts[index]
                        group.addTask { await Discovery.probe(h) }
                        index += 1
                    }
                }
            }
            if !Task.isCancelled { self.scanning = false; self.progress = 1 }
        }
    }

    nonisolated static func probe(_ ip: String) async -> Found? {
        let address = "\(ip):\(API.defaultPort)"
        guard let host = await API.hello(address) else { return nil }
        return Found(name: host, address: address)
    }
}

/// The iPad's own Wi-Fi network, as a list of addresses to try.
enum Subnet {
    static func dotted(_ v: UInt32) -> String {
        "\(v >> 24 & 255).\(v >> 16 & 255).\(v >> 8 & 255).\(v & 255)"
    }

    static func candidates() -> [String] {
        var result: [String] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return [] }
        defer { freeifaddrs(ifaddr) }
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let p = ptr {
            ptr = p.pointee.ifa_next
            let name = String(cString: p.pointee.ifa_name)
            guard name.hasPrefix("en"), let sa = p.pointee.ifa_addr, let nm = p.pointee.ifa_netmask,
                  sa.pointee.sa_family == UInt8(AF_INET) else { continue }
            let addr = sa.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr.s_addr }
            let mask = nm.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr.s_addr }
            let ip = UInt32(bigEndian: addr)
            var m = UInt32(bigEndian: mask)
            if m.nonzeroBitCount < 22 { m = 0xFFFF_FF00 } // big networks: just this /24
            let net = ip & m
            let count = ~m
            guard count >= 2, count <= 1024 else { continue }
            // Nearest addresses first: PCs usually sit close to the iPad.
            let own = ip & count
            let order = (1..<count).sorted { abs(Int($0) - Int(own)) < abs(Int($1) - Int(own)) }
            for i in order where (net | i) != ip {
                let h = dotted(net | i)
                if !result.contains(h) { result.append(h) }
            }
        }
        return result
    }
}
