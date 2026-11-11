import SwiftUI
import UIKit
import CoreText

// The eight looks the app can wear, each locked to its own references (refero-design research).
//
// GILDED   - Atoms (absolute black, ivory text, weathered-gold labels, flat 4 pt cards with gold
//            hairlines) + 601 Inc. (oversized wide numerals) + Slash (champagne light, metal
//            objects in the dark). The hero numerals are real 3D gold; the rest are gold leaf
//            with an extruded edge; hairlines catch the light from the top left.
// GLASS    - Dimension (#0A0A0A lit by a cool-to-warm glow, blurred 24 pt cards, pill controls,
//            floating bottom nav) + The Resonance (blue light as light, illuminated edges, ONE
//            panel with a luminous machined rim). A lens of living light is its object.
// PAPER    - 19-86: pure white, black ink, one light weight, monumental numerals, 1 px black
//            rules. + Uniswap Cup's single colour, + basement.studio's dimensional type: the
//            hero numerals are sculpted ink that casts a shadow on the page.
// TERMINAL - Midjourney (violet-black void, monospace, accent glyph headings, tinted pills)
//            + rig.ai's display patina (2 px scanlines) and a live ASCII torus, phosphor glow.
// REACTOR  - JetBrains: a luminous layered sculpture floating in pure black, 20 % violet panel
//            washes with 16 pt corners and no borders or shadows, semibold labels against thin
//            (weight 300) stat numerals, white capsule actions. + VITURE: the object is the
//            architecture; colour behaves like light.
// MOLTEN   - three.tools: true black, #1a1a1a cards with #343434 hairlines and 20 pt corners,
//            everything bold, white-to-silver metal lettering, a molten red-orange object with
//            no outer neon, a neutral horizon glow. Orange only on small actions and the object.
// APEX     - Lamborghini: black and #181818 charcoal, towering condensed capitals, broad
//            uppercase lead-ins, square ends, hexagon controls, yellow for the decisive action
//            and the selected tab rule only. The rev counter is its staged machine.
// CYBER    - (user brief: cyberpunk street-tech) ON.energy (absolute black + electric yellow,
//            mono labels led by a dot, cyan reserved for measured series) + Kippo (wide-tracked
//            mono capitals) + rig.ai (14 px cut-metal chamfers, scanlines, ticker, wireframe
//            terrain, corner brackets). Red is alerts only.
//
// Each look has its own signature colour; the user can swap it for any of the others.

enum StyleID: String, Codable, CaseIterable, Identifiable {
    case gilded, glass, paper, terminal, reactor, molten, apex, cyber
    var id: String { rawValue }
    var name: String {
        switch self {
        case .gilded: return "Gilded"
        case .glass: return "Glass"
        case .paper: return "Paper"
        case .terminal: return "Terminal"
        case .reactor: return "Reactor"
        case .molten: return "Molten"
        case .apex: return "Apex"
        case .cyber: return "Cyberpunk"
        }
    }
    var blurb: String {
        switch self {
        case .gilded: return "Black with solid gold numbers"
        case .glass: return "Frosted panels and a lens of light"
        case .paper: return "Sculpted ink on white"
        case .terminal: return "A glowing console"
        case .reactor: return "An energy core in deep space"
        case .molten: return "Chrome numbers, molten rings"
        case .apex: return "A supercar rev counter"
        case .cyber: return "Neon street-tech HUD"
        }
    }
    /// main (labels, lines), hi (bright numerals), deep (decorative gradients), onLight (on white)
    var signature: (main: UInt32, hi: UInt32, deep: UInt32, onLight: UInt32) {
        switch self {
        case .gilded: return (0xC8AD86, 0xECE4B4, 0xCC9166, 0x8E6F3E)
        case .glass: return (0x6FAEFF, 0xC4DCFF, 0x0068F0, 0x2F55B8)
        case .paper: return (0xE2491F, 0xFF9C7D, 0xB5330B, 0xD03A12)
        case .terminal: return (0x7FD4FF, 0xD2F1FF, 0x2E8FD6, 0x1F6FB0)
        case .reactor: return (0x9D7BFF, 0xE9DDFF, 0xAF1DF5, 0x5A32C8)
        case .molten: return (0xFF4300, 0xFFB199, 0xC81E00, 0xB5330B)
        case .apex: return (0xFFC000, 0xFFE28A, 0x917300, 0x917300)
        case .cyber: return (0xFCEE0A, 0xFFF98A, 0xC9B800, 0x8A7400)
        }
    }
}

