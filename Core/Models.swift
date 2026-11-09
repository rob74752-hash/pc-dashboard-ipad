import Foundation

// MARK: - What the PC sends (GET /api/stats)
// Every field is optional and decoded leniently: an odd value in one place must never
// blank the whole dashboard.

extension KeyedDecodingContainer {
    func val<T: Decodable>(_ type: T.Type, _ key: Key) -> T? {
        (try? decodeIfPresent(type, forKey: key)) ?? nil
    }
}

struct RawStats: Decodable {
    var ready: Bool
    var time: Double?
    var now: Double?
    var api: Int?
    var info: RawStatic?
    var cpu: RawCPU?
    var mem: RawMem?
    var disk: RawDisk?
    var net: RawNet?
    var gpus: [RawGPU]
    var battery: RawBattery?
    var procs: [RawProc]
    var lhm: LHMNode?
    var media: MediaInfo?
    var audio: AudioInfo?

    enum CodingKeys: String, CodingKey {
        case ready, time, now, api, cpu, mem, disk, net, gpus, battery, procs, lhm, media, audio
        case info = "static"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ready = c.val(Bool.self, .ready) ?? false
        time = c.val(Double.self, .time)
        now = c.val(Double.self, .now)
        api = c.val(Int.self, .api)
        info = c.val(RawStatic.self, .info)
        cpu = c.val(RawCPU.self, .cpu)
        mem = c.val(RawMem.self, .mem)
        disk = c.val(RawDisk.self, .disk)
        net = c.val(RawNet.self, .net)
        gpus = c.val([RawGPU].self, .gpus) ?? []
        battery = c.val(RawBattery.self, .battery)
        procs = c.val([RawProc].self, .procs) ?? []
        lhm = c.val(LHMNode.self, .lhm)
        media = c.val(MediaInfo.self, .media)
        audio = c.val(AudioInfo.self, .audio)
    }
}

struct RawStatic: Decodable {
    var host: String?
    var os: String?
    var cpuName: String?
    var cores: Int?
    var threads: Int?
    var bootTime: Double?

    enum CodingKeys: String, CodingKey { case host, os, cpuName, cores, threads, bootTime }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        host = c.val(String.self, .host)
        os = c.val(String.self, .os)
        cpuName = c.val(String.self, .cpuName)
        cores = c.val(Int.self, .cores)
        threads = c.val(Int.self, .threads)
        bootTime = c.val(Double.self, .bootTime)
    }
}

struct RawCPU: Decodable {
    var load: Double?
    var mhz: Double?
    var cores: [Double?]
    enum CodingKeys: String, CodingKey { case load, mhz, cores }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        load = c.val(Double.self, .load)
        mhz = c.val(Double.self, .mhz)
        cores = c.val([Double?].self, .cores) ?? []
    }
}

struct RawMem: Decodable {
    var total: Double?
    var used: Double?
    var commit: Double?
    var commitLimit: Double?
    enum CodingKeys: String, CodingKey { case total, used, commit, commitLimit }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        total = c.val(Double.self, .total)
        used = c.val(Double.self, .used)
        commit = c.val(Double.self, .commit)
        commitLimit = c.val(Double.self, .commitLimit)
    }
}

struct RawDrive: Decodable {
    var name: String?
    var label: String?
    var size: Double?
    var free: Double?
    enum CodingKeys: String, CodingKey { case name, label, size, free }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = c.val(String.self, .name)
        label = c.val(String.self, .label)
        size = c.val(Double.self, .size)
        free = c.val(Double.self, .free)
    }
}

struct RawDisk: Decodable {
    var active: Double?
    var read: Double?
    var write: Double?
    var drives: [RawDrive]
    enum CodingKeys: String, CodingKey { case active, read, write, drives }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        active = c.val(Double.self, .active)
        read = c.val(Double.self, .read)
        write = c.val(Double.self, .write)
        drives = c.val([RawDrive].self, .drives) ?? []
    }
}

struct RawNet: Decodable {
    var rx: Double?
    var tx: Double?
    var ping: Double?
    var ips: [String]
    enum CodingKeys: String, CodingKey { case rx, tx, ping, ips }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rx = c.val(Double.self, .rx)
        tx = c.val(Double.self, .tx)
        ping = c.val(Double.self, .ping)
        ips = c.val([String].self, .ips) ?? []
    }
}

