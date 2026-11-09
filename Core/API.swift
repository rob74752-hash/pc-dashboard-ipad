import Foundation
import UIKit
import CoreImage

/// Talking to the PC Dashboard server on the PC (server.ps1, port 8090 by default).
enum API {
    static let defaultPort = 8090

    private static let session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 4
        c.timeoutIntervalForResource = 8
        c.requestCachePolicy = .reloadIgnoringLocalCacheData
        c.httpMaximumConnectionsPerHost = 4
        c.waitsForConnectivity = false
        return URLSession(configuration: c)
    }()

    private static let probeSession: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 1.2
        c.timeoutIntervalForResource = 2
        c.requestCachePolicy = .reloadIgnoringLocalCacheData
        c.httpMaximumConnectionsPerHost = 2
        c.waitsForConnectivity = false
        return URLSession(configuration: c)
    }()

    /// "http://192.168.4.26:8090/" or "192.168.4.26" -> "192.168.4.26:8090"
    static func normalize(_ input: String) -> String? {
        var s = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for p in ["http://", "https://"] where s.hasPrefix(p) { s.removeFirst(p.count) }
        if let slash = s.firstIndex(of: "/") { s = String(s[..<slash]) }
        guard !s.isEmpty, !s.contains(" ") else { return nil }
        if !s.contains(":") { s += ":\(defaultPort)" }
        guard URL(string: "http://" + s + "/") != nil else { return nil }
        return s
    }

    static func url(_ address: String, _ path: String, _ query: [String: String] = [:]) -> URL? {
        guard var c = URLComponents(string: "http://" + address + path) else { return nil }
        if !query.isEmpty { c.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) } }
        return c.url
    }

    struct Payload {
        var ready: Bool
        var api: Int
        var time: Double
        var now: Double?
        var media: MediaInfo?
        var audio: AudioInfo?
        var snap: Snapshot
    }

    /// Fetches and interprets one second of stats (off the main thread).
    static func stats(_ address: String) async throws -> Payload {
        guard let u = url(address, "/api/stats") else { throw URLError(.badURL) }
        let (data, resp) = try await session.data(from: u)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let raw = try JSONDecoder().decode(RawStats.self, from: data)
        let snap = raw.ready ? Interpret.snapshot(raw) : Snapshot()
        return Payload(ready: raw.ready, api: raw.api ?? 1, time: raw.time ?? 0, now: raw.now,
                       media: raw.media, audio: raw.audio, snap: snap)
    }

    static func post<T: Decodable>(_ address: String, _ path: String, _ query: [String: String] = [:]) async throws -> T {
        guard let u = url(address, path, query) else { throw URLError(.badURL) }
        var req = URLRequest(url: u)
        req.httpMethod = "POST"
        req.setValue("0", forHTTPHeaderField: "Content-Length")
        let (data, resp) = try await session.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// Is a PC Dashboard listening here? Returns its name. Also accepts older servers
    /// (before the iPad app existed) by reading /api/stats.
    static func hello(_ address: String, allowOld: Bool = false) async -> String? {
        if let u = url(address, "/api/hello"),
           let r = try? await probeSession.data(from: u),
           (r.1 as? HTTPURLResponse)?.statusCode == 200,
           let h = try? JSONDecoder().decode(HelloReply.self, from: r.0), h.app == "pcdash" {
            return h.host ?? "PC"
        }
        guard allowOld, let u = url(address, "/api/stats"),
              let r = try? await session.data(from: u),
              (r.1 as? HTTPURLResponse)?.statusCode == 200,
              let raw = try? JSONDecoder().decode(RawStats.self, from: r.0), raw.cpu != nil || !raw.ready else { return nil }
        return raw.info?.host ?? "PC"
    }

    struct Art {
        var image: UIImage
        var tint: UIColor
    }

    /// Album art plus its average colour (for the soft glow behind it).
    static func art(_ address: String, key: String) async -> Art? {
        guard let u = url(address, "/api/media/art", ["k": key]),
              let r = try? await session.data(from: u),
              (r.1 as? HTTPURLResponse)?.statusCode == 200,
              let img = UIImage(data: r.0) else { return nil }
        let ready = img.preparingForDisplay() ?? img
        return Art(image: ready, tint: averageColor(img) ?? UIColor(red: 0.8, green: 0.57, blue: 0.4, alpha: 1))
    }

    private static let ciContext = CIContext(options: [.workingColorSpace: NSNull()])

    static func averageColor(_ image: UIImage) -> UIColor? {
        guard let input = CIImage(image: image) else { return nil }
        let extent = input.extent
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [
            kCIInputImageKey: input, kCIInputExtentKey: CIVector(cgRect: extent),
        ]), let out = filter.outputImage else { return nil }
        var px = [UInt8](repeating: 0, count: 4)
        ciContext.render(out, toBitmap: &px, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                         format: .RGBA8, colorSpace: nil)
        return UIColor(red: CGFloat(px[0]) / 255, green: CGFloat(px[1]) / 255, blue: CGFloat(px[2]) / 255, alpha: 1)
    }
}