enum AccentID: String, Codable, CaseIterable, Identifiable {
    case auto
    case gold, champagne, rose, copper, platinum, sapphire, amethyst
    case volt, cyan, magenta, ember, violet, crimson
    var id: String { rawValue }
    var name: String {
        switch self {
        case .auto: return "Signature"
        case .gold: return "Gold"
        case .champagne: return "Champagne"
        case .rose: return "Rose gold"
        case .copper: return "Copper"
        case .platinum: return "Platinum"
        case .sapphire: return "Sapphire"
        case .amethyst: return "Amethyst"
        case .volt: return "Volt"
        case .cyan: return "Ice"
        case .magenta: return "Magenta"
        case .ember: return "Ember"
        case .violet: return "Violet"
        case .crimson: return "Crimson"
        }
    }
    /// main (labels, lines), hi (bright numerals), deep (decorative gradients), onLight (on white)
    func hexes(_ style: StyleID) -> (main: UInt32, hi: UInt32, deep: UInt32, onLight: UInt32) {
        switch self {
        case .auto: return style.signature
        case .gold: return (0xC8AD86, 0xECE4B4, 0xCC9166, 0x8E6F3E)
        case .champagne: return (0xE2CFA6, 0xF6EBD0, 0xC9A770, 0x8A7140)
        case .rose: return (0xD9A08B, 0xF2CDBE, 0xB8735E, 0xA35A45)
        case .copper: return (0xCC8152, 0xEDB990, 0xA35A33, 0xA14E22)
        case .platinum: return (0xC4CAD3, 0xEEF1F5, 0x8E97A5, 0x55606E)
        case .sapphire: return (0x7E9CE0, 0xC3D2F7, 0x4867AF, 0x2F55B8)
        case .amethyst: return (0xA98BE3, 0xD9CBF5, 0x6B62F2, 0x6A4CC4)
        case .volt: return (0xFCEE0A, 0xFFF98A, 0xC9B800, 0x8A7400)
        case .cyan: return (0x3CE0FF, 0xB4F3FF, 0x0A8FD6, 0x0A6C9E)
        case .magenta: return (0xFF3D9A, 0xFFA8D2, 0xC2125F, 0xB0155A)
        case .ember: return (0xFF5B2E, 0xFFB08F, 0xC22A00, 0xB5330B)
        case .violet: return (0x9B6BFF, 0xD6C4FF, 0x5B2BD9, 0x5A32C8)
        case .crimson: return (0xFF3347, 0xFF9AA3, 0xB00020, 0xB0122A)
        }
    }
    func swatch(_ style: StyleID) -> Color { Color(hex: hexes(style).main) }
}