struct RawGPU: Decodable {
    var id: String?
    var name: String?
    var load: Double?
    var vram: Double?
    var vramTotal: Double?
    enum CodingKeys: String, CodingKey { case id, name, load, vram, vramTotal }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.val(String.self, .id)
        name = c.val(String.self, .name)
        load = c.val(Double.self, .load)
        vram = c.val(Double.self, .vram)
        vramTotal = c.val(Double.self, .vramTotal)
    }
}

struct RawBattery: Decodable {
    var pct: Double?
    var plugged: Bool?
    enum CodingKeys: String, CodingKey { case pct, plugged }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pct = c.val(Double.self, .pct)
        plugged = c.val(Bool.self, .plugged)
    }
}

struct RawProc: Decodable {
    var name: String?
    var cpu: Double?
    var mem: Double?
    enum CodingKeys: String, CodingKey { case name, cpu, mem }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = c.val(String.self, .name)
        cpu = c.val(Double.self, .cpu)
        mem = c.val(Double.self, .mem)
    }
}

/// One node of LibreHardwareMonitor's sensor tree (passed through raw by the PC).
struct LHMNode: Decodable {
    var text: String
    var value: String?
    var hardwareId: String?
    var imageURL: String?
    var children: [LHMNode]

    enum CodingKeys: String, CodingKey {
        case text = "Text", value = "Value", hardwareId = "HardwareId", imageURL = "ImageURL", children = "Children"
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        text = c.val(String.self, .text) ?? ""
        if let s = c.val(String.self, .value) { value = s }
        else if let d = c.val(Double.self, .value) { value = String(d) }
        else { value = nil }
        hardwareId = c.val(String.self, .hardwareId)
        imageURL = c.val(String.self, .imageURL)
        children = c.val([LHMNode].self, .children) ?? []
    }
}

// MARK: - Music (Windows media controls, via the PC)

struct MediaCaps: Decodable, Equatable {
    var play = false, pause = false, toggle = false, next = false, prev = false
    var seek = false, shuffle = false, repeatMode = false

    enum CodingKeys: String, CodingKey {
        case play, pause, toggle, next, prev, seek, shuffle
        case repeatMode = "repeat"
    }
    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        play = c.val(Bool.self, .play) ?? false
        pause = c.val(Bool.self, .pause) ?? false
        toggle = c.val(Bool.self, .toggle) ?? false
        next = c.val(Bool.self, .next) ?? false
        prev = c.val(Bool.self, .prev) ?? false
        seek = c.val(Bool.self, .seek) ?? false
        shuffle = c.val(Bool.self, .shuffle) ?? false
        repeatMode = c.val(Bool.self, .repeatMode) ?? false
    }
}

struct MediaSessionInfo: Decodable, Equatable, Identifiable {
    var id: String
    var app: String
    var title: String
    var artist: String
    var playing: Bool

    enum CodingKeys: String, CodingKey { case id, app, title, artist, playing }
    init(id: String, app: String, title: String, artist: String, playing: Bool) {
        self.id = id; self.app = app; self.title = title; self.artist = artist; self.playing = playing
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.val(String.self, .id) ?? UUID().uuidString
        app = c.val(String.self, .app) ?? "Music"
        title = c.val(String.self, .title) ?? ""
        artist = c.val(String.self, .artist) ?? ""
        playing = c.val(Bool.self, .playing) ?? false
    }
}

struct MediaInfo: Decodable, Equatable {
    var id: String = ""
    var app: String = "Music"
    var title: String = ""
    var artist: String = ""
    var album: String = ""
    var status: String = "stopped"
    var pos: Double?
    var dur: Double?
    var updated: Double?
    var rate: Double = 1
    var art: String?
    var shuffle: Bool?
    var repeatMode: String?
    var can = MediaCaps()
    var pinned = false
    var sessions: [MediaSessionInfo] = []

    var isPlaying: Bool { status == "playing" }

