import SwiftUI
import CoreMotion

// Shared building blocks. Each one draws itself in the current style (see Design.swift).

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB, red: Double(hex >> 16 & 255) / 255, green: Double(hex >> 8 & 255) / 255,
                  blue: Double(hex & 255) / 255, opacity: alpha)
    }
}

extension Font {
    static func display(_ size: CGFloat, weight: Font.Weight = .light) -> Font { Theme.d.display(size, weight: weight) }
    static var eyebrow: Font { Theme.d.text(10.5, .semibold) }
    static var ui: Font { Theme.d.text(14) }
    static var uiMedium: Font { Theme.d.text(14, .medium) }
    static var small: Font { Theme.d.text(12) }
}

// MARK: - Labels

/// Section label. Gilded: tracked gold capitals. Glass: grey sentence case. Paper: black
/// sentence case. Terminal: lowercase monospace after an accent glyph.
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
        }
    }
}

/// A card in the current style.
struct Card<Content: View>: View {
    var title: String?
    var trailing: String?
    var padding: CGFloat = Theme.pad
    @ViewBuilder var content: () -> Content

    var body: some View {
        let inner = VStack(alignment: .leading, spacing: 14) {
            if title != nil || trailing != nil {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    if let title { Eyebrow(title) }
                    Spacer(minLength: 8)
                    if let trailing {
                        Text(trailing)
                            .font(.small)
                            .foregroundStyle(Theme.text3)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
            content()
        }
        switch Theme.style {
        case .paper:
            // 19-86: no boxes, just a 1 px black rule above each block.
            inner
                .padding(.top, 12)
                .padding(.horizontal, 2)
                .padding(.bottom, 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .overlay(alignment: .top) { Rectangle().fill(Theme.ivory).frame(height: 1) }
        case .glass:
            inner
                .padding(padding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background {
                    RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).fill(Theme.d.cardFill))
                }
                .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
                .shadow(color: .black.opacity(0.25), radius: 10, y: 6)
        default:
            inner
                .padding(padding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(Theme.d.cardFill, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
        }
    }
}

/// A meter. Gilded/Glass: thin capsule. Paper: flat rule. Terminal: LED blocks.
struct Meter: View {
    var value: Double   // 0...100
    var color: Color? = nil
    var height: CGFloat = 3

    var body: some View {
        let v = max(0, min(100, value))
        let c = color ?? Theme.signal
        Group {
            switch Theme.style {
            case .terminal:
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
            case .paper:
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Theme.track)
                        Rectangle().fill(c).frame(width: max(1, g.size.width * CGFloat(v / 100)))
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

// MARK: - Gold leaf numerals (Gilded)

/// Device tilt for the foil highlight (the iPad's gyro). Read without observation so it
/// never causes extra redraws; the foil's own 30 fps timeline picks it up.
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

struct GoldLeaf: ViewModifier {
    var enabled: Bool

    func body(content: Content) -> some View {
        let d = Theme.d
        if enabled {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { ctx in
                let t = Float(ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2000))
                let tilt = Motion.shared.tilt
                content
                    .foregroundStyle(d.numeral)
                    .visualEffect { view, proxy in
                        view.colorEffect(ShaderLibrary.goldFoil(
                            .float2(proxy.size),
                            .float(t),
                            .float2(Float(tilt.x), Float(tilt.y)),
                            .color(d.numeral),
                            .color(d.accent),
                            .color(d.deco)))
                    }
            }
            .onAppear { Motion.shared.retain() }
            .onDisappear { Motion.shared.release() }
        } else {
            content.foregroundStyle(LinearGradient(colors: [d.numeral, d.numeral, d.accent],
                                                   startPoint: .top, endPoint: .bottom))
        }
    }
}

/// The big readout numerals, in the current style, with a small unit beside them.
struct BigNumber: View {
    @Environment(Store.self) private var store
    var value: String
    var unit: String = ""
    var size: CGFloat
    var color: Color? = nil   // a status colour replaces the style's colour

    var body: some View {
        let d = Theme.d
        let tracking: CGFloat = d.style == .gilded ? -0.04 : d.style == .terminal ? -0.02 : d.style == .paper ? -0.02 : -0.014
        HStack(alignment: .firstTextBaseline, spacing: size * 0.06) {
            Group {
                let text = Text(value)
                    .font(d.display(size))
                    .tracking(size * tracking)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                if let color {
                    text.foregroundStyle(color)
                } else if d.foil {
                    text.modifier(GoldLeaf(enabled: store.settings.effects))
                } else {
                    text.foregroundStyle(d.numeral)
                }
            }
            if !unit.isEmpty {
                Text(unit)
                    .font(d.display(max(13, size * 0.26), weight: .regular))
                    .foregroundStyle(color ?? Theme.gold)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
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
        case .glass:
            Text(title)
                .font(Theme.d.text(14, .medium))
                .foregroundStyle(active ? Theme.onFill : Theme.text2)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(active ? Theme.fill : .clear, in: Capsule())
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
        Button {
            taps += 1
            action()
        } label: {
            ZStack {
                Circle().fill(filled ? Theme.fill : (active && Theme.style == .terminal ? Theme.fill : Color.clear))
                Circle().strokeBorder(stroke, lineWidth: 1)
                Image(systemName: symbol)
                    .font(.system(size: size * 0.36, weight: .semibold))
                    .foregroundStyle(filled ? Theme.onFill : (active ? Theme.gold : Theme.ivory))
                    .symbolEffect(.bounce, value: taps)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: size, height: size)
            .contentShape(Circle())
        }
        .buttonStyle(PressScale())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
        .hoverEffect(.lift)
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
