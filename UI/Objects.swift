import SwiftUI
import UIKit

// Each look's signature object, and the drawn (not SceneKit) pieces: the lens of light,
// the ASCII torus, the rev counter, the wireframe ground, the ticker and the record.

/// The current look's object, reacting to how hard the PC is working.
struct HeroObject: View {
    @Environment(Store.self) private var store

    var body: some View {
        let d = Theme.d
        let s = store.snap
        let cpu = max(0, min(1, (s?.cpu.load ?? 0) / 100))
        let gpu = max(0, min(1, (s?.gpus.first?.load ?? 0) / 100))
        let mem = max(0, min(1, (s?.mem.pct ?? 0) / 100))
        let live = store.settings.effects
        switch d.style {
        case .glass:
            LightOrb(energy: cpu, live: live)
        case .terminal:
            AsciiTorus(energy: cpu, color: d.accent, live: live)
        case .apex:
            Tachometer(value: cpu * 100)
        case .gilded:
            solid(.gold, cpu, [cpu, gpu, mem], live)
        case .paper:
            solid(.ink, cpu, [cpu, gpu, mem], live)
        case .reactor:
            solid(.plasma, cpu, [cpu, gpu, mem], live)
        case .molten:
            solid(.trefoil, cpu, [cpu, gpu, mem], live)
        case .cyber:
            solid(.wire, cpu, [cpu, gpu, mem], live)
                .shadow(color: d.second.opacity(0.55), radius: 10)
        }
    }

    private func solid(_ kind: ObjectKind, _ energy: Double, _ values: [Double], _ live: Bool) -> some View {
        let d = Theme.d
        return CoreObject(kind: kind, main: UIColor(hex: d.mainHex), hi: UIColor(hex: d.hiHex), deep: UIColor(hex: d.deepHex),
                          second: UIColor(hex: d.secondHex), energy: energy, values: values, live: live)
            .aspectRatio(1, contentMode: .fit)
            .allowsHitTesting(false)
    }
}

/// Glass: a lens with slow currents of light inside (a shader, see Shaders.metal).
struct LightOrb: View {
    var energy: Double
    var live: Bool

    var body: some View {
        let d = Theme.d
        let hi = d.accent, mid = Color(hex: d.mainHex), low = d.deco
        let e = Float(max(0, min(1, energy)))
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !live)) { ctx in
            let t = Float(ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 4000))
            Rectangle()
                .fill(Color.white)
                .visualEffect { view, proxy in
                    view.colorEffect(ShaderLibrary.lightOrb(
                        .float2(proxy.size),
                        .float(t),
                        .float(e),
                        .color(hi),
                        .color(mid),
                        .color(low)))
                }
        }
        .aspectRatio(1, contentMode: .fit)
        .allowsHitTesting(false)
    }
}

/// Terminal: the classic spinning torus, drawn from text characters.
struct AsciiTorus: View {
    var energy: Double
    var color: Color
    var live: Bool

    private static let ramp = Array(".,-~:;=!*#$@")

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12, paused: !live)) { ctx in
            Canvas { g, size in
                let t = ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 10000)
                let font: CGFloat = size.width > 300 ? 11 : 7.5
                let cw = font * 0.602, ch = font * 1.18
                let cols = max(8, Int(size.width / cw)), rows = max(6, Int(size.height / ch))
                let lines = Self.frame(cols: cols, rows: rows, a: t * 0.85, b: t * 0.42, aspect: Double(cw / ch))
                let glow = 0.55 + 0.45 * energy
                for (r, line) in lines.enumerated() {
                    g.draw(Text(line).font(.system(size: font, design: .monospaced)).foregroundColor(color.opacity(glow)),
                           at: CGPoint(x: 0, y: CGFloat(r) * ch), anchor: .topLeading)
                }
            }
        }
        .shadow(color: color.opacity(0.5), radius: 6)
        .allowsHitTesting(false)
    }

    /// One frame of the torus as rows of characters.
    static func frame(cols: Int, rows: Int, a: Double, b: Double, aspect: Double) -> [String] {
        var out = [[Character]](repeating: [Character](repeating: " ", count: cols), count: rows)
        var depth = [[Double]](repeating: [Double](repeating: 0, count: cols), count: rows)
        let r1 = 1.0, r2 = 2.0, k2 = 5.0
        // Scale so the torus fills the smaller side of the grid.
        let k1 = min(Double(cols) * 0.46, Double(rows) * 0.46 / aspect) * k2 / (r1 + r2)
        let cosA = cos(a), sinA = sin(a), cosB = cos(b), sinB = sin(b)
        var theta = 0.0
        while theta < 2 * Double.pi {
            let cosT = cos(theta), sinT = sin(theta)
            var phi = 0.0
            while phi < 2 * Double.pi {
                let cosP = cos(phi), sinP = sin(phi)
                let cx = r2 + r1 * cosT, cy = r1 * sinT
                let x = cx * (cosB * cosP + sinA * sinB * sinP) - cy * cosA * sinB
                let y = cx * (sinB * cosP - sinA * cosB * sinP) + cy * cosA * cosB
                let z = k2 + cosA * cx * sinP + cy * sinA
                let ooz = 1 / z
                let xp = Int(Double(cols) / 2 + k1 * ooz * x)
                let yp = Int(Double(rows) / 2 - k1 * ooz * y * aspect)
                if xp >= 0, xp < cols, yp >= 0, yp < rows, ooz > depth[yp][xp] {
                    let l = cosP * cosT * sinB - cosA * cosT * sinP - sinA * sinT + cosB * (cosA * sinT - cosT * sinA * sinP)
                    depth[yp][xp] = ooz
                    let i = max(0, min(ramp.count - 1, Int(l * 8)))
                    out[yp][xp] = ramp[i]
                }
                phi += 0.03
            }
            theta += 0.09
        }
        return out.map { String($0) }
    }
}