/// How the real 3D numerals are made, for the looks that have them.
enum Solid { case gold, chrome, ink }

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
    var numeral = Color.white      // big numbers (when not metal)
    var deco = Color.white         // decorative gradients only
    var signal = Color.white       // live data: lines, meters, progress
    var onSignal = Color.black     // text on a signal-coloured fill
    var hairline = Color.gray      // borders and rules
    var track = Color.gray         // empty part of meters
    var raised = Color.gray        // placeholders, pressed fills
    var fill = Color.white         // primary buttons
    var onFill = Color.black       // text/icons on primary buttons
    var cardFill = Color.black
    var second = Color.white       // a second light (Cyberpunk's cyan); elsewhere = accent
    var side = Color.black         // the dark edge of extruded numerals
    var glow = Color.clear         // the light numerals give off (clear = none)
    var radius: CGFloat = 4
    var cut: CGFloat = 0           // chamfered corners (Cyberpunk)
    var foil = false               // metal-leaf numerals
    var scan = false               // display scanlines
    var solid: Solid? = nil        // real 3D hero numerals
    // The raw tones, for the 3D scenes and shaders.
    var mainHex: UInt32 = 0xFFFFFF
    var hiHex: UInt32 = 0xFFFFFF
    var deepHex: UInt32 = 0x888888
    var secondHex: UInt32 = 0xFFFFFF

    static func shade(_ hex: UInt32, _ k: Double) -> Color {
        Color(.sRGB, red: Double(hex >> 16 & 255) / 255 * k, green: Double(hex >> 8 & 255) / 255 * k,
              blue: Double(hex & 255) / 255 * k, opacity: 1)
    }

    static func make(_ style: StyleID, _ a: AccentID) -> Design {
        let h = a.hexes(style)
        let main = Color(hex: h.main), hi = Color(hex: h.hi), deep = Color(hex: h.deep), onLight = Color(hex: h.onLight)
        var d = Design(style: style, accentID: a)
        d.mainHex = h.main; d.hiHex = h.hi; d.deepHex = h.deep; d.secondHex = h.main
        d.second = main
        d.side = shade(h.deep, 0.42)
        switch style {
        case .gilded:
            let ivory = Color(hex: 0xFFF7DD)
            d.canvas = .black; d.ink = ivory; d.ink2 = ivory.opacity(0.62); d.ink3 = ivory.opacity(0.40)
            d.label = main; d.accent = main; d.numeral = hi; d.deco = deep
            d.signal = main; d.onSignal = .black
            d.hairline = main.opacity(0.30); d.track = ivory.opacity(0.10); d.raised = Color(hex: 0x0E0C09)
            d.fill = main; d.onFill = .black; d.cardFill = .black; d.radius = 4
            d.foil = true; d.solid = .gold
        case .glass:
            d.canvas = Color(hex: 0x0A0A0A); d.ink = Color(hex: 0xF2F2F2); d.ink2 = Color(hex: 0xB2B2B2); d.ink3 = Color(hex: 0x7A7A7A)
            d.label = Color(hex: 0xB2B2B2); d.accent = hi; d.numeral = .white; d.deco = deep
            d.signal = hi; d.onSignal = .black
            d.hairline = Color.white.opacity(0.10); d.track = Color.white.opacity(0.12); d.raised = Color.white.opacity(0.07)
            d.fill = .white; d.onFill = .black; d.cardFill = Color.black.opacity(0.22); d.radius = 24
            d.glow = main.opacity(0.55)
        case .paper:
            d.dark = false
            d.canvas = .white; d.ink = .black; d.ink2 = Color(hex: 0x555555); d.ink3 = Color(hex: 0x8C8C8C)
            d.label = .black; d.accent = onLight; d.numeral = .black; d.deco = onLight
            d.signal = .black; d.onSignal = .white
            d.hairline = .black; d.track = Color.black.opacity(0.09); d.raised = Color(hex: 0xF2F2F2)
            d.fill = .black; d.onFill = .white; d.cardFill = .white; d.radius = 0
            d.side = Color(hex: 0x4A4A4A)
            d.solid = .ink
        case .terminal:
            let mist = Color(hex: 0xCAD5E2)
            d.canvas = Color(hex: 0x06051D); d.ink = mist; d.ink2 = mist.opacity(0.66); d.ink3 = mist.opacity(0.42)
            d.label = .white; d.accent = main; d.numeral = .white; d.deco = main
            d.signal = main; d.onSignal = Color(hex: 0x06051D)
            d.hairline = Color.white.opacity(0.10); d.track = Color.white.opacity(0.08); d.raised = Color(hex: 0x1D293D)
            d.fill = main.opacity(0.22); d.onFill = hi; d.cardFill = Color(hex: 0x0F1C36).opacity(0.62); d.radius = 8
            d.glow = main.opacity(0.75); d.scan = true
        case .reactor:
            d.canvas = .black; d.ink = .white; d.ink2 = Color.white.opacity(0.70); d.ink3 = Color.white.opacity(0.45)
            d.label = .white; d.accent = hi; d.numeral = .white; d.deco = deep
            d.signal = main; d.onSignal = .black
            d.hairline = Color.white.opacity(0.20); d.track = Color.white.opacity(0.10); d.raised = Color(hex: 0x19191C)
            d.fill = .white; d.onFill = Color(hex: 0x19191C); d.cardFill = main.opacity(0.17); d.radius = 16
            d.glow = deep.opacity(0.70)
        case .molten:
            d.canvas = .black; d.ink = .white; d.ink2 = Color(hex: 0xCACACA); d.ink3 = Color(hex: 0x8D8D8D)
            d.label = .white; d.accent = main; d.numeral = .white; d.deco = main
            d.signal = Color(hex: 0xE9E6E6); d.onSignal = .black
            d.hairline = Color(hex: 0x343434); d.track = Color.white.opacity(0.10); d.raised = Color(hex: 0x181818)
            d.fill = main; d.onFill = .white; d.cardFill = Color(hex: 0x1A1A1A); d.radius = 20
            d.side = Color(hex: 0x2C2C2C)
            d.foil = true; d.solid = .chrome
        case .apex:
            let soft = Color(hex: 0xF5F5F5)
            d.canvas = .black; d.ink = soft; d.ink2 = Color(hex: 0xC4C4C4); d.ink3 = Color(hex: 0x969696)
            d.label = Color(hex: 0xC4C4C4); d.accent = main; d.numeral = soft; d.deco = Color(hex: 0x7D7D7D)
            d.signal = soft; d.onSignal = .black
            d.hairline = Color(hex: 0x7D7D7D).opacity(0.45); d.track = Color.white.opacity(0.12); d.raised = Color(hex: 0x181818)
            d.fill = main; d.onFill = .black; d.cardFill = Color(hex: 0x181818); d.radius = 0
        case .cyber:
            // Cyan is the second light; if the user picks a blue-ish colour, yellow takes that job.
            let cool: Set<AccentID> = [.cyan, .sapphire, .platinum]
            let secondHex: UInt32 = cool.contains(a) ? 0xFCEE0A : 0x00F0FF
            let second = Color(hex: secondHex)
            let pale = Color(hex: 0xD7F9FF)
            d.canvas = Color(hex: 0x050507); d.ink = pale; d.ink2 = pale.opacity(0.66); d.ink3 = pale.opacity(0.40)
            d.label = main; d.accent = second; d.numeral = main; d.deco = second
            d.signal = second; d.onSignal = .black
            d.hairline = main.opacity(0.30); d.track = second.opacity(0.13); d.raised = Color(hex: 0x0D0D12)
            d.fill = main; d.onFill = .black; d.cardFill = Color(hex: 0x0B0B10).opacity(0.88); d.radius = 0
            d.second = second; d.secondHex = secondHex
            d.cut = 12; d.scan = true
            d.glow = main.opacity(0.45)
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
        case .reactor: return .system(size: size, weight: weight == .light ? .thin : weight)
        case .molten: return .system(size: size, weight: .bold)
        case .apex: return .system(size: size, weight: weight == .light ? .bold : .semibold).width(.compressed)
        case .cyber: return .system(size: size, weight: weight == .light ? .heavy : .bold).width(.condensed)
        }
    }

    /// The same face as `display`, for the 3D numerals (always with fixed-width digits).
    func uiDisplay(_ size: CGFloat) -> UIFont {
        let base: UIFont
        switch style {
        case .gilded: base = .systemFont(ofSize: size, weight: .regular, width: .expanded)
        case .molten: base = .systemFont(ofSize: size, weight: .heavy)
        case .paper: base = .systemFont(ofSize: size, weight: .regular)
        default: base = .systemFont(ofSize: size, weight: .regular)
        }
        let features: [[UIFontDescriptor.FeatureKey: Int]] = [[.type: kNumberSpacingType, .selector: kMonospacedNumbersSelector]]
        let desc = base.fontDescriptor.addingAttributes([.featureSettings: features])
        return UIFont(descriptor: desc, size: size)
    }

    /// Everyday text.
    func text(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        switch style {
        case .terminal:
            return .system(size: size * 0.94, weight: weight == .bold || weight == .semibold ? .medium : .regular, design: .monospaced)
        case .cyber:
            return .system(size: size * 0.92, weight: weight == .bold || weight == .semibold || weight == .medium ? .semibold : .regular,
                           design: .monospaced)
        case .paper:
            // 19-86: one light-ish weight for everything
            return .system(size: size, weight: weight == .light || weight == .ultraLight ? weight : .regular)
        case .molten:
            // three.tools: bold everywhere; brightness and size make the hierarchy
            return .system(size: size, weight: weight == .light || weight == .ultraLight ? .semibold : .bold)
        default:
            return .system(size: size, weight: weight)
        }
    }
}

