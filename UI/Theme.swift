import SwiftUI
import UIKit
import CoreMotion

// Shared building blocks. Each one draws itself in the current style (see Design.swift).

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB, red: Double(hex >> 16 & 255) / 255, green: Double(hex >> 8 & 255) / 255,
                  blue: Double(hex & 255) / 255, opacity: alpha)
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat(hex >> 16 & 255) / 255, green: CGFloat(hex >> 8 & 255) / 255,
                  blue: CGFloat(hex & 255) / 255, alpha: alpha)
    }
}

extension Font {
    static func display(_ size: CGFloat, weight: Font.Weight = .light) -> Font { Theme.d.display(size, weight: weight) }
    static var eyebrow: Font { Theme.d.text(10.5, .semibold) }
    static var ui: Font { Theme.d.text(14) }
    static var uiMedium: Font { Theme.d.text(14, .medium) }
    static var small: Font { Theme.d.text(12) }
}

// MARK: - Shapes

/// A card outline: rounded, or with two opposite corners cut off (Cyberpunk's cut-metal plates).
struct Plate: InsettableShape {
    var radius: CGFloat
    var cut: CGFloat = 0
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        guard cut > 0 else {
            return Path(roundedRect: r, cornerRadius: max(0, radius - inset), style: .continuous)
        }
        let c = min(cut, min(r.width, r.height) / 2)
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - c, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + c))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + c, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY - c))
        p.closeSubpath()
        return p
    }

    func inset(by amount: CGFloat) -> Plate {
        var s = self
        s.inset += amount
        return s
    }
}

/// A flat-sided hexagon (Apex's control shape).
struct Hexagon: InsettableShape {
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        let c = CGPoint(x: r.midX, y: r.midY)
        let rad = min(r.width, r.height) / 2
        var p = Path()
        for i in 0..<6 {
            let a = CGFloat(i) * .pi / 3 - .pi / 2
            let pt = CGPoint(x: c.x + cos(a) * rad, y: c.y + sin(a) * rad)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }

    func inset(by amount: CGFloat) -> Hexagon {
        var s = self
        s.inset += amount
        return s
    }
}

extension Theme {
    /// The outline of small boxes (art, chips, pickers) in the current style.
    static var box: Plate { Plate(radius: d.radius, cut: min(d.cut, 8)) }

    /// The outline of a round control in the current style.
    static func control(_ size: CGFloat) -> AnyShape {
        switch d.style {
        case .apex: return AnyShape(Hexagon())
        case .cyber: return AnyShape(Plate(radius: 0, cut: size * 0.24))
        default: return AnyShape(Circle())
        }
    }
}

// MARK: - Labels

/// Section label. Every look sets it its own way (tracked capitals, sentence case, glyph-led
/// monospace, broad racing capitals...).
struct Eyebrow: View {
    var text: String
    var color: Color?
    init(_ text: String, color: Color? = nil) { self.text = text; self.color = color }

    var body: some View {
        switch Theme.style {
        case .gilded:
            Text(text.uppercased())
                .font(Theme.d.text(10.5, .semibold))
                .tracking(1.6)
                .foregroundStyle(color ?? Theme.label)
                .lineLimit(1)
        case .glass:
            Text(text)
                .font(Theme.d.text(13, .medium))
                .foregroundStyle(color ?? Theme.label)
                .lineLimit(1)
        case .paper:
            Text(text)
                .font(Theme.d.text(13))
                .foregroundStyle(color ?? Theme.label)
                .lineLimit(1)
        case .terminal:
            HStack(spacing: 6) {
                Text("▸").foregroundStyle(Theme.gold)
                Text(text.lowercased()).foregroundStyle(color ?? Theme.label)
            }
            .font(Theme.d.text(12.5))
            .lineLimit(1)
        case .reactor:
            Text(text)
                .font(Theme.d.text(13, .semibold))
                .foregroundStyle(color ?? Theme.label)
                .lineLimit(1)
        case .molten:
            Text(text)
                .font(Theme.d.text(13.5, .bold))
                .foregroundStyle(color ?? Theme.label)
                .lineLimit(1)
        case .apex:
            Text(text.uppercased())
                .font(.system(size: 10.5, weight: .medium).width(.expanded))
                .tracking(0.9)
                .foregroundStyle(color ?? Theme.label)
                .lineLimit(1)
        case .cyber:
            HStack(spacing: 7) {
                Rectangle().fill(color ?? Theme.label).frame(width: 5, height: 5)
                Text(text.uppercased())
                    .font(Theme.d.text(11, .semibold))
                    .tracking(2.6)
                    .foregroundStyle(color ?? Theme.label)
            }
            .lineLimit(1)
        }
    }
}

