import SwiftUI
import SceneKit
import UIKit
import CoreText

// Real 3D, drawn with SceneKit: the solid hero numerals and each look's signature object.
// Everything here is small, lit by one generated "studio" and paced at 30 frames a second
// so the iPad (6th generation) stays cool.

// MARK: - Light and materials

enum EnvMap {
    private static var cache: [String: UIImage] = [:]

    /// A tiny photo studio for metal to reflect: a sky that fades to a dark floor, a bright
    /// horizon line and a few soft boxes. Drawn once per colour and kept.
    static func studio(_ key: String, sky: UIColor, box: UIColor) -> UIImage {
        if let img = cache[key] { return img }
        let size = CGSize(width: 512, height: 256)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let img = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cg = ctx.cgContext
            let space = CGColorSpaceCreateDeviceRGB()
            let colors = [sky.cgColor, UIColor(white: 0.20, alpha: 1).cgColor, UIColor(white: 0.02, alpha: 1).cgColor] as CFArray
            if let grad = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.5, 1]) {
                cg.drawLinearGradient(grad, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            }
            let spots: [(CGPoint, CGFloat, UIColor)] = [
                (CGPoint(x: 120, y: 58), 96, box),
                (CGPoint(x: 384, y: 76), 64, box.withAlphaComponent(0.85)),
                (CGPoint(x: 262, y: 26), 54, UIColor.white),
                (CGPoint(x: 470, y: 150), 40, box.withAlphaComponent(0.5)),
            ]
            for (c, r, color) in spots {
                let cols = [color.cgColor, color.withAlphaComponent(0).cgColor] as CFArray
                if let g = CGGradient(colorsSpace: space, colors: cols, locations: [0, 1]) {
                    cg.drawRadialGradient(g, startCenter: c, startRadius: 0, endCenter: c, endRadius: r, options: [])
                }
            }
            UIColor(white: 1, alpha: 0.6).setFill()
            cg.fill(CGRect(x: 0, y: 121, width: size.width, height: 3))
        }
        cache[key] = img
        return img
    }
}

enum Mat {
    static func metal(_ color: UIColor, roughness: Double) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = color
        m.metalness.contents = 1.0
        m.roughness.contents = roughness
        return m
    }

    static func matte(_ color: UIColor, roughness: Double = 0.7) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = color
        m.metalness.contents = 0.0
        m.roughness.contents = roughness
        return m
    }

    /// Something that gives off its own light and ignores the lamps.
    static func light(_ color: UIColor, intensity: CGFloat = 1) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = UIColor.black
        m.emission.contents = color
        m.emission.intensity = intensity
        return m
    }
}

private func addLamps(to scene: SCNScene, key: CGFloat = 900, ambient: CGFloat = 260) {
    let keyLight = SCNLight()
    keyLight.type = .directional
    keyLight.intensity = key
    keyLight.color = UIColor.white
    let keyNode = SCNNode()
    keyNode.light = keyLight
    keyNode.eulerAngles = SCNVector3(-0.7, -0.5, 0)
    scene.rootNode.addChildNode(keyNode)

    let amb = SCNLight()
    amb.type = .ambient
    amb.intensity = ambient
    amb.color = UIColor.white
    let ambNode = SCNNode()
    ambNode.light = amb
    scene.rootNode.addChildNode(ambNode)
}

// MARK: - Solid numerals

/// A hero numeral as a real extruded object (Gilded: gold, Molten: chrome, Paper: ink).
/// An invisible copy of the text does the layout, so it sits exactly where flat text would.
struct SolidNumber: View {
    var value: String
    var size: CGFloat
    var look: Solid

