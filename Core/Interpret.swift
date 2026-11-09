import Foundation

/// Turns the PC's raw stats into the tidy Snapshot the screens draw.
/// A port of model() in the web dashboard's core.js, so both show the same numbers.
enum Interpret {

    // MARK: LibreHardwareMonitor sensor tree

    struct Sensor { var group: String; var name: String; var value: Double }
    struct Hardware { var name: String; var kind: String; var sensors: [Sensor] = [] }

    static let groups: [String: String] = [
        "Temperatures": "temp", "Load": "load", "Clocks": "clock", "Powers": "power", "Fans": "fan",
        "Voltages": "volt", "Data": "data", "SmallData": "smalldata", "Throughput": "throughput",
        "Controls": "control", "Levels": "level",
    ]

    static func matches(_ s: String, _ pattern: String) -> Bool {
        s.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    static func hwKind(_ node: LHMNode) -> String {
        let id = (node.hardwareId ?? "").lowercased(), img = (node.imageURL ?? "").lowercased()
        if matches(id, "cpu") || matches(img, "cpu\\.png") { return "cpu" }
        if matches(id, "gpu") || matches(img, "(ati|amd|nvidia|intel)\\.png") { return "gpu" }
        if matches(id, "nvme|hdd|ssd|storage") || matches(img, "hdd\\.png") { return "storage" }
        if matches(id, "ram|memory") || matches(img, "ram\\.png") { return "memory" }
        if matches(id, "nic|network") || matches(img, "nic\\.png") { return "network" }
        if matches(id, "battery") || matches(img, "battery") { return "battery" }
        if matches(id, "lpc|superio") || matches(img, "chip\\.png") { return "superio" }
        if matches(id, "mainboard|motherboard") || matches(img, "mainboard\\.png") { return "mainboard" }
        return "other"
    }

    static func parseValue(_ raw: String?) -> Double {
        guard let raw, !raw.isEmpty else { return .nan }
        let s = raw.replacingOccurrences(of: ",", with: ".")
        guard let r = s.range(of: "-?\\d+(\\.\\d+)?", options: .regularExpression), var v = Double(s[r]) else { return .nan }
        if raw.contains("°F") { v = (v - 32) * 5 / 9 } // LHM set to Fahrenheit: keep °C inside the app
        return v
    }

    static func parseLHM(_ root: LHMNode) -> [Hardware] {
        var list: [Hardware] = []
        var index: [String: Int] = [:]
        func walk(_ node: LHMNode, _ path: String, parent: LHMNode?, grand: (node: LHMNode, path: String)?) {
            if node.children.isEmpty, let parent, let grand, let g = groups[parent.text] {
                let i: Int
                if let found = index[grand.path] { i = found } else {
                    list.append(Hardware(name: grand.node.text, kind: hwKind(grand.node)))
                    i = list.count - 1
                    index[grand.path] = i
                }
                list[i].sensors.append(Sensor(group: g, name: node.text, value: parseValue(node.value)))
                return
            }
            for (k, child) in node.children.enumerated() {
                walk(child, path + "/" + String(k), parent: node, grand: parent.map { (node: $0, path: parentPath(path)) })
            }
        }
        walk(root, "r", parent: nil, grand: nil)
        return list
    }

    /// The path of a node's parent ("r/0/3" -> "r/0").
    private static func parentPath(_ path: String) -> String {
        guard let i = path.lastIndex(of: "/") else { return path }
        return String(path[..<i])
    }

    static func pick(_ hw: Hardware?, _ group: String, _ patterns: [String]) -> Double? {
        guard let hw else { return nil }
        let list = hw.sensors.filter { s in
            guard s.group == group, s.value.isFinite else { return false }
            if group == "temp" { return s.value > 0 && s.value < 150 && !matches(s.name, "warning|critical|limit") }
            if group == "fan" { return s.value < 20000 }
            return true
        }
        for p in patterns {
            if let hit = list.first(where: { matches($0.name, p) }) { return hit.value }
        }
        return nil
    }

    static func tokens(_ s: String) -> [String] {
        var t = s.lowercased()
        t = t.replacingOccurrences(of: "\\((tm|r)\\)", with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: "\\b(series|laptop|gpu|graphics)\\b", with: " ", options: .regularExpression)
        return t.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
    }

    static func matchGPU(_ name: String, _ list: [Hardware]) -> Hardware? {
        let a = tokens(name)
        var best: Hardware?
        var bestScore = 0.5
        for h in list {
            let b = tokens(h.name)
            let hit = a.filter { b.contains($0) }.count
            let denom = Double(max(1, a.count + b.count - hit))
            let score = Double(hit) / denom
            if score > bestScore { bestScore = score; best = h }
        }
        return best
    }

    static func cleanName(_ s: String?) -> String {
        var t = s ?? ""
        t = t.replacingOccurrences(of: "\\((TM|R)\\)", with: "", options: [.regularExpression, .caseInsensitive])
        t = t.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return t.trimmingCharacters(in: .whitespaces)
    }

    static func shortGPU(_ s: String) -> String {
        var t = cleanName(s)
        t = t.replacingOccurrences(of: "^(AMD|NVIDIA|Intel)\\s+", with: "", options: [.regularExpression, .caseInsensitive])
        t = t.replacingOccurrences(of: "\\s+Series$", with: "", options: [.regularExpression, .caseInsensitive])
        t = t.replacingOccurrences(of: "^(GeForce|Radeon)\\s+(?=(RX|RTX|GTX|Pro|\\w*\\d))", with: "", options: [.regularExpression, .caseInsensitive])
        if matches(t, "^Radeon Graphics$|^Graphics$|^UHD|^Iris|^Radeon$") { return "Integrated" }
        return t
    }

    /// Short, friendly CPU name: "AMD Ryzen 7 7800X3D 8-Core Processor" -> "Ryzen 7 7800X3D".
    static func shortCPU(_ s: String) -> String {
        var t = cleanName(s)
        t = t.replacingOccurrences(of: "^(AMD|Intel)\\s+", with: "", options: [.regularExpression, .caseInsensitive])
        t = t.replacingOccurrences(of: "\\s+(\\d+-Core|with Radeon.*|Processor|CPU).*$", with: "", options: [.regularExpression, .caseInsensitive])
        t = t.replacingOccurrences(of: "^Core\\s+", with: "Core ", options: .regularExpression)
        t = t.replacingOccurrences(of: "\\s*@.*$", with: "", options: .regularExpression)
        return t.isEmpty ? "Processor" : t
    }

    // MARK: Snapshot

    static func snapshot(_ d: RawStats) -> Snapshot {
        var m = Snapshot()
        let st = d.info
        let hws = d.lhm.map(parseLHM) ?? []
        let lc = hws.first { $0.kind == "cpu" }
        let lgs = hws.filter { $0.kind == "gpu" }
        let lds = hws.filter { $0.kind == "storage" }

        m.host = st?.host ?? "PC"
        m.os = (st?.os ?? "").replacingOccurrences(of: "Microsoft ", with: "")
        m.time = d.time ?? 0
        if let boot = st?.bootTime, let t = d.time { m.uptime = t - boot }
        m.hasLhm = d.lhm != nil

        var cpu = CPUInfo()
        cpu.name = cleanName(st?.cpuName)
        cpu.load = d.cpu?.load
        cpu.mhz = d.cpu?.mhz
        cpu.cores = (d.cpu?.cores ?? []).map { $0 ?? 0 }
        cpu.nCores = st?.cores
        cpu.nThreads = st?.threads
        cpu.temp = pick(lc, "temp", ["tctl|tdie", "package", "^core \\(", "average", "core max", "."])
        cpu.power = pick(lc, "power", ["package", "^cpu", "."])
        m.cpu = cpu

        // Windows can list one card twice plus blank placeholder adapters: keep real, distinct cards.
        var raw = d.gpus.sorted { a, b in
            let va = a.vramTotal ?? 0, vb = b.vramTotal ?? 0
            if va != vb { return va > vb }
            return (a.load ?? 0) > (b.load ?? 0)
        }
        var seen = Set<String>()
        raw = raw.filter { g in
            if (g.name ?? "").isEmpty && (g.vramTotal ?? 0) == 0 { return false }
            let k = cleanName(g.name) + "|" + String(Int(((g.vramTotal ?? 0) / 268_435_456).rounded()))
            if seen.contains(k) { return false }
            seen.insert(k)
            return true
        }
        raw = Array(raw.prefix(2))
        m.gpus = raw.enumerated().map { i, g in
            let l = matchGPU(g.name ?? "", lgs) ?? (raw.count == 1 && lgs.count == 1 ? lgs[0] : nil)
            let n = cleanName(g.name)
            let name = n.isEmpty ? "GPU \(i + 1)" : n
            return GPUInfo(
                id: g.id ?? name, name: name, short: shortGPU(name), load: g.load, vram: g.vram, vramTotal: g.vramTotal,
                temp: pick(l, "temp", ["gpu core", "^core", "edge", "^(?!.*(hot|junction|memory)).*"]),
                hot: pick(l, "temp", ["hot ?spot|junction"]),
                clock: pick(l, "clock", ["gpu core", "^core", "."]),
                power: pick(l, "power", ["package|total|board", "gpu core|^core", "."]),
                fan: pick(l, "fan", ["."]))
        }

        m.mem = MemInfo(used: d.mem?.used, total: d.mem?.total, commit: d.mem?.commit, commitLimit: d.mem?.commitLimit)
        m.disk = DiskInfo(
            read: d.disk?.read, write: d.disk?.write, active: d.disk?.active,
            drives: (d.disk?.drives ?? []).compactMap { x in
                guard let size = x.size, size > 0 else { return nil }
                return DriveInfo(name: x.name ?? "?", label: x.label ?? "", size: size, free: x.free ?? 0)
            },
            temp: lds.first.flatMap { pick($0, "temp", ["composite", "."]) })
        m.net = NetInfo(rx: d.net?.rx, tx: d.net?.tx, ping: d.net?.ping, ip: d.net?.ips.first ?? "")

        var fans: [FanInfo] = []
        for h in hws {
            for s in h.sensors where s.group == "fan" && s.value.isFinite && s.value > 0 && s.value < 20000 {
                let name = (h.kind == "gpu" && !matches(s.name, "^gpu") ? "GPU " : "") + s.name
                if !fans.contains(where: { $0.name == name }) { fans.append(FanInfo(name: name, rpm: s.value)) }
            }
        }
        m.fans = fans

        var temps: [TempItem] = []
        if let t = cpu.temp { temps.append(TempItem(name: "CPU", celsius: t, kind: .cpu)) }
        for g in m.gpus { if let t = g.temp { temps.append(TempItem(name: g.short, celsius: t, kind: .gpu)) } }
        for h in lds {
            if let t = pick(h, "temp", ["composite", "^temperature$", "."]) {
                let name = lds.count > 1 ? "SSD \(temps.filter { $0.kind == .storage }.count + 1)" : "SSD"
                temps.append(TempItem(name: name, celsius: t, kind: .storage))
            }
        }
        m.temps = temps

        var power = cpu.power ?? 0
        for g in m.gpus { power += g.power ?? 0 }
        m.power = power > 0 ? power : nil

        if let b = d.battery, let pct = b.pct { m.battery = BatteryInfo(pct: pct, plugged: b.plugged ?? false) }
        m.procs = d.procs.compactMap { p in
            guard let n = p.name else { return nil }
            return ProcInfo(name: n, cpu: p.cpu ?? 0, mem: p.mem ?? 0)
        }
        return m
    }
}
