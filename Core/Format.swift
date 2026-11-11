import Foundation

/// Number formatting shared by every screen. Temperatures stay in °C inside the app.
enum Fmt {
    static func pct(_ v: Double?) -> String {
        guard let v, v.isFinite else { return "--" }
        return String(Int(v.rounded()))
    }

    static func gb(_ bytes: Double?, digits: Int = 1) -> String {
        guard let b = bytes, b.isFinite else { return "--" }
        return String(format: "%.\(digits)f", b / 1_073_741_824)
    }

    static func bytes(_ b: Double?) -> String {
        guard let b, b.isFinite else { return "--" }
        if b >= 1_099_511_627_776 { return String(format: "%.1f TB", b / 1_099_511_627_776) }
        if b >= 1_073_741_824 { return String(format: "%.1f GB", b / 1_073_741_824) }
        if b >= 1_048_576 { return "\(Int((b / 1_048_576).rounded())) MB" }
        return "\(Int((b / 1024).rounded())) KB"
    }

    /// Network speed (input in bytes per second, shown in bits): ("94.2", "Mb/s")
    static func bits(_ bps: Double?) -> (String, String) {
        let b = (bps ?? 0) * 8
        if b >= 1e9 { return (String(format: "%.2f", b / 1e9), "Gb/s") }
        if b >= 1e6 { return (String(format: b >= 1e8 ? "%.0f" : "%.1f", b / 1e6), "Mb/s") }
        return (String(format: "%.0f", b / 1e3), "Kb/s")
    }

    /// Disk speed: ("312", "MB/s")
    static func byteRate(_ v: Double?) -> (String, String) {
        let b = v ?? 0
        if b >= 1_073_741_824 { return (String(format: "%.2f", b / 1_073_741_824), "GB/s") }
        if b >= 1_048_576 { return (String(format: b >= 104_857_600 ? "%.0f" : "%.1f", b / 1_048_576), "MB/s") }
        return (String(format: "%.0f", b / 1024), "KB/s")
    }

    static func bitsText(_ v: Double?) -> String { let r = bits(v); return r.0 + " " + r.1 }
    static func byteRateText(_ v: Double?) -> String { let r = byteRate(v); return r.0 + " " + r.1 }

    static func tempValue(_ c: Double?, fahrenheit: Bool) -> Int? {
        guard let c, c.isFinite else { return nil }
        return Int((fahrenheit ? c * 9 / 5 + 32 : c).rounded())
    }

    static func temp(_ c: Double?, fahrenheit: Bool) -> String {
        guard let v = tempValue(c, fahrenheit: fahrenheit) else { return "--" }
        return "\(v)°"
    }

    static func ghz(_ mhz: Double?) -> String {
        guard let mhz, mhz.isFinite, mhz > 0 else { return "--" }
        return String(format: "%.2f", mhz / 1000)
    }

    static func watts(_ w: Double?) -> String {
        guard let w, w.isFinite else { return "--" }
        return String(Int(w.rounded()))
    }

    /// Energy used: ("412", "Wh") or ("1.24", "kWh")
    static func energy(_ wh: Double) -> (String, String) {
        if wh >= 1000 { return (String(format: "%.2f", wh / 1000), "kWh") }
        if wh >= 10 { return (String(Int(wh.rounded())), "Wh") }
        return (String(format: "%.1f", wh), "Wh")
    }

    static func uptime(_ ms: Double?) -> String {
        guard let ms, ms.isFinite, ms > 0 else { return "--" }
        let s = Int(ms / 1000)
        let d = s / 86400, h = s % 86400 / 3600, m = s % 3600 / 60
        if d > 0 { return "\(d)d \(h)h" }
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    static func duration(_ secs: Double?) -> String {
        guard let secs, secs.isFinite, secs >= 0 else { return "--:--" }
        let s = Int(secs.rounded(.down))
        if s >= 3600 { return String(format: "%d:%02d:%02d", s / 3600, s % 3600 / 60, s % 60) }
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    // Thresholds in °C: [warm, hot, critical]
    static func level(_ c: Double?, _ kind: TempKind) -> Int {
        guard let c, c.isFinite else { return -1 }
        let l: [Double]
        switch kind {
        case .cpu: l = [75, 88, 95]
        case .gpu: l = [75, 85, 95]
        case .storage: l = [55, 65, 75]
        case .other: l = [60, 75, 90]
        }
        return c >= l[2] ? 3 : c >= l[1] ? 2 : c >= l[0] ? 1 : 0
    }

    static let levelWords = ["Normal", "Warm", "Hot", "Critical"]

    static func clock(_ date: Date, h24: Bool) -> (hm: String, s: String, ampm: String) {
        let c = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        let h = c.hour ?? 0, m = c.minute ?? 0, s = c.second ?? 0
        let hh = h24 ? String(format: "%02d", h) : String(h % 12 == 0 ? 12 : h % 12)
        return (hh + ":" + String(format: "%02d", m), String(format: "%02d", s), h24 ? "" : (h >= 12 ? "PM" : "AM"))
    }

    static func dateLine(_ date: Date) -> String {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("EEEEdMMMM")
        return f.string(from: date)
    }
}