enum Theme {
    nonisolated(unsafe) static var d = Design.make(.gilded, .auto)

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
    static var second: Color { d.second }

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
    /// Small previews pass false so nothing animates inside them.
    var live = true

    var body: some View {
        switch design.style {
        case .gilded:
            ZStack {
                design.canvas
                // Slash: champagne light falling from above onto the black.
                RadialGradient(colors: [design.deco.opacity(0.20), .clear], center: UnitPoint(x: 0.24, y: -0.12),
                               startRadius: 10, endRadius: 560)
            }
            .ignoresSafeArea()
        case .glass:
            ZStack {
                design.canvas
                // Dimension's sky: cool light up top, warm muted beige low down, plus the accent.
                RadialGradient(colors: [Color(hex: 0x4867AF).opacity(0.42), .clear], center: UnitPoint(x: 0.5, y: -0.1),
                               startRadius: 10, endRadius: 760)
                RadialGradient(colors: [design.deco.opacity(0.46), .clear], center: UnitPoint(x: 0.05, y: 0.15),
                               startRadius: 10, endRadius: 560)
                RadialGradient(colors: [Color(hex: 0xC9B79C).opacity(0.26), .clear], center: UnitPoint(x: 0.85, y: 1.1),
                               startRadius: 10, endRadius: 700)
                if live { DriftingLight(color: design.accent) }
            }
            .ignoresSafeArea()
        case .terminal:
            ZStack {
                LinearGradient(colors: [Color(hex: 0x061434), Color(hex: 0x06051D)], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.7))
                RadialGradient(colors: [design.accent.opacity(0.10), .clear], center: UnitPoint(x: 0.8, y: 0.3),
                               startRadius: 10, endRadius: 520)
            }
            .ignoresSafeArea()
        case .reactor:
            design.canvas.ignoresSafeArea()
        case .molten:
            GeometryReader { g in
                ZStack {
                    design.canvas
                    // three.tools: a neutral pool of light rising from the bottom centre.
                    RadialGradient(colors: [Color.white.opacity(0.20), .clear], center: UnitPoint(x: 0.5, y: 1.0),
                                   startRadius: 0, endRadius: max(g.size.width, 200) * 0.55)
                        .scaleEffect(x: 1, y: 0.62, anchor: .bottom)
                }
            }
            .ignoresSafeArea()
        case .cyber:
            ZStack {
                design.canvas
                LinearGradient(colors: [design.second.opacity(0.07), .clear], startPoint: .bottom, endPoint: UnitPoint(x: 0.5, y: 0.45))
                WireTerrain(color: design.label, live: live)
            }
            .ignoresSafeArea()
        default:
            design.canvas.ignoresSafeArea()
        }
    }
}

/// Glass: one slow pool of accent light that drifts behind the frosted panels.
struct DriftingLight: View {
    var color: Color
    @State private var on = false

    var body: some View {
        GeometryReader { g in
            Circle()
                .fill(RadialGradient(colors: [color.opacity(0.30), .clear], center: .center, startRadius: 0, endRadius: 260))
                .frame(width: 520, height: 520)
                .position(x: on ? g.size.width * 0.78 : g.size.width * 0.30, y: on ? g.size.height * 0.30 : g.size.height * 0.72)
                .animation(.easeInOut(duration: 26).repeatForever(autoreverses: true), value: on)
        }
        .allowsHitTesting(false)
        .onAppear { on = true }
    }
}