    var body: some View {
        let d = Theme.d
        let font = d.uiDisplay(size)
        let pad = size * 0.24
        Text(value)
            .font(Font(font as CTFont))
            .foregroundStyle(Color.clear)
            .overlay {
                GeometryReader { g in
                    let w = g.size.width + pad * 2
                    let h = g.size.height + pad * 2
                    ZStack {
                        if look == .ink {
                            // the shadow the ink throws on the paper
                            Text(value)
                                .font(Font(font as CTFont))
                                .foregroundStyle(Color.black.opacity(0.30))
                                .lineLimit(1)
                                .minimumScaleFactor(0.3)
                                .frame(width: g.size.width, height: g.size.height)
                                .blur(radius: size * 0.05)
                                .offset(x: size * 0.035, y: size * 0.075)
                        }
                        Numeral3D(text: value, font: font, look: look, lineHeight: g.size.height,
                                  viewSize: CGSize(width: w, height: h),
                                  main: UIColor(hex: d.mainHex), hi: UIColor(hex: d.hiHex), deep: UIColor(hex: d.deepHex))
                    }
                    .frame(width: w, height: h)
                    .offset(x: -pad, y: -pad)
                }
            }
            .accessibilityLabel(value)
    }
}

struct Numeral3D: UIViewRepresentable {
    var text: String
    var font: UIFont
    var look: Solid
    var lineHeight: CGFloat
    var viewSize: CGSize
    var main: UIColor
    var hi: UIColor
    var deep: UIColor

    func makeCoordinator() -> NumeralRig { NumeralRig() }

    func makeUIView(context: Context) -> SCNView {
        let v = SCNView(frame: CGRect(origin: .zero, size: viewSize))
        v.backgroundColor = UIColor.clear
        v.isOpaque = false
        v.antialiasingMode = .multisampling4X
        v.preferredFramesPerSecond = 30
        v.isUserInteractionEnabled = false
        v.scene = context.coordinator.scene
        v.pointOfView = context.coordinator.cameraNode
        v.delegate = context.coordinator
        v.isPlaying = true
        Motion.shared.retain()
        return v
    }

    func updateUIView(_ v: SCNView, context: Context) {
        context.coordinator.update(self)
    }

    static func dismantleUIView(_ v: SCNView, coordinator: NumeralRig) {
        v.isPlaying = false
        v.delegate = nil
        Motion.shared.release()
    }
}

final class NumeralRig: NSObject, SCNSceneRendererDelegate {
    let scene = SCNScene()
    let cameraNode = SCNNode()
    private let rig = SCNNode()
    private var textNode: SCNNode?
    private var current = ""
    private var lit = ""

    override init() {
        super.init()
        scene.background.contents = UIColor.clear
        let cam = SCNCamera()
        cam.zNear = 1
        cam.zFar = 8000
        cam.fieldOfView = 20
        cameraNode.camera = cam
        scene.rootNode.addChildNode(cameraNode)
        scene.rootNode.addChildNode(rig)
        addLamps(to: scene)
    }