/// A card in the current style. `stage` marks the one hero panel of a page, which some looks
/// treat specially (Glass: luminous rim, Reactor: open black space, Cyberpunk: corner brackets).
struct Card<Content: View>: View {
    var title: String?
    var trailing: String?
    var padding: CGFloat = Theme.pad
    var stage = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        let inner = VStack(alignment: .leading, spacing: 14) {
            if title != nil || trailing != nil {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    if let title { Eyebrow(title) }
                    Spacer(minLength: 8)
                    if let trailing {
                        Text(Theme.style == .cyber || Theme.style == .apex ? trailing.uppercased() : trailing)
                            .font(.small)
                            .foregroundStyle(Theme.text3)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .truncationMode(.middle)
                    }
                }
            }
            content()
        }
        let d = Theme.d
        let shape = Plate(radius: d.radius, cut: d.cut)
        switch d.style {
        case .paper:
            // 19-86: no boxes, just a 1 px black rule above each block.
            inner
                .padding(.top, 12)
                .padding(.horizontal, 2)
                .padding(.bottom, 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .overlay(alignment: .top) { Rectangle().fill(Theme.ivory).frame(height: stage ? 2 : 1) }
        case .glass:
            inner
                .padding(padding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background {
                    shape.fill(.ultraThinMaterial)
                        .overlay(shape.fill(d.cardFill))
                }
                // The Resonance: edges catch the light; the hero panel gets a machined luminous rim.
                .overlay(shape.strokeBorder(
                    LinearGradient(colors: [Color.white.opacity(stage ? 0.55 : 0.30), Color.white.opacity(0.05), d.accent.opacity(stage ? 0.55 : 0.12)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: stage ? 1.5 : 1))
                .shadow(color: stage ? d.deco.opacity(0.45) : .black.opacity(0.25), radius: stage ? 22 : 10, y: 6)
        case .gilded:
            inner
                .padding(padding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(d.cardFill, in: shape)
                // The hairline is lit from the top left, like a gilt edge.
                .overlay(shape.strokeBorder(
                    LinearGradient(colors: [d.numeral.opacity(0.85), d.accent.opacity(0.30), d.accent.opacity(0.14)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1))
        case .reactor:
            // JetBrains: tinted panels, no borders, no shadows. The hero floats in open black.
            inner
                .padding(padding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(stage ? Color.clear : d.cardFill, in: shape)
        case .molten:
            inner
                .padding(padding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(LinearGradient(colors: [Color(hex: 0x1D1D1D), Color(hex: 0x121212)], startPoint: .top, endPoint: .bottom), in: shape)
                .overlay(shape.strokeBorder(d.hairline, lineWidth: 1))
        case .apex:
            inner
                .padding(padding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(stage ? Color.black : d.cardFill)
                .overlay(alignment: .top) { Rectangle().fill(stage ? d.accent : d.hairline).frame(height: stage ? 2 : 1) }
        case .cyber:
            inner
                .padding(padding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(d.cardFill, in: shape)
                .overlay(shape.strokeBorder(d.label.opacity(stage ? 0.75 : 0.30), lineWidth: 1))
                .overlay(alignment: .topLeading) { Rectangle().fill(d.label).frame(width: stage ? 54 : 22, height: 2) }
                .overlay(alignment: .bottomTrailing) {
                    Rectangle().fill(d.second.opacity(0.9)).frame(width: stage ? 34 : 12, height: 2)
                }
        case .terminal:
            inner
                .padding(padding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(d.cardFill, in: shape)
                .overlay(shape.strokeBorder(stage ? d.accent.opacity(0.45) : d.hairline, lineWidth: 1))
        }
    }
}

/// A meter. Capsules, flat rules or LED blocks depending on the look.
struct Meter: View {
    var value: Double   // 0...100
    var color: Color? = nil
    var height: CGFloat = 3

    var body: some View {
        let v = max(0, min(100, value))
        let c = color ?? Theme.signal
        Group {
            switch Theme.style {
            case .terminal, .cyber:
                GeometryReader { g in
                    let n = max(6, Int(g.size.width / 7))
                    let lit = Int((Double(n) * v / 100).rounded())
                    HStack(spacing: 2) {
                        ForEach(0..<n, id: \.self) { i in
                            Rectangle().fill(i < lit ? c : Theme.track)
                        }
                    }
                }
                .frame(height: max(5, height + 2))
                .shadow(color: c.opacity(0.45), radius: 3)
            case .paper, .apex:
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Theme.track)
                        Rectangle().fill(c).frame(width: max(1, g.size.width * CGFloat(v / 100)))
                    }
                }
                .frame(height: height)
            case .reactor:
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.track)
                        Capsule()
                            .fill(LinearGradient(colors: [c, color == nil ? Theme.ember : c], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(height, g.size.width * CGFloat(v / 100)))
                            .shadow(color: (color ?? Theme.ember).opacity(0.8), radius: 5)
                    }
                }
                .frame(height: height)
            default:
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.track)
                        Capsule().fill(c).frame(width: max(height, g.size.width * CGFloat(v / 100)))
                    }
                }
                .frame(height: height)
            }
        }
        .animation(.smooth(duration: 0.6), value: value)
    }
}

/// "Label    value unit" row used in the smaller cards.
struct StatRow: View {
    var label: String
    var value: String
    var unit: String = ""
    var valueColor: Color? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(label)
                .font(.small)
                .foregroundStyle(Theme.text2)
                .lineLimit(1)
            Spacer(minLength: 6)
            Text(value)
                .font(Theme.d.text(14, .medium).monospacedDigit())
                .foregroundStyle(valueColor ?? Theme.ivory)
                .contentTransition(.numericText())
            if !unit.isEmpty {
                Text(unit).font(.small).foregroundStyle(Theme.text3)
            }
        }
    }
}

