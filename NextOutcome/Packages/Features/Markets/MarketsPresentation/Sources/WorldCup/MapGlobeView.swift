//
//  MapGlobeView.swift
//  NextOutcome
//
//  Created by Sok Pich on 04/07/2026.
//

import SwiftUI
import DesignSystem

/// The hub's Map tab: a rotating, draggable globe with each nation's win % pill anchored to
/// its coordinates.
struct MapView: View {
    /// The country pills to place on the globe.
    let countries: [GlobeCountry]

    var body: some View {
        Group {
            #if canImport(UIKit)
            if countries.isEmpty {
                ContentUnavailableView("No odds yet", systemImage: "globe")
                    .frame(height: 360)
            } else {
                GlobeSceneView(countries: countries)
                    .frame(height: 420)
                    .frame(maxWidth: .infinity)
            }
            #else
            Color.clear.frame(height: 420)
            #endif
        }
    }
}

#if canImport(UIKit)
import SceneKit
import UIKit

/// SceneKit globe: a dotted sphere that auto-rotates and can be dragged, with billboarded
/// pill nodes (flag colour dot + "ABBR %") anchored on the surface. Pills on the far side are
/// occluded by the sphere via the depth buffer.
struct GlobeSceneView: UIViewRepresentable {
    /// The country pills to render on the sphere.
    let countries: [GlobeCountry]

    /// The sphere radius in scene units.
    private static let radius: CGFloat = 1.5

    /// Creates the coordinator that owns pan-gesture state.
    func makeCoordinator() -> Coordinator { Coordinator() }