    func update(_ n: Numeral3D) {
        // The camera sees exactly `viewSize` points at the depth of the text.
        let h = max(10, Double(n.viewSize.height))
        let fov = 20.0
        cameraNode.position = SCNVector3(0, 0, Float(h / 2 / tan(fov / 2 * Double.pi / 180)))

        let lookKey: String
        switch n.look {
        case .gold: lookKey = "gold"
        case .chrome: lookKey = "chrome"
        case .ink: lookKey = "ink"
        }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        n.main.getRed(&r, green: &g, blue: &b, alpha: &a)
        let tone = lookKey + String(Int(r * 255)) + "." + String(Int(g * 255)) + "." + String(Int(b * 255))
        if tone != lit {
            lit = tone
            switch n.look {
            case .gold:
                scene.lightingEnvironment.contents = EnvMap.studio("warm" + tone, sky: UIColor(red: 1, green: 0.93, blue: 0.80, alpha: 1), box: n.hi)
                scene.lightingEnvironment.intensity = 1.9
            case .chrome:
                scene.lightingEnvironment.contents = EnvMap.studio("cool", sky: UIColor(white: 0.95, alpha: 1), box: UIColor.white)
                scene.lightingEnvironment.intensity = 1.7
            case .ink:
                scene.lightingEnvironment.contents = EnvMap.studio("paper", sky: UIColor(white: 1, alpha: 1), box: UIColor.white)
                scene.lightingEnvironment.intensity = 0.8
            }
        }

        let key = n.text + "|" + n.font.fontName + "|" + String(Double(n.font.pointSize)) + "|" + tone
        if key != current {
            current = key
            textNode?.removeFromParentNode()
            let size = n.font.pointSize
            let depth = size * (n.look == .ink ? 0.13 : 0.17)
            let geo = SCNText(string: n.text, extrusionDepth: depth)
            geo.font = n.font
            geo.flatness = 0.22
            geo.chamferRadius = min(depth * 0.2, size * 0.012)
            let front: SCNMaterial, side: SCNMaterial, bevel: SCNMaterial
            switch n.look {
            case .gold:
                front = Mat.metal(n.main, roughness: 0.21)
                side = Mat.metal(n.deep, roughness: 0.40)
                bevel = Mat.metal(n.hi, roughness: 0.12)
            case .chrome:
                front = Mat.metal(UIColor(white: 0.93, alpha: 1), roughness: 0.14)
                side = Mat.metal(UIColor(white: 0.50, alpha: 1), roughness: 0.30)
                bevel = Mat.metal(UIColor.white, roughness: 0.08)
            case .ink:
                front = Mat.matte(UIColor(white: 0.015, alpha: 1), roughness: 0.92)
                side = Mat.matte(UIColor(white: 0.26, alpha: 1), roughness: 0.9)
                bevel = Mat.matte(UIColor(white: 0.10, alpha: 1), roughness: 0.8)
            }
            // SCNText: front, back, extruded sides, front chamfer, back chamfer
            geo.materials = [front, side, side, bevel, side]
            let node = SCNNode(geometry: geo)
            let (mn, mx) = node.boundingBox
            node.pivot = SCNMatrix4MakeTranslation((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, (mn.z + mx.z) / 2)
            rig.addChildNode(node)
            textNode = node
        }

        // Put the middle of the digits where the middle of flat digits would be.
        let f = n.font
        let k = min(1.0, Double(n.lineHeight) / max(1.0, Double(f.lineHeight)))
        let y = Double(n.lineHeight) / 2 - (Double(f.ascender) - Double(f.capHeight) / 2) * k
        rig.position = SCNVector3(0, Float(y), 0)
        rig.scale = SCNVector3(Float(k), Float(k), Float(k))
    }

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        // A slow sway so the depth reads even on a stand, plus the tilt of the iPad itself.
        let tilt = Motion.shared.tilt
        let ry = -0.17 + sin(time * 0.42) * 0.15 + Double(tilt.x) * 0.28
        let rx = -0.13 + sin(time * 0.29 + 1.3) * 0.045 + Double(tilt.y) * 0.16
        rig.eulerAngles = SCNVector3(Float(rx), Float(ry), 0)
    }
}

// MARK: - Signature objects

enum ObjectKind: String { case gold, ink, plasma, trefoil, wire }

/// One slowly turning object that reacts to how hard the PC is working.
/// gold / ink: an armillary of machined bands. plasma: a cage of light around a black core.
/// trefoil: three interlocked molten rings (processor, graphics, memory). wire: a data core.
struct CoreObject: UIViewRepresentable {
    var kind: ObjectKind
    var main: UIColor
    var hi: UIColor
    var deep: UIColor
    var second: UIColor
    var energy: Double          // 0...1
    var values: [Double]        // processor, graphics, memory, each 0...1
    var live: Bool

    func makeCoordinator() -> ObjectRig { ObjectRig() }