// MARK: - Numerals

/// Device tilt for the metal highlights and the 3D numerals (the iPad's gyro). Read without
/// observation so it never causes extra redraws.
final class Motion {
    static let shared = Motion()
    private let manager = CMMotionManager()
    private(set) var tilt = CGPoint.zero
    private var users = 0

    func retain() {
        users += 1
        guard users == 1, manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 20
        manager.startDeviceMotionUpdates(to: .main) { [weak self] m, _ in
            guard let m else { return }
            let x = max(-1, min(1, m.attitude.roll / 0.6))
            let y = max(-1, min(1, m.attitude.pitch / 0.6))
            self?.tilt = CGPoint(x: x, y: y)
        }
    }

    func release() {
        users = max(0, users - 1)
        if users == 0 { manager.stopDeviceMotionUpdates() }
    }
}

/// Brushed metal leaf with a highlight that drifts and follows the tilt (Gilded: gold,
/// Molten: chrome).
struct MetalLeaf: ViewModifier {
    var enabled: Bool
    var hi: Color
    var mid: Color
    var low: Color

    func body(content: Content) -> some View {
        if enabled {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { ctx in
                let t = Float(ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2000))
                let tilt = Motion.shared.tilt
                content
                    .foregroundStyle(hi)
                    .visualEffect { view, proxy in
                        view.colorEffect(ShaderLibrary.goldFoil(
                            .float2(proxy.size),
                            .float(t),
                            .float2(Float(tilt.x), Float(tilt.y)),
                            .color(hi),
                            .color(mid),
                            .color(low)))
                    }
            }
            .onAppear { Motion.shared.retain() }
            .onDisappear { Motion.shared.release() }
        } else {
            content.foregroundStyle(LinearGradient(colors: [hi, hi, mid], startPoint: .top, endPoint: .bottom))
        }
    }
}

/// The dark side of an extruded numeral: the same glyphs stepped back and down.
struct Extrusion: View {
    var text: Text
    var size: CGFloat
    var color: Color

