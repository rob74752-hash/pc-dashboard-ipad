import SwiftUI

// The four looks the app can wear, each locked to its own references (refero-design research).
//
// GILDED  - Atoms (absolute black, ivory text, weathered-gold labels, flat 4 pt cards with 1 px
//           gold hairlines) + 601 Inc. (oversized wide numerals, gold nav underline)
//           + Slash (warm gradient for decoration only). Big numerals are gold leaf.
// GLASS   - Dimension: #0A0A0A canvas lit by a cool-blue-to-warm-beige glow, translucent
//           blurred cards with 24 pt corners, pill controls (white fill = primary), grey
//           sentence-case labels, a floating pill navigation bar at the bottom.
// PAPER   - 19-86: pure white, black ink, one light weight for everything, monumental light
//           numerals, 1 px black rules instead of boxes, dot markers, grey inactive links.
//           Borrowed from Uniswap Cup: ONE colour used sparingly (live dot, units, artist).
// TERMINAL - Midjourney: violet-black void with a navy gradient, monospace everywhere at
//           regular weight, headings prefixed by a small accent glyph, translucent tinted
//           "specimen" pills, a generated ASCII sphere in the background, LED-block meters.
//
// The colour the user picks (gold, rose gold, sapphire...) becomes the one accent in every style.

enum StyleID: String, Codable, CaseIterable, Identifiable {
    case gilded, glass, paper, terminal
    var id: String { rawValue }
    var name: String {
        switch self {
        case .gilded: return "Gilded"
        case .glass: return "Glass"
        case .paper: return "Paper"
        case .terminal: return "Terminal"
        }
    }
    var blurb: String {
        switch self {
        case .gilded: return "Black with gold-leaf numbers"
        case .glass: return "Frosted panels over a soft glow"
        case .paper: return "Black ink on white, like a print"
        case .terminal: return "A monospace console"
        }
    }
}

enum AccentID: String, Codable, CaseIterable, Identifiable {
    case gold, champagne, rose, copper, platinum, sapphire, amethyst
    var id: String { rawValue }
    var name: String {
        switch self {
        case .gold: return "Gold"
        case .champagne: return "Champagne"
        case .rose: return "Rose gold"
        case .copper: return "Copper"
        case .platinum: return "Platinum"
        case .sapphire: return "Sapphire"
        case .amethyst: return "Amethyst"
        }
    }
    /// main (labels, lines), hi (bright numerals), deep (decorative gradients), onLight (on white)
    var hexes: (main: UInt32, hi: UInt32, deep: UInt32, onLight: UInt32) {
        switch self {
        case .gold: return (0xC8AD86, 0xECE4B4, 0xCC9166, 0x8E6F3E)
        case .champagne: return (0xE2CFA6, 0xF6EBD0, 0xC9A770, 0x8A7140)
        case .rose: return (0xD9A08B, 0xF2CDBE, 0xB8735E, 0xA35A45)
        case .copper: return (0xCC8152, 0xEDB990, 0xA35A33, 0xA14E22)
        case .platinum: return (0xC4CAD3, 0xEEF1F5, 0x8E97A5, 0x55606E)
        case .sapphire: return (0x7E9CE0, 0xC3D2F7, 0x4867AF, 0x2F55B8)
        case .amethyst: return (0xA98BE3, 0xD9CBF5, 0x6B62F2, 0x6A4CC4)
        }
    }
    var swatch: Color { Color(hex: hexes.main) }
}

struct Design {
    var style: StyleID
    var accentID: AccentID
    var dark = true
    var canvas = Color.black
    var ink = Color.white          // primary text
    var ink2 = Color.gray          // secondary text
    var ink3 = Color.gray          // tertiary text
    var label = Color.white        // section labels
    var accent = Color.white       // highlights, units, artist, active controls
    var numeral = Color.white      // big numbers (when not gold leaf)
    var deco = Color.white         // decorative gradients only
    var signal = Color.white       // live data: lines, meters, progress
    var onSignal = Color.black     // text on a signal-coloured fill
    var hairline = Color.gray      // borders and rules
    var track = Color.gray         // empty part of meters
    var raised = Color.gray        // placeholders, pressed fills
    var fill = Color.white         // primary buttons
    var onFill = Color.black       // text/icons on primary buttons
    var cardFill = Color.black
    var radius: CGFloat = 4
    var foil = false