    func makeUIView(context: Context) -> SCNView {
        let v = SCNView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        // The plasma core blooms, which needs a solid backdrop: it only ever sits on pure black.
        let solid = kind == .plasma
        v.backgroundColor = solid ? UIColor.black : UIColor.clear
        v.isOpaque = solid
        v.antialiasingMode = solid ? .multisampling2X : .multisampling4X
        v.preferredFramesPerSecond = 30
        v.isUserInteractionEnabled = false
        context.coordinator.build(self)
        v.scene = context.coordinator.scene
        v.pointOfView = context.coordinator.cameraNode
        v.delegate = context.coordinator
        v.isPlaying = live
        return v
    }

    func updateUIView(_ v: SCNView, context: Context) {
        context.coordinator.energy = max(0, min(1, energy))
        context.coordinator.values = values
        if v.isPlaying != live { v.isPlaying = live }
    }

    static func dismantleUIView(_ v: SCNView, coordinator: ObjectRig) {
        v.isPlaying = false
        v.delegate = nil
    }
}

final class ObjectRig: NSObject, SCNSceneRendererDelegate {
    let scene = SCNScene()
    let cameraNode = SCNNode()
    var energy = 0.2
    var values: [Double] = [0.2, 0.2, 0.2]

    private let spin = SCNNode()
    private var kind = ObjectKind.gold
    private var rings: [(node: SCNNode, speed: Double, dir: Double)] = []
    private var glowing: [SCNMaterial] = []
    private var last: TimeInterval = 0
    private var phase = 0.0
    private var smooth = 0.2

    func build(_ o: CoreObject) {
        kind = o.kind
        energy = max(0, min(1, o.energy))
        smooth = energy
        values = o.values

        let cam = SCNCamera()
        cam.zNear = 0.1
        cam.zFar = 50
        cam.fieldOfView = 30
        cameraNode.camera = cam
        cameraNode.position = SCNVector3(0, 0, 4.5)
        scene.rootNode.addChildNode(cameraNode)
        scene.rootNode.addChildNode(spin)

        switch o.kind {
        case .gold:
            scene.background.contents = UIColor.clear
            scene.lightingEnvironment.contents = EnvMap.studio("warm-object", sky: UIColor(red: 1, green: 0.93, blue: 0.80, alpha: 1), box: o.hi)
            scene.lightingEnvironment.intensity = 1.9
            addLamps(to: scene)
            armillary(band: Mat.metal(o.main, roughness: 0.26), core: Mat.metal(o.hi, roughness: 0.14))
        case .ink:
            scene.background.contents = UIColor.clear
            scene.lightingEnvironment.contents = EnvMap.studio("paper", sky: UIColor(white: 1, alpha: 1), box: UIColor.white)
            scene.lightingEnvironment.intensity = 1.3
            addLamps(to: scene, key: 700, ambient: 300)
            armillary(band: Mat.matte(UIColor(white: 0.05, alpha: 1), roughness: 0.6), core: Mat.matte(o.main, roughness: 0.5))
        case .plasma:
            scene.background.contents = UIColor.black
            cam.wantsHDR = true
            cam.wantsExposureAdaptation = false
            cam.bloomIntensity = 0.85
            cam.bloomThreshold = 0.72
            cam.bloomBlurRadius = 10
            cameraNode.position = SCNVector3(0, 0, 5.3)
            plasma(o)
        case .trefoil:
            scene.background.contents = UIColor.clear
            scene.lightingEnvironment.contents = EnvMap.studio("ember", sky: UIColor(red: 1, green: 0.86, blue: 0.74, alpha: 1), box: UIColor(red: 1, green: 0.78, blue: 0.62, alpha: 1))
            scene.lightingEnvironment.intensity = 1.5
            addLamps(to: scene, key: 1000, ambient: 180)
            trefoil(o)
        case .wire:
            scene.background.contents = UIColor.clear
            cameraNode.position = SCNVector3(0, 0, 4.9)
            wire(o)
        }
    }

