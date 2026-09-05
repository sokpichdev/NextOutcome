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
                    .frame(height: 360)
                    .frame(maxWidth: .infinity)
            }
            #else
            Color.clear.frame(height: 360)
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
        // Pin the field of view to the horizontal axis: the hub's globe is in a wide, short
        // container, and leaving this automatic lets SceneKit measure against the taller
        // dimension, which crops the sphere's left and right edges off screen.
        camera.projectionDirection = .horizontal
        camera.wantsHDR = true
        // A tight bloom: a wide one smears the land dots' glow across the whole sphere and
        // washes the ocean out to a flat mid-blue, which is what made the globe read as a
        // featureless ball.
        camera.bloomIntensity = 0.7
        camera.bloomThreshold = 0.5
        camera.bloomBlurRadius = 3
        let cameraNode = SCNNode()
        cameraNode.name = "camera"
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0, 6) // far enough that the whole sphere fits with margin
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
        // Near-black: the emission texture supplies the ocean colour, and a lighter diffuse
        // on top of it washes the continents out.
        material.diffuse.contents = UIColor(red: 0.01, green: 0.02, blue: 0.05, alpha: 1)
        material.emission.contents = Self.dotTexture()
        material.emission.intensity = 1
        material.lightingModel = .constant
        sphere.firstMaterial = material
        return sphere
    }

    /// The dotted-continents texture: a dark ocean with glowing blue dots laid out only where
    /// `WorldLandMask` says there is land, so the sphere reads as a real world map rather than
    /// a uniformly speckled ball.
    ///
    /// The dot grid is spaced evenly in texture space and each row's horizontal step is
    /// widened by `1 / cos(latitude)` so that dots stay roughly evenly spaced *on the sphere*
    /// instead of bunching up towards the poles, where the equirectangular projection squeezes
    /// longitude together.
    /// - Parameter size: The texture width in pixels (height is half, as equirectangular
    ///   textures are 2:1).
    /// - Returns: The dotted globe emission texture.
    static func dotTexture(size: Int = 2048) -> UIImage {
        let s = CGSize(width: size, height: size / 2)
        let step = CGFloat(size) / 128 // ~128 dots across the equator
        let dot = step * 0.42
        return UIGraphicsImageRenderer(size: s).image { ctx in
            // Very nearly black: the camera renders HDR and converts to sRGB on the way out,
            // which lifts dark values noticeably, so an ocean that looks right in the texture
            // reads as pale slate on screen.
            UIColor(red: 0.004, green: 0.01, blue: 0.03, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: s))
            UIColor(red: 0.34, green: 0.62, blue: 1, alpha: 0.95).setFill()

            var y = step / 2
            while y < s.height {
                let latitude = 90 - Double(y / s.height) * 180
                // Past this latitude every column of the projection converges on the pole and
                // the dots wind into a visible spiral, so leave the ice caps bare.
                guard abs(latitude) < 82 else {
                    y += step
                    continue
                }
                // Widen the step towards the poles; clamp so the very last rows stay sane.
                let squeeze = min(6, 1 / max(0.17, cos(latitude * .pi / 180)))
                let rowStep = step * CGFloat(squeeze)
                // Offset alternate rows by half a step for a denser, hex-like packing.
                var x = (Int(y / step) % 2 == 0) ? rowStep / 2 : rowStep
                // Stretch each dot horizontally by the same factor, so the projection's
                // squeeze turns the ellipse back into a round dot on the sphere instead of a
                // sliver.
                let dotWidth = dot * CGFloat(squeeze)
                while x < s.width {
                    let longitude = Double(x / s.width) * 360 - 180
                    if WorldLandMask.isLand(latitude: latitude, longitude: longitude) {
                        ctx.cgContext.fillEllipse(
                            in: CGRect(x: x - dotWidth / 2, y: y - dot / 2, width: dotWidth, height: dot)
                        )
                    }
                    x += rowStep
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