/// Apex: a rev counter. 0-100 % around 270 degrees, a redline from 85, a lit needle.
struct Tachometer: View {
    var value: Double

    var body: some View {
        TachDial(value: max(0, min(100, value)))
            .animation(.smooth(duration: 0.8), value: value)
            .aspectRatio(1, contentMode: .fit)
    }
}

struct TachDial: View, Animatable {
    var value: Double

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        let d = Theme.d
        Canvas { g, size in
            let r = min(size.width, size.height) / 2 - 4
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            func angle(_ v: Double) -> Double { (135 + 270 * v / 100) * Double.pi / 180 }
            func point(_ v: Double, _ k: CGFloat) -> CGPoint {
                let a = angle(v)
                return CGPoint(x: c.x + CGFloat(cos(a)) * r * k, y: c.y + CGFloat(sin(a)) * r * k)
            }

            // The ticks: a short one every 2 %, a long one every 10 %.
            for i in 0...50 {
                let v = Double(i) * 2
                let major = i % 5 == 0
                var tick = Path()
                tick.move(to: point(v, major ? 0.86 : 0.92))
                tick.addLine(to: point(v, 1.0))
                let tone: Color = v >= 85 ? Theme.critical : (v <= value ? d.ink : d.ink3.opacity(0.75))
                g.stroke(tick, with: .color(tone), lineWidth: major ? 2 : 1)
            }

            // The numbers 0...10 inside the long ticks.
            let numSize = max(8, r * 0.105)
            for i in 0...10 {
                let v = Double(i) * 10
                let tone: Color = v >= 85 ? Theme.critical : d.ink2
                g.draw(Text("\(i)").font(.system(size: numSize, weight: .semibold).width(.compressed)).foregroundColor(tone),
                       at: point(v, 0.74), anchor: .center)
            }

            // The swept band.
            var band = Path()
            band.addArc(center: c, radius: r * 0.60, startAngle: .radians(angle(0)), endAngle: .radians(angle(100)), clockwise: false)
            g.stroke(band, with: .color(d.track), style: StrokeStyle(lineWidth: r * 0.055, lineCap: .butt))
            if value > 0.3 {
                var swept = Path()
                swept.addArc(center: c, radius: r * 0.60, startAngle: .radians(angle(0)), endAngle: .radians(angle(min(value, 85))), clockwise: false)
                g.stroke(swept, with: .color(d.signal), style: StrokeStyle(lineWidth: r * 0.055, lineCap: .butt))
            }
            if value > 85 {
                var red = Path()
                red.addArc(center: c, radius: r * 0.60, startAngle: .radians(angle(85)), endAngle: .radians(angle(value)), clockwise: false)
                g.stroke(red, with: .color(Theme.critical), style: StrokeStyle(lineWidth: r * 0.055, lineCap: .butt))
            }

            // The needle, lit in the one action colour.
            var needle = Path()
            needle.move(to: point(value, 0.50))
            needle.addLine(to: point(value, 0.98))
            var lit = g
            lit.addFilter(.shadow(color: d.accent.opacity(0.9), radius: 7))
            lit.stroke(needle, with: .color(d.accent), style: StrokeStyle(lineWidth: max(2, r * 0.022), lineCap: .butt))
        }
    }
}