    /// Nested machined bands around a polished sphere.
    private func armillary(band: SCNMaterial, core: SCNMaterial) {
        let radii: [CGFloat] = [1.0, 0.81, 0.62, 0.43]
        for (i, r) in radii.enumerated() {
            let tube = SCNTube(innerRadius: r - 0.034, outerRadius: r, height: 0.09)
            tube.radialSegmentCount = 96
            tube.materials = [band]
            let holder = SCNNode()
            holder.eulerAngles = SCNVector3(Float(i) * 0.9 + 0.35, Float(i) * 0.6, Float(i) * 1.3)
            let ring = SCNNode(geometry: tube)
            holder.addChildNode(ring)
            spin.addChildNode(holder)
            rings.append((ring, 0.45 + Double(i) * 0.22, i % 2 == 0 ? 1 : -1))
        }
        let ball = SCNSphere(radius: 0.2)
        ball.segmentCount = 48
        ball.materials = [core]
        spin.addChildNode(SCNNode(geometry: ball))
    }

    /// JetBrains' luminous sculpture: overlapping translucent lobes with hot rims around a black centre.
    private func plasma(_ o: CoreObject) {
        for i in 0..<9 {
            let holder = SCNNode()
            holder.eulerAngles = SCNVector3(Float(i) * 0.7, Float(i) * 1.15, Float(i) * 0.43)

            let torus = SCNTorus(ringRadius: 1.0 - CGFloat(i % 3) * 0.025, pipeRadius: 0.011)
            torus.ringSegmentCount = 120
            torus.pipeSegmentCount = 8
            let rim = Mat.light(i % 3 == 0 ? o.hi : o.deep, intensity: 1.1)
            torus.materials = [rim]
            glowing.append(rim)
            let ring = SCNNode(geometry: torus)

            let disc = SCNCylinder(radius: 0.98, height: 0.002)
            disc.radialSegmentCount = 96
            let lobe = Mat.light(i % 2 == 0 ? o.main : o.deep, intensity: 0.8)
            lobe.blendMode = .add
            lobe.transparency = 0.045
            lobe.isDoubleSided = true
            lobe.writesToDepthBuffer = false
            disc.materials = [lobe]
            let discNode = SCNNode(geometry: disc)
            discNode.renderingOrder = 10
            ring.addChildNode(discNode)

            holder.addChildNode(ring)
            spin.addChildNode(holder)
            rings.append((ring, 0.16 + Double(i) * 0.045, i % 2 == 0 ? 1 : -1))
        }
        let ball = SCNSphere(radius: 0.58)
        ball.segmentCount = 64
        ball.materials = [Mat.light(UIColor.black, intensity: 0)]
        spin.addChildNode(SCNNode(geometry: ball))
    }

    /// three.tools' molten object, rebuilt as three interlocked rings: processor, graphics, memory.
    private func trefoil(_ o: CoreObject) {
        // Rotations that lay each ring in its own plane (Borromean rings).
        let turns: [SCNVector3] = [
            SCNVector3(Float.pi / 2, 0, 0),
            SCNVector3(0, 0, Float.pi / 2),
            SCNVector3(0, -Float.pi / 2, 0),
        ]
        for turn in turns {
            let torus = SCNTorus(ringRadius: 0.80, pipeRadius: 0.15)
            torus.ringSegmentCount = 96
            torus.pipeSegmentCount = 36
            let m = SCNMaterial()
            m.lightingModel = .physicallyBased
            m.diffuse.contents = o.main
            m.metalness.contents = 0.0
            m.roughness.contents = 0.30
            m.clearCoat.contents = 1.0
            m.clearCoatRoughness.contents = 0.12
            m.emission.contents = o.deep
            m.emission.intensity = 0.4
            torus.materials = [m]
            glowing.append(m)
            let ring = SCNNode(geometry: torus)
            ring.scale = SCNVector3(1, 1, 0.56)
            let holder = SCNNode()
            holder.eulerAngles = turn
            holder.addChildNode(ring)
            spin.addChildNode(holder)
        }
    }

