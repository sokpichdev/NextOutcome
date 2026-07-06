//
//  USStateMapView.swift
//  NextOutcome
//
//  Created by Sok Pich on 05/07/2026.
//

import SwiftUI
import DesignSystem

/// A real, state-shaped US election map. Each state is filled by whatever color the caller
/// supplies (typically a `RaceLean` color), with a thin border between states, scaled to fit
/// the available width while preserving the source geometry's aspect ratio.
///
/// Built from `USStateGeometry`'s embedded path data (parsed once per state via
/// `SVGPathParser`) rather than any bitmap/globe trick — this is the one place in the app that
/// draws real state boundary shapes.
public struct USStateMapView: View {
    /// Fill color for each postal-code-keyed state; states missing from this map render in a
    /// neutral "no data" color.
    private let colors: [String: Color]
    /// Called when a state is tapped, with its postal abbreviation.
    private let onSelect: (String) -> Void
    /// The parsed path for every state, built once and reused across re-renders.
    private static let statePaths: [(code: String, path: Path)] = USStateGeometry.paths.map {
        (code: $0.key, path: SVGPathParser.path(from: $0.value))
    }

    /// Creates the map.
    /// - Parameters:
    ///   - colors: Fill color per postal-code state abbreviation.
    ///   - onSelect: Called with a state's postal abbreviation when tapped. Defaults to a no-op.
    public init(colors: [String: Color], onSelect: @escaping (String) -> Void = { _ in }) {
        self.colors = colors
        self.onSelect = onSelect
    }

    public var body: some View {
        GeometryReader { geo in
            // A single shared CGAffineTransform (anchored at the viewBox's own origin) keeps
            // every state's coordinates consistent with each other after scaling — unlike
            // Shape's `.scale(anchor:)`, which anchors around each shape's *own* bounding box
            // and would scatter the states apart from one another.
            let scale = geo.size.width / USStateGeometry.viewBoxSize.width
            let transform = CGAffineTransform(scaleX: scale, y: scale)
            ZStack(alignment: .topLeading) {
                ForEach(Self.statePaths, id: \.code) { entry in
                    let scaled = entry.path.applying(transform)
                    scaled
                        .fill(colors[entry.code] ?? DSColor.surfaceElevated)
                        .overlay(scaled.stroke(DSColor.background, lineWidth: 0.75))
                        .onTapGesture { onSelect(entry.code) }
                }
            }
            .frame(width: geo.size.width, height: USStateGeometry.viewBoxSize.height * scale, alignment: .topLeading)
        }
        .aspectRatio(USStateGeometry.viewBoxSize.width / USStateGeometry.viewBoxSize.height, contentMode: .fit)
    }
}