    static func make(_ style: StyleID, _ a: AccentID) -> Design {
        let h = a.hexes
        let main = Color(hex: h.main), hi = Color(hex: h.hi), deep = Color(hex: h.deep), onLight = Color(hex: h.onLight)
        var d = Design(style: style, accentID: a)
        switch style {
        case .gilded:
            let ivory = Color(hex: 0xFFF7DD)
            d.canvas = .black; d.ink = ivory; d.ink2 = ivory.opacity(0.62); d.ink3 = ivory.opacity(0.40)
            d.label = main; d.accent = main; d.numeral = hi; d.deco = deep
            d.signal = main; d.onSignal = .black
            d.hairline = main.opacity(0.30); d.track = ivory.opacity(0.10); d.raised = Color(hex: 0x0E0C09)
            d.fill = main; d.onFill = .black; d.cardFill = .black; d.radius = 4
            d.foil = true
        case .glass:
            d.canvas = Color(hex: 0x0A0A0A); d.ink = Color(hex: 0xF2F2F2); d.ink2 = Color(hex: 0xB2B2B2); d.ink3 = Color(hex: 0x7A7A7A)
            d.label = Color(hex: 0xB2B2B2); d.accent = hi; d.numeral = .white; d.deco = deep
            d.signal = hi; d.onSignal = .black
            d.hairline = Color.white.opacity(0.10); d.track = Color.white.opacity(0.12); d.raised = Color.white.opacity(0.07)
            d.fill = .white; d.onFill = .black; d.cardFill = Color.black.opacity(0.22); d.radius = 24
        case .paper:
            d.dark = false
            d.canvas = .white; d.ink = .black; d.ink2 = Color(hex: 0x555555); d.ink3 = Color(hex: 0x8C8C8C)
            d.label = .black; d.accent = onLight; d.numeral = .black; d.deco = onLight
            d.signal = .black; d.onSignal = .white
            d.hairline = .black; d.track = Color.black.opacity(0.09); d.raised = Color(hex: 0xF2F2F2)
            d.fill = .black; d.onFill = .white; d.cardFill = .white; d.radius = 0
        case .terminal:
            let mist = Color(hex: 0xCAD5E2)
            d.canvas = Color(hex: 0x06051D); d.ink = mist; d.ink2 = mist.opacity(0.66); d.ink3 = mist.opacity(0.42)
            d.label = .white; d.accent = main; d.numeral = .white; d.deco = main
            d.signal = main; d.onSignal = Color(hex: 0x06051D)
            d.hairline = Color.white.opacity(0.10); d.track = Color.white.opacity(0.08); d.raised = Color(hex: 0x1D293D)
            d.fill = main.opacity(0.22); d.onFill = hi; d.cardFill = Color(hex: 0x0F1C36).opacity(0.62); d.radius = 8
        }
        return d
    }

    /// Big readout numerals.
    func display(_ size: CGFloat, weight: Font.Weight = .light) -> Font {
        switch style {
        case .gilded: return .system(size: size, weight: weight).width(.expanded)
        case .glass: return .system(size: size, weight: weight == .light ? .regular : weight)
        case .paper: return .system(size: size, weight: .light)
        case .terminal: return .system(size: size, weight: .regular, design: .monospaced)
        }
    }

    /// Everyday text.
    func text(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        switch style {
        case .terminal:
            return .system(size: size * 0.94, weight: weight == .bold || weight == .semibold ? .medium : .regular, design: .monospaced)
        case .paper:
            // 19-86: one light-ish weight for everything
            return .system(size: size, weight: weight == .light || weight == .ultraLight ? weight : .regular)
        default:
            return .system(size: size, weight: weight)
        }
    }
}

enum Theme {
    nonisolated(unsafe) static var d = Design.make(.gilded, .gold)

    static func apply(_ s: AppSettings) {
        d = Design.make(s.style, s.accent)
    }