    /// A wireframe data core.
    private func wire(_ o: CoreObject) {
        func lines(_ color: UIColor, _ k: CGFloat) -> SCNMaterial {
            let m = Mat.light(color, intensity: k)
            m.fillMode = .lines
            m.isDoubleSided = true
            return m
        }
        let outer = SCNSphere(radius: 1.0)
        outer.isGeodesic = true
        outer.segmentCount = 9
        outer.materials = [lines(o.second, 1.0)]
        let outerNode = SCNNode(geometry: outer)
        spin.addChildNode(outerNode)
        rings.append((outerNode, 0.22, 1))

        let grid = SCNSphere(radius: 0.72)
        grid.segmentCount = 14
        grid.materials = [lines(o.second.withAlphaComponent(0.55), 0.6)]
        let gridNode = SCNNode(geometry: grid)
        gridNode.eulerAngles = SCNVector3(0.5, 0, 0.3)
        spin.addChildNode(gridNode)
        rings.append((gridNode, 0.5, -1))

        let inner = SCNSphere(radius: 0.44)
        inner.isGeodesic = true
        inner.segmentCount = 3
        inner.materials = [lines(o.main, 1.0)]
        let innerNode = SCNNode(geometry: inner)
        spin.addChildNode(innerNode)
        rings.append((innerNode, 1.1, -1))

        let heart = SCNSphere(radius: 0.13)
        let heartMat = Mat.light(o.main, intensity: 1.0)
        heart.materials = [heartMat]
        glowing.append(heartMat)
        spin.addChildNode(SCNNode(geometry: heart))

        let halo = SCNTorus(ringRadius: 1.12, pipeRadius: 0.007)
        halo.ringSegmentCount = 120
        halo.materials = [Mat.light(o.main, intensity: 1.0)]
        let haloNode = SCNNode(geometry: halo)
        haloNode.eulerAngles = SCNVector3(1.15, 0, 0.25)
        scene.rootNode.addChildNode(haloNode)
    }

    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        let dt = last == 0 ? 0 : min(0.1, max(0, time - last))
        last = time
        smooth += (energy - smooth) * min(1, dt * 1.5)
        phase += dt * (0.30 + smooth * 1.7)

        switch kind {
        case .gold, .ink:
            spin.eulerAngles = SCNVector3(0.32, Float(phase * 0.30), 0.08)
            for r in rings {
                r.node.eulerAngles = SCNVector3(Float(phase * r.speed * r.dir), 0, 0)
            }
        case .plasma:
            spin.eulerAngles = SCNVector3(Float(sin(phase * 0.13) * 0.3), Float(phase * 0.22), 0)
            for r in rings {
                r.node.eulerAngles = SCNVector3(Float(phase * r.speed * r.dir), 0, Float(phase * r.speed * 0.4))
            }
            let k = CGFloat(0.95 + smooth * 0.75 + sin(time * 2.2) * 0.06)
            for m in glowing { m.emission.intensity = k }
        case .trefoil:
            spin.eulerAngles = SCNVector3(Float(0.42 + sin(phase * 0.21) * 0.18), Float(phase * 0.42), Float(0.2 + cos(phase * 0.17) * 0.12))
            for (i, m) in glowing.enumerated() {
                let v = i < values.count ? max(0, min(1, values[i])) : 0
                m.emission.intensity = CGFloat(0.12 + v * 1.5)
            }
        case .wire:
            spin.eulerAngles = SCNVector3(0.25, 0, 0.1)
            for r in rings {
                r.node.eulerAngles.y = Float(phase * r.speed * r.dir)
            }
            // an occasional twitch, like a bad signal
            let tick = Int(time * 11)
            let jolt: Float = tick % 47 == 0 ? 0.06 : 0
            spin.position = SCNVector3(jolt, 0, 0)
            for m in glowing { m.emission.intensity = CGFloat(0.8 + smooth * 0.9 + sin(time * 5) * 0.15) }
        }
    }
}
