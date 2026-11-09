import SwiftUI
import CoreMotion

// Design lock (refero-design research, Nov 2026)
// Primary: Atoms ("black steel, golden inscription"): absolute black, ivory text, weathered gold
//          for labels/headings/interactive highlights, flat 4 pt cards drawn with 1 px gold hairlines.
// Borrowed: 601 Inc. - oversized aged-gold display numerals, tight -0.04 em tracking, gold
//           nav links with a 1 px underline. Slash - a warm golden gradient used ONLY for
//           decorative depth (glows, chart fills), never as a surface or text colour.
// Charts follow Gentler Streak: title left, range right, faint grid, dashed average line.
// Ember/red are status colours only (hot / critical temperatures).

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB, red: Double(hex >> 16 & 255) / 255, green: Double(hex >> 8 & 255) / 255,
                  blue: Double(hex & 255) / 255, opacity: alpha)
    }
}

enum Theme {
    static let canvas = Color.black
    static let ivory = Color(hex: 0xFFF7DD)      // primary text, hairline dividers
    static let gold = Color(hex: 0xC8AD86)       // labels, headings, active controls, live data lines
    static let aged = Color(hex: 0xECE4B4)       // big display numerals only
    static let ember = Color(hex: 0xCC9166)      // decorative gradients only
    static let hot = Color(hex: 0xE58A4A)        // status: hot
    static let critical = Color(hex: 0xEF5A4C)   // status: critical / offline

    static let text2 = ivory.opacity(0.62)
    static let text3 = ivory.opacity(0.40)
    static let hairline = gold.opacity(0.30)
    static let track = ivory.opacity(0.10)
    static let raised = Color(hex: 0x0E0C09)     // pressed / selected fills

    static let radius: CGFloat = 4
    static let pad: CGFloat = 20
    static let gap: CGFloat = 8

    static func levelColor(_ level: Int) -> Color {
        switch level {
        case 3: return critical
        case 2: return hot
        case 1: return aged
        default: return gold
        }
    }

    /// Decorative gold-to-ember gradient (fills, glows).
    static var gleam: LinearGradient {
        LinearGradient(colors: [aged, gold, ember], startPoint: .top, endPoint: .bottom)
    }
}

extension Font {
    /// Wide, light numerals for big readouts (stand-in for 601's changeling-neo).
    static func display(_ size: CGFloat, weight: Font.Weight = .light) -> Font {
        .system(size: size, weight: weight).width(.expanded)
    }
    static let eyebrow = Font.system(size: 10.5, weight: .semibold)
    static let ui = Font.system(size: 14, weight: .regular)
    static let uiMedium = Font.system(size: 14, weight: .medium)
    static let small = Font.system(size: 12, weight: .regular)
}

// MARK: - Small building blocks

/// Tracked uppercase label in weathered gold ("PROCESSOR").
struct Eyebrow: View {
    var text: String
    var color: Color = Theme.gold
    init(_ text: String, color: Color = Theme.gold) { self.text = text; self.color = color }
    var body: some View {
        Text(text.uppercased())
            .font(.eyebrow)
            .tracking(1.6)
            .foregroundStyle(color)
            .lineLimit(1)
    }
}

/// Flat black card with a 1 px gold hairline and a 4 pt radius.
struct Card<Content: View>: View {
    var title: String?
    var trailing: String?
    var padding: CGFloat = Theme.pad
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
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
        .padding(padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.canvas)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).strokeBorder(Theme.hairline, lineWidth: 1))
    }
}

/// A hairline meter: thin ivory track, gold fill.
struct Meter: View {
    var value: Double   // 0...100
    var color: Color = Theme.gold
    var height: CGFloat = 3

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track)
                Capsule().fill(color)
                    .frame(width: max(height, g.size.width * CGFloat(max(0, min(100, value)) / 100)))
            }
        }
        .frame(height: height)
        .animation(.smooth(duration: 0.6), value: value)
    }
}

/// "Label    value unit" row used in the smaller cards.
struct StatRow: View {
    var label: String
    var value: String
    var unit: String = ""
    var valueColor: Color = Theme.ivory

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(label)
                .font(.small)
                .foregroundStyle(Theme.text2)
                .lineLimit(1)
            Spacer(minLength: 6)
            Text(value)
                .font(.system(size: 14, weight: .medium).monospacedDigit())
                .foregroundStyle(valueColor)
                .contentTransition(.numericText())
            if !unit.isEmpty {
                Text(unit).font(.small).foregroundStyle(Theme.text3)
            }
        }
    }
}

// MARK: - Gold leaf numerals

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
        if enabled {
            TimelineView(.animation(minimumInterval: 1.0 / 30)) { ctx in
                let t = Float(ctx.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2000))
                let tilt = Motion.shared.tilt
                content
                    .foregroundStyle(Theme.aged)
                    .visualEffect { view, proxy in
                        view.colorEffect(ShaderLibrary.goldFoil(
                            .float2(proxy.size),
                            .float(t),
                            .float2(Float(tilt.x), Float(tilt.y))))
                    }
            }
            .onAppear { Motion.shared.retain() }
            .onDisappear { Motion.shared.release() }
        } else {
            content.foregroundStyle(LinearGradient(colors: [Color(hex: 0xF4EAC4), Theme.aged, Theme.gold],
                                                   startPoint: .top, endPoint: .bottom))
        }
    }
}

/// Oversized wide numerals in gold leaf, with a small unit set beside them.
struct BigNumber: View {
    @Environment(Store.self) private var store
    var value: String
    var unit: String = ""
    var size: CGFloat
    var color: Color? = nil   // a status colour replaces the gold

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: size * 0.06) {
            numerals
            if !unit.isEmpty {
                Text(unit)
                    .font(.display(max(13, size * 0.26), weight: .regular))
                    .foregroundStyle(color ?? Theme.gold)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }

    @ViewBuilder private var numerals: some View {
        let text = Text(value)
            .font(.display(size))
            .tracking(-size * 0.04)
            .monospacedDigit()
            .contentTransition(.numericText())
        if let color {
            text.foregroundStyle(color)
        } else {
            text.modifier(GoldLeaf(enabled: store.settings.effects))
        }
    }
}

/// The gold nav link from 601: gold text, 1 px underline when active.
struct NavLink: View {
    var title: String
    var active: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(title.uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(1.8)
                    .foregroundStyle(active ? Theme.gold : Theme.text3)
                Rectangle()
                    .fill(active ? Theme.gold : .clear)
                    .frame(height: 1)
            }
            .fixedSize()
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .animation(.easeOut(duration: 0.2), value: active)
    }
}

/// Round gold-outline control (music transport, small toggles).
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
                Circle()
                    .fill(filled ? Theme.gold : Color.clear)
                Circle()
                    .strokeBorder(filled ? Color.clear : (active ? Theme.gold : Theme.hairline), lineWidth: 1)
                Image(systemName: symbol)
                    .font(.system(size: size * 0.36, weight: .semibold))
                    .foregroundStyle(filled ? Color.black : (active ? Theme.gold : Theme.ivory))
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
}

struct PressScale: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}