    static var canvas: Color { d.canvas }
    static var ivory: Color { d.ink }
    static var gold: Color { d.accent }
    static var label: Color { d.label }
    static var aged: Color { d.numeral }
    static var ember: Color { d.deco }
    static var signal: Color { d.signal }
    static var onSignal: Color { d.onSignal }
    static var fill: Color { d.fill }
    static var onFill: Color { d.onFill }
    static var text2: Color { d.ink2 }
    static var text3: Color { d.ink3 }
    static var hairline: Color { d.hairline }
    static var track: Color { d.track }
    static var raised: Color { d.raised }
    static var radius: CGFloat { d.radius }
    static var style: StyleID { d.style }

    static let hot = Color(hex: 0xE58A4A)        // status: hot
    static let critical = Color(hex: 0xEF5A4C)   // status: critical / offline
    static let pad: CGFloat = 20
    static let gap: CGFloat = 8

    static func levelColor(_ level: Int) -> Color {
        switch level {
        case 3: return critical
        case 2: return hot
        case 1: return d.style == .paper ? d.accent : d.numeral
        default: return d.signal
        }
    }

    /// Decorative gradient (fills, glows).
    static var gleam: LinearGradient {
        LinearGradient(colors: [d.numeral, d.signal, d.deco], startPoint: .top, endPoint: .bottom)
    }
}

// MARK: - Backgrounds

struct StyleBackground: View {
    var design: Design = Theme.d

    var body: some View {
        switch design.style {
        case .glass:
            ZStack {
                design.canvas
                // Dimension's sky: cool blue-grey up top, warm muted beige low down, plus the accent.
                RadialGradient(colors: [Color(hex: 0x4867AF).opacity(0.42), .clear], center: UnitPoint(x: 0.5, y: -0.1),
                               startRadius: 10, endRadius: 760)
                RadialGradient(colors: [design.deco.opacity(0.40), .clear], center: UnitPoint(x: 0.05, y: 0.15),
                               startRadius: 10, endRadius: 560)
                RadialGradient(colors: [Color(hex: 0xC9B79C).opacity(0.26), .clear], center: UnitPoint(x: 0.85, y: 1.1),
                               startRadius: 10, endRadius: 700)
            }
            .ignoresSafeArea()
        case .terminal:
            ZStack {
                LinearGradient(colors: [Color(hex: 0x061434), Color(hex: 0x06051D)], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.7))
                AsciiSphere()
            }
            .ignoresSafeArea()
        default:
            design.canvas.ignoresSafeArea()
        }
    }
}

/// A sphere drawn from text characters, very faint, like generated output (Terminal style).
struct AsciiSphere: View {
    private static let ramp = Array(" .:-=+*#%@")

    var body: some View {
        Canvas { ctx, size in
            let cell = CGSize(width: 7.22, height: 15) // SF Mono 12 pt advance
            let cols = Int(size.width / cell.width), rows = Int(size.height / cell.height)
            let cx = Double(cols) * 0.78, cy = Double(rows) * 0.42
            let rx = Double(rows) * 0.42 * cell.height / cell.width, ry = Double(rows) * 0.42
            let l = (x: -0.55, y: -0.55, z: 0.63)
            for r in 0..<rows {
                var line = ""
                for c in 0..<cols {
                    let x = (Double(c) - cx) / rx, y = (Double(r) - cy) / ry
                    let q = x * x + y * y
                    if q > 1 { line.append(" "); continue }
                    let z = (1 - q).squareRoot()
                    let shade = max(0, x * l.x + y * l.y + z * l.z)
                    let i = min(Self.ramp.count - 1, Int(shade * Double(Self.ramp.count - 1) + 0.5))
                    line.append(Self.ramp[i])
                }
                ctx.draw(Text(line).font(.system(size: 12, design: .monospaced)).foregroundColor(Color(hex: 0xCAD5E2).opacity(0.075)),
                         at: CGPoint(x: 0, y: CGFloat(r) * cell.height), anchor: .topLeading)
            }
        }
        .allowsHitTesting(false)
    }
}