    enum CodingKeys: String, CodingKey {
        case id, app, title, artist, album, status, pos, dur, updated, rate, art, shuffle, can, pinned, sessions
        case repeatMode = "repeat"
    }
    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.val(String.self, .id) ?? ""
        app = c.val(String.self, .app) ?? "Music"
        title = c.val(String.self, .title) ?? ""
        artist = c.val(String.self, .artist) ?? ""
        album = c.val(String.self, .album) ?? ""
        status = c.val(String.self, .status) ?? "stopped"
        pos = c.val(Double.self, .pos)
        dur = c.val(Double.self, .dur)
        updated = c.val(Double.self, .updated)
        rate = c.val(Double.self, .rate) ?? 1
        art = c.val(String.self, .art)
        shuffle = c.val(Bool.self, .shuffle)
        repeatMode = c.val(String.self, .repeatMode)
        can = c.val(MediaCaps.self, .can) ?? MediaCaps()
        pinned = c.val(Bool.self, .pinned) ?? false
        sessions = c.val([MediaSessionInfo].self, .sessions) ?? []
    }
}

struct AudioInfo: Decodable, Equatable {
    var level: Double = 0
    var muted = false
    var device: String?

    enum CodingKeys: String, CodingKey { case level, muted, device }
    init(level: Double, muted: Bool, device: String?) { self.level = level; self.muted = muted; self.device = device }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        level = c.val(Double.self, .level) ?? 0
        muted = c.val(Bool.self, .muted) ?? false
        device = c.val(String.self, .device)
    }
}

struct MediaReply: Decodable {
    var ok: Bool
    var now: Double?
    var media: MediaInfo?
    enum CodingKeys: String, CodingKey { case ok, now, media }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = c.val(Bool.self, .ok) ?? false
        now = c.val(Double.self, .now)
        media = c.val(MediaInfo.self, .media)
    }
}

struct AudioReply: Decodable {
    var ok: Bool
    var audio: AudioInfo?
    enum CodingKeys: String, CodingKey { case ok, audio }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = c.val(Bool.self, .ok) ?? false
        audio = c.val(AudioInfo.self, .audio)
    }
}

struct HelloReply: Decodable {
    var app: String?
    var api: Int?
    var host: String?
}

// MARK: - The tidy model the screens draw

struct CPUInfo {
    var name = "CPU"
    var load: Double?
    var mhz: Double?
    var cores: [Double] = []
    var nCores: Int?
    var nThreads: Int?
    var temp: Double?
    var power: Double?
}

struct GPUInfo: Identifiable {
    var id: String
    var name: String
    var short: String
    var load: Double?
    var vram: Double?
    var vramTotal: Double?
    var temp: Double?
    var hot: Double?
    var clock: Double?
    var power: Double?
    var fan: Double?
}

struct MemInfo {
    var used: Double?
    var total: Double?
    var commit: Double?
    var commitLimit: Double?
    var pct: Double? {
        guard let u = used, let t = total, t > 0 else { return nil }
        return u / t * 100
    }
}

struct DriveInfo: Identifiable {
    var id: String { name }
    var name: String
    var label: String
    var size: Double
    var free: Double
    var usedPct: Double { size > 0 ? (size - free) / size * 100 : 0 }
}

struct DiskInfo {
    var read: Double?
    var write: Double?
    var active: Double?
    var drives: [DriveInfo] = []
    var temp: Double?
}

struct NetInfo {
    var rx: Double?
    var tx: Double?
    var ping: Double?
    var ip: String = ""
}

struct FanInfo: Identifiable {
    var id: String { name }
    var name: String
    var rpm: Double
}

enum TempKind { case cpu, gpu, storage, other }

struct TempItem: Identifiable {
    var id: String { name }
    var name: String
    var celsius: Double
    var kind: TempKind
}

struct ProcInfo: Identifiable {
    var id: String { name }
    var name: String
    var cpu: Double
    var mem: Double
}

struct BatteryInfo {
    var pct: Double
    var plugged: Bool
}

struct Snapshot {
    var host = "PC"
    var os = ""
    var time: Double = 0
    var uptime: Double?
    var hasLhm = false
    var cpu = CPUInfo()
    var gpus: [GPUInfo] = []
    var mem = MemInfo()
    var disk = DiskInfo()
    var net = NetInfo()
    var fans: [FanInfo] = []
    var temps: [TempItem] = []
    var power: Double?
    var battery: BatteryInfo?
    var procs: [ProcInfo] = []
}

/// One second of history.
struct Sample: Identifiable {
    var id: Date { t }
    var t: Date
    var cpu: Double?
    var gpu: Double?
    var mem: Double?
    var rx: Double?
    var tx: Double?
    var rd: Double?
    var wr: Double?
    var tcpu: Double?
    var tgpu: Double?
}