/// Cyberpunk: a wireframe ground rushing toward you along the bottom of the screen.
struct WireTerrain: View {
    var color: Color
    var live: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !live)) { ctx in
            Canvas { g, size in
                let t = ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1000)
                let horizon = size.height * 0.66
                let depth = size.height - horizon
                guard depth > 4 else { return }
                let mid = size.width / 2

                var rays = Path()
                for i in -16...16 {
                    let far = CGPoint(x: mid + CGFloat(i) * size.width * 0.012, y: horizon)
                    let near = CGPoint(x: mid + CGFloat(i) * size.width * 0.17, y: size.height)
                    rays.move(to: far)
                    rays.addLine(to: near)
                }
                g.stroke(rays, with: .linearGradient(Gradient(colors: [color.opacity(0), color.opacity(0.26)]),
                                                     startPoint: CGPoint(x: 0, y: horizon), endPoint: CGPoint(x: 0, y: size.height)),
                         lineWidth: 1)

                let phase = live ? (t * 0.35).truncatingRemainder(dividingBy: 1) : 0.4
                for k in 0..<16 {
                    let z = Double(k) + 1 - phase
                    let y = horizon + depth / CGFloat(1 + z * 0.9)
                    var line = Path()
                    line.move(to: CGPoint(x: 0, y: y))
                    line.addLine(to: CGPoint(x: size.width, y: y))
                    g.stroke(line, with: .color(color.opacity(0.26 / (1 + z * 0.55))), lineWidth: 1)
                }

                var edge = Path()
                edge.move(to: CGPoint(x: 0, y: horizon))
                edge.addLine(to: CGPoint(x: size.width, y: horizon))
                g.stroke(edge, with: .color(color.opacity(0.30)), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
    }
}

/// A line of text that scrolls forever (Cyberpunk's status strip).
struct Ticker: View {
    var text: String
    var color: Color
    var live: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !live)) { ctx in
            Canvas { g, size in
                let line = g.resolve(Text(text).font(Theme.d.text(10.5, .semibold)).tracking(2.4).foregroundColor(color))
                let w = max(40, line.measure(in: CGSize(width: 20000, height: 40)).width)
                let t = ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 100000)
                var x = -CGFloat((t * 34).truncatingRemainder(dividingBy: Double(w)))
                while x < size.width {
                    g.draw(line, at: CGPoint(x: x, y: size.height / 2), anchor: .leading)
                    x += w
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Four corner brackets, like a targeting frame.
struct CornerBrackets: View {
    var color: Color
    var length: CGFloat = 14

    var body: some View {
        Canvas { g, size in
            var p = Path()
            let l = min(length, min(size.width, size.height) / 3)
            let w = size.width, h = size.height
            p.move(to: CGPoint(x: 0, y: l)); p.addLine(to: .zero); p.addLine(to: CGPoint(x: l, y: 0))
            p.move(to: CGPoint(x: w - l, y: 0)); p.addLine(to: CGPoint(x: w, y: 0)); p.addLine(to: CGPoint(x: w, y: l))
            p.move(to: CGPoint(x: w, y: h - l)); p.addLine(to: CGPoint(x: w, y: h)); p.addLine(to: CGPoint(x: w - l, y: h))
            p.move(to: CGPoint(x: l, y: h)); p.addLine(to: CGPoint(x: 0, y: h)); p.addLine(to: CGPoint(x: 0, y: h - l))
            g.stroke(p, with: .color(color), lineWidth: 1.5)
        }
        .allowsHitTesting(false)
    }
}

/// A record that turns while the music plays, peeking out from behind the artwork.
struct Vinyl: View {
    var tint: Color
    var playing: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !playing)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600)
            GeometryReader { g in
                let s = min(g.size.width, g.size.height)
                ZStack {
                    Circle().fill(Color(hex: 0x0A0A0A))
                    // grooves
                    ForEach(0..<7, id: \.self) { i in
                        Circle()
                            .stroke(Color.white.opacity(i % 2 == 0 ? 0.07 : 0.035), lineWidth: 1)
                            .padding(s * (0.05 + CGFloat(i) * 0.042))
                    }
                    // the light across the grooves stays put while the record turns
                    Circle()
                        .fill(AngularGradient(colors: [.clear, Color.white.opacity(0.16), .clear, .clear, Color.white.opacity(0.10), .clear, .clear],
                                              center: .center))
                        .padding(s * 0.03)
                    ZStack {
                        Circle().fill(tint)
                        Circle().fill(LinearGradient(colors: [Color.white.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom))
                        Rectangle().fill(Color.black.opacity(0.55)).frame(width: s * 0.16, height: 2).offset(y: -s * 0.09)
                        Circle().fill(Color.black).frame(width: s * 0.035, height: s * 0.035)
                    }
                    .frame(width: s * 0.34, height: s * 0.34)
                    .rotationEffect(.degrees(t * 200))
                    Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                }
                .frame(width: s, height: s)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .allowsHitTesting(false)
    }
}