    /// Builds the `SCNView`, its scene, camera, auto-rotation, and pan gesture.
    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X
        view.scene = makeScene()
        view.pointOfView = view.scene?.rootNode.childNode(withName: "camera", recursively: false)
        view.rendersContinuously = true

        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        view.addGestureRecognizer(pan)
        context.coordinator.globe = view.scene?.rootNode.childNode(withName: "globe", recursively: false)
        return view
    }

    /// Rebuilds the pill nodes only when the set of countries changes (tracked by signature).
    func updateUIView(_ view: SCNView, context: Context) {
        guard let globe = view.scene?.rootNode.childNode(withName: "globe", recursively: false) else { return }
        context.coordinator.globe = globe
        // Rebuild pills when the country set changes.
        let signature = countries.map(\.id).joined(separator: ",")
        guard context.coordinator.pillSignature != signature else { return }
        context.coordinator.pillSignature = signature
        globe.childNode(withName: "pills", recursively: false)?.removeFromParentNode()
        globe.addChildNode(makePills())
    }

    // MARK: scene

    /// Builds the scene: camera (with bloom) and the tilted, auto-rotating globe node.
    private func makeScene() -> SCNScene {
        let scene = SCNScene()

        let camera = SCNCamera()
        camera.fieldOfView = 40
        camera.wantsHDR = true
        camera.bloomIntensity = 1.1
        camera.bloomThreshold = 0.3
        camera.bloomBlurRadius = 8
        let cameraNode = SCNNode()
        cameraNode.name = "camera"
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 5)
        scene.rootNode.addChildNode(cameraNode)

        let globe = SCNNode(geometry: makeGlobeGeometry())
        globe.name = "globe"
        globe.eulerAngles = SCNVector3(0.35, 0, 0) // tilt so the northern hemisphere shows
        globe.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 40)))
        scene.rootNode.addChildNode(globe)

        return scene
    }

    /// Builds the sphere geometry with the dotted-glow emission texture.
    private func makeGlobeGeometry() -> SCNSphere {
        let sphere = SCNSphere(radius: Self.radius)
        sphere.segmentCount = 96
        let material = SCNMaterial()
        material.diffuse.contents = UIColor(red: 0.04, green: 0.06, blue: 0.13, alpha: 1)
        material.emission.contents = Self.dotTexture()
        material.emission.intensity = 1
        material.lightingModel = .constant
        sphere.firstMaterial = material
        return sphere
    }

    /// A dark texture speckled with glowing blue dots — the "dotted globe" look.
    /// - Parameter size: The texture width in pixels (height is half).
    /// - Returns: The dotted globe emission texture.
    private static func dotTexture(size: Int = 1024) -> UIImage {
        let s = CGSize(width: size, height: size / 2)
        return UIGraphicsImageRenderer(size: s).image { ctx in
            UIColor(red: 0.03, green: 0.05, blue: 0.11, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: s))
            let step: CGFloat = 12
            let dot: CGFloat = 2.4
            UIColor(red: 0.3, green: 0.55, blue: 1, alpha: 0.55).setFill()
            var y: CGFloat = step
            while y < s.height {
                var x: CGFloat = step
                while x < s.width {
                    ctx.cgContext.fillEllipse(in: CGRect(x: x, y: y, width: dot, height: dot))
                    x += step
                }
                y += step
            }
        }
    }

    // MARK: pills

    /// Builds a container node holding one billboarded pill per country, placed on the surface.
    private func makePills() -> SCNNode {
        let container = SCNNode()
        container.name = "pills"
        for country in countries {
            let node = SCNNode(geometry: pillPlane(for: country))
            node.constraints = [SCNBillboardConstraint()]
            node.position = surfacePosition(lat: country.lat, lon: country.lon, scale: 1.04)
            container.addChildNode(node)
        }
        return container
    }

    /// Converts latitude/longitude to a 3D point on (or just above) the sphere surface.
    /// - Parameters:
    ///   - lat: Latitude in degrees.
    ///   - lon: Longitude in degrees.
    ///   - scale: A radius multiplier (>1 lifts the pill slightly off the surface).
    /// - Returns: The scene-space position.
    private func surfacePosition(lat: Double, lon: Double, scale: Float) -> SCNVector3 {
        let r = Float(Self.radius) * scale
        let phi = Float(lat * .pi / 180)
        let lambda = Float(lon * .pi / 180)
        return SCNVector3(
            r * cos(phi) * sin(lambda),
            r * sin(phi),
            r * cos(phi) * cos(lambda)
        )
    }

    /// Builds a textured plane displaying a country's pill image, sized to the image aspect.
    private func pillPlane(for country: GlobeCountry) -> SCNPlane {
        let image = Self.pillImage(for: country)
        let aspect = image.size.width / max(image.size.height, 1)
        let height: CGFloat = 0.13
        let plane = SCNPlane(width: height * aspect, height: height)
        let material = SCNMaterial()
        material.diffuse.contents = image
        material.isDoubleSided = true
        material.lightingModel = .constant
        plane.firstMaterial = material
        return plane
    }

    /// Renders a country's pill (coloured dot + "ABBR %") into an image for the plane texture.
    private static func pillImage(for country: GlobeCountry) -> UIImage {
        let text = "\(country.abbreviation)  \(country.caption)"
        let font = UIFont.systemFont(ofSize: 34, weight: .bold)
        let textSize = (text as NSString).size(withAttributes: [.font: font])
        let dotD: CGFloat = 26
        let padX: CGFloat = 26, padY: CGFloat = 16, gap: CGFloat = 14
        let size = CGSize(width: padX * 2 + dotD + gap + textSize.width, height: textSize.height + padY * 2)

        return UIGraphicsImageRenderer(size: size).image { ctx in
            let rect = CGRect(origin: .zero, size: size)
            let bg = UIBezierPath(roundedRect: rect, cornerRadius: size.height / 2)
            UIColor(red: 0.09, green: 0.11, blue: 0.16, alpha: 0.96).setFill()
            bg.fill()
            UIColor.white.withAlphaComponent(0.12).setStroke()
            bg.lineWidth = 2; bg.stroke()

            let color = UIColor(hexString: country.colorHex) ?? UIColor(red: 0.23, green: 0.54, blue: 0.97, alpha: 1)
            color.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: padX, y: (size.height - dotD) / 2, width: dotD, height: dotD))

            (text as NSString).draw(
                at: CGPoint(x: padX + dotD + gap, y: (size.height - textSize.height) / 2),
                withAttributes: [.font: font, .foregroundColor: UIColor.white]
            )
        }
    }

    /// Owns the pan-gesture handling and remembers the current pill set so `updateUIView`
    /// can skip needless rebuilds.
    final class Coordinator: NSObject {
        /// The globe node being rotated (weak to avoid a retain cycle).
        weak var globe: SCNNode?
        /// A signature of the current country set, to detect changes.
        var pillSignature = ""
        /// The globe's orientation when a drag began.
        private var startAngles: SCNVector3?

        /// Handles the drag gesture: pauses auto-rotation, rotates with the finger, then
        /// resumes the slow spin when the drag ends.
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let globe else { return }
            switch gesture.state {
            case .began:
                globe.removeAllActions()
                startAngles = globe.eulerAngles
            case .changed:
                guard let start = startAngles, let view = gesture.view else { return }
                let t = gesture.translation(in: view)
                let k: Float = 0.01
                globe.eulerAngles = SCNVector3(
                    start.x + Float(t.y) * k,
                    start.y + Float(t.x) * k,
                    start.z
                )
            case .ended, .cancelled:
                // Resume the slow spin from the current orientation.
                globe.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 40)))
            default:
                break
            }
        }
    }
}

private extension UIColor {
    /// Creates a colour from a 6-digit hex string (with optional `#`), or `nil` if invalid.
    convenience init?(hexString: String?) {
        guard let raw = hexString?.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: ""),
              raw.count == 6, let v = UInt32(raw, radix: 16) else { return nil }
        self.init(
            red: CGFloat((v >> 16) & 0xFF) / 255,
            green: CGFloat((v >> 8) & 0xFF) / 255,
            blue: CGFloat(v & 0xFF) / 255,
            alpha: 1
        )
    }
}
#endif