    var body: some View {
        let steps = max(2, min(7, Int((size * 0.06).rounded())))
        ZStack {
            ForEach(Array((1...steps).reversed()), id: \.self) { i in
                text
                    .foregroundStyle(color)
                    .offset(x: CGFloat(i) * 0.55, y: CGFloat(i) * 0.95)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Cyberpunk: the numeral with its colour channels knocked apart, jolting now and then.
struct Glitch: View {
    var text: Text
    var size: CGFloat
    var live: Bool

    var body: some View {
        if live && size >= 56 {
            TimelineView(.periodic(from: .now, by: 0.09)) { ctx in
                layers(shift(ctx.date))
            }
        } else {
            layers(CGSize(width: max(0.8, size * 0.014), height: 0))
        }
    }

    private func shift(_ date: Date) -> CGSize {
        let k = Int(date.timeIntervalSinceReferenceDate / 0.09)
        let burst = k % 61 < 3 || k % 97 == 0
        let w = burst ? size * 0.05 : max(0.8, size * 0.014)
        return CGSize(width: w, height: burst && k % 2 == 0 ? size * 0.02 : 0)
    }

    private func layers(_ s: CGSize) -> some View {
        ZStack {
            text.foregroundStyle(Theme.second.opacity(0.85)).offset(x: -s.width, y: -s.height)
            text.foregroundStyle(Theme.critical.opacity(0.85)).offset(x: s.width, y: s.height)
            text.foregroundStyle(Theme.aged)
        }
        .compositingGroup()
        .shadow(color: Theme.d.glow, radius: size * 0.10)
    }
}

/// The big readout numerals, in the current style, with a small unit beside them.
/// `solid` asks for the real 3D version where the look has one (hero numbers only).
struct BigNumber: View {
    @Environment(Store.self) private var store
    var value: String
    var unit: String = ""
    var size: CGFloat
    var color: Color? = nil   // a status colour replaces the style's colour
    var solid = false

    var body: some View {
        let d = Theme.d
        HStack(alignment: .firstTextBaseline, spacing: size * 0.06) {
            numeral
            if !unit.isEmpty {
                Text(d.style == .apex || d.style == .cyber ? unit.uppercased() : unit)
                    .font(unitFont)
                    .foregroundStyle(color ?? unitColor)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }

    private var unitFont: Font {
        let d = Theme.d
        switch d.style {
        case .apex: return .system(size: max(10, size * 0.16), weight: .medium).width(.expanded)
        case .cyber: return d.text(max(11, size * 0.2), .semibold)
        case .molten: return .system(size: max(13, size * 0.26), weight: .bold)
        default: return d.display(max(13, size * 0.26), weight: .regular)
        }
    }

    private var unitColor: Color {
        switch Theme.style {
        case .molten, .apex: return Theme.text3
        default: return Theme.gold
        }
    }

    private var face: Text {
        let d = Theme.d
        let k: CGFloat
        switch d.style {
        case .gilded: k = -0.04
        case .terminal, .paper: k = -0.02
        case .molten: k = -0.035
        case .reactor: k = -0.03
        case .apex: k = 0
        case .cyber: k = 0.01
        default: k = -0.014
        }
        return Text(value)
            .font(d.display(size))
            .tracking(size * k)
            .monospacedDigit()
    }

    @ViewBuilder private var numeral: some View {
        let d = Theme.d
        let fx = store.settings.effects
        if let color {
            face.foregroundStyle(color).contentTransition(.numericText())
        } else if solid, fx, let look = d.solid {
            SolidNumber(value: value, size: size, look: look)
        } else {
            switch d.style {
            case .gilded:
                face.modifier(MetalLeaf(enabled: fx, hi: d.numeral, mid: d.accent, low: d.deco))
                    .background { if size >= 26 { Extrusion(text: face, size: size, color: d.side) } }
                    .contentTransition(.numericText())
            case .molten:
                face.modifier(MetalLeaf(enabled: fx, hi: .white, mid: Color(hex: 0xC6C6C6), low: Color(hex: 0x7A7A7A)))
                    .background { if size >= 26 { Extrusion(text: face, size: size, color: d.side) } }
                    .contentTransition(.numericText())
            case .cyber:
                Glitch(text: face, size: size, live: fx)
            case .glass:
                face.foregroundStyle(d.numeral)
                    .shadow(color: d.glow.opacity(size >= 50 ? 0.9 : 0.5), radius: size * 0.16)
                    .contentTransition(.numericText())
            case .terminal:
                face.foregroundStyle(d.numeral)
                    .shadow(color: d.glow, radius: size * 0.12)
                    .contentTransition(.numericText())
            case .reactor:
                face.foregroundStyle(LinearGradient(colors: [.white, d.accent], startPoint: .top, endPoint: .bottom))
                    .shadow(color: d.glow, radius: size * 0.18)
                    .contentTransition(.numericText())
            default:
                face.foregroundStyle(d.numeral).contentTransition(.numericText())
            }
        }
    }
}

// MARK: - Navigation and buttons

/// Page link in the top bar, drawn per style.
struct NavLink: View {
    var title: String
    var active: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            label
                .fixedSize()
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .animation(.easeOut(duration: 0.2), value: active)
    }

    @ViewBuilder private var label: some View {
        switch Theme.style {
        case .gilded:
            VStack(spacing: 6) {
                Text(title.uppercased())
                    .font(Theme.d.text(12, .semibold))
                    .tracking(1.8)
                    .foregroundStyle(active ? Theme.gold : Theme.text3)
                Rectangle().fill(active ? Theme.gold : .clear).frame(height: 1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        case .paper:
            HStack(spacing: 7) {
                Circle().fill(active ? Theme.gold : .clear).frame(width: 6, height: 6)
                Text(title).font(Theme.d.text(15)).foregroundStyle(active ? Theme.ivory : Theme.text3)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        case .terminal:
            Text(title.lowercased())
                .font(Theme.d.text(13))
                .foregroundStyle(active ? Theme.d.onFill : Theme.text3)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(active ? Theme.fill : .clear, in: Capsule())
                .overlay(Capsule().strokeBorder(active ? Color.white.opacity(0.10) : .clear, lineWidth: 1))
        case .glass, .reactor:
            Text(title)
                .font(Theme.d.text(14, .medium))
                .foregroundStyle(active ? Theme.onFill : Theme.text2)
                .padding(.horizontal, Theme.style == .glass ? 18 : 16)
                .padding(.vertical, 9)
                .background(active ? Theme.fill : .clear, in: Capsule())
        case .molten:
            Text(title)
                .font(Theme.d.text(13.5, .bold))
                .foregroundStyle(active ? Color.black : Theme.text3)
                .padding(.horizontal, 15)
                .padding(.vertical, 8)
                .background {
                    if active {
                        Capsule().fill(LinearGradient(colors: [.white, Color(hex: 0xD9D6D6)], startPoint: .top, endPoint: .bottom))
                    }
                }
        case .apex:
            VStack(spacing: 7) {
                Text(title.uppercased())
                    .font(.system(size: 11.5, weight: .medium).width(.expanded))
                    .tracking(0.8)
                    .foregroundStyle(active ? Theme.ivory : Theme.text3)
                Rectangle().fill(active ? Theme.gold : .clear).frame(height: 2)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
        case .cyber:
            Text(title.uppercased())
                .font(Theme.d.text(12, .semibold))
                .tracking(2)
                .foregroundStyle(active ? Theme.onFill : Theme.text2)
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background { if active { Plate(radius: 0, cut: 7).fill(Theme.fill) } }
        }
    }
}

/// Round control (music transport, small toggles), drawn per style.
struct RingButton: View {
    var symbol: String
    var size: CGFloat = 44
    var filled = false
    var enabled = true
    var active = false
    var action: () -> Void

    @State private var taps = 0

    var body: some View {
        let shape = Theme.control(size)
        Button {
            taps += 1
            action()
        } label: {
            ZStack {
                shape.fill(face)
                if filled, Theme.style == .molten {
                    // three.tools: a translucent white sheen across the top of the orange key
                    shape.fill(LinearGradient(colors: [Color.white.opacity(0.38), .clear], startPoint: .top, endPoint: .center))
                }
                shape.stroke(stroke, lineWidth: 1)
                Image(systemName: symbol)
                    .font(.system(size: size * 0.36, weight: .semibold))
                    .foregroundStyle(filled ? Theme.onFill : (active ? Theme.gold : Theme.ivory))
                    .symbolEffect(.bounce, value: taps)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: size, height: size)
            .contentShape(shape)
            .shadow(color: filled ? glow : .clear, radius: size * 0.22)
        }
        .buttonStyle(PressScale())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
        .hoverEffect(.lift)
    }

    private var face: Color {
        if filled { return Theme.fill }
        switch Theme.style {
        case .terminal: return active ? Theme.fill : .clear
        case .molten: return Color(hex: 0x1A1A1A)
        case .reactor: return Color.white.opacity(0.06)
        default: return .clear
        }
    }

    private var glow: Color {
        switch Theme.style {
        case .reactor: return Theme.ember.opacity(0.7)
        case .cyber: return Theme.fill.opacity(0.55)
        case .molten: return Theme.fill.opacity(0.45)
        case .glass: return Theme.d.glow.opacity(0.7)
        default: return .clear
        }
    }

    private var stroke: Color {
        if filled { return Theme.style == .terminal ? Color.white.opacity(0.12) : .clear }
        return active ? Theme.gold : Theme.hairline
    }
}

struct PressScale: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

/// Fine dark display lines over the whole screen (Terminal, Cyberpunk).
struct Scanlines: View {
    private static let tile: UIImage = {
        let size = CGSize(width: 4, height: 4)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.black.withAlphaComponent(0.22).setFill()
            ctx.fill(CGRect(x: 0, y: 2, width: 4, height: 2))
        }
    }()

    var body: some View {
        Rectangle()
            .fill(ImagePaint(image: Image(uiImage: Self.tile), scale: 0.5))
            .allowsHitTesting(false)
            .ignoresSafeArea()
    }
}
