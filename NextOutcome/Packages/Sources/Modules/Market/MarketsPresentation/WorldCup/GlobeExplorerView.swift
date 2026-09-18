//
//  GlobeExplorerView.swift
//  NextOutcome
//

import SwiftUI
import MapKit
import DesignSystem

/// Full-screen globe opened from the side menu, styled after Apple Maps' globe view: MapKit's
/// own 3D Earth (realistic elevation, free spin/zoom/tilt), floating material controls, a
/// map-style switcher, and a bottom card of the favourites that flies the camera to a nation.
public struct GlobeExplorerView: View {
    /// Shared with the World Cup hub, so opening the globe reuses already-loaded odds.
    @State private var viewModel: WorldCupHubViewModel
    /// The camera; starts far enough out that MapKit renders the whole globe.
    @State private var position: MapCameraPosition = .camera(Self.overviewCamera)
    /// The imagery the globe is drawn with.
    @State private var style: GlobeMapStyle = .satellite
    /// The nation the camera last flew to, highlighted on the globe and in the list.
    @State private var focusedID: GlobeCountry.ID?
    /// Whether the favourites card shows all five rows or just the leader, like Apple Maps'
    /// sheet detents. Starts collapsed so the globe gets the screen.
    @State private var isCardExpanded = false
    /// Closes the screen.
    private let onClose: () -> Void

    /// Creates the view.
    /// - Parameters:
    ///   - viewModel: The World Cup hub view model supplying the winner market.
    ///   - onClose: Called when the close button is tapped.
    public init(viewModel: WorldCupHubViewModel, onClose: @escaping () -> Void) {
        self._viewModel = State(initialValue: viewModel)
        self.onClose = onClose
    }

    /// The whole-Earth view the screen opens on and the "globe" button returns to.
    private static let overviewCamera = MapCamera(
        centerCoordinate: CLLocationCoordinate2D(latitude: 25, longitude: -30),
        distance: 42_000_000
    )

    /// The pills to place on the globe, ranked by win chance.
    private var countries: [GlobeCountry] {
        MapGlobeBuilder.countries(from: viewModel.winnerEvent, teams: viewModel.teamsByName)
    }

    public var body: some View {
        Map(position: $position) {
            ForEach(countries) { country in
                Annotation(country.name, coordinate: country.coordinate, anchor: .center) {
                    GlobePill(country: country, isFocused: country.id == focusedID)
                        .onTapGesture { fly(to: country) }
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(style.mapStyle)
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        // Insetting the map itself (rather than the full-bleed container) keeps MapKit's logo
        // and Legal link laid out above the card instead of colliding under it.
        .safeAreaInset(edge: .bottom) { bottomCard }
        .overlay(alignment: .topLeading) { titleCard }
        .overlay(alignment: .topTrailing) { controls }
        .background(Color.black.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .task { await viewModel.loadIfNeeded() }
    }

    // MARK: overlays

    /// A small floating title, like Apple Maps' place card header.
    private var titleCard: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Globe").font(DSFont.headline)
            Text("World Cup winner odds").font(DSFont.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.leading, DSLayout.margin)
        .padding(.top, DSLayout.spacingSmall)
    }

    /// Apple Maps–style stacked control group: close, map style, and back-to-globe.
    private var controls: some View {
        VStack(spacing: 0) {
            controlButton("xmark", label: "Close globe", action: onClose)
            Divider().frame(width: 28)
            Menu {
                Picker("Map style", selection: $style) {
                    ForEach(GlobeMapStyle.allCases) { style in
                        Label(style.title, systemImage: style.glyph).tag(style)
                    }
                }
            } label: {
                controlGlyph("map")
            }
            .accessibilityLabel("Map style")
            Divider().frame(width: 28)
            controlButton("globe.americas", label: "Show whole globe") {
                focusedID = nil
                withAnimation(.easeInOut(duration: 1.2)) { position = .camera(Self.overviewCamera) }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 8, y: 2)
        .padding(.trailing, DSLayout.margin)
        .padding(.top, DSLayout.spacingSmall)
    }

    /// One button in the control group.
    private func controlButton(_ glyph: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { controlGlyph(glyph) }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
    }

    /// The icon shared by every control, sized to Apple Maps' 44pt hit target.
    private func controlGlyph(_ glyph: String) -> some View {
        Image(systemName: glyph)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(.primary)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
    }

    /// The bottom card: load state, or the top five favourites (tap to fly there).
    @ViewBuilder
    private var bottomCard: some View {
        VStack(alignment: .leading, spacing: DSLayout.spacingSmall) {
            Button {
                withAnimation(.spring(duration: 0.35)) { isCardExpanded.toggle() }
            } label: {
                Capsule()
                    .fill(.secondary.opacity(0.5))
                    .frame(width: 36, height: 5)
                    .frame(maxWidth: .infinity, minHeight: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isCardExpanded ? "Collapse favourites" : "Expand favourites")
            switch viewModel.state {
            case .idle, .loading:
                HStack { ProgressView(); Text("Loading odds…").foregroundStyle(.secondary) }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DSLayout.spacing)
            case .failed(let message):
                Text(message).foregroundStyle(.secondary)
            case .loaded where countries.isEmpty:
                Text("No odds yet").foregroundStyle(.secondary)
            case .loaded:
                Text("Favourites").font(DSFont.title3.bold())
                ForEach(Array(countries.prefix(isCardExpanded ? 5 : 1).enumerated()), id: \.element.id) { index, country in
                    leaderRow(rank: index + 1, country: country)
                }
            }
        }
        .font(DSFont.body)
        .padding(DSLayout.margin)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.horizontal, DSLayout.spacingSmall)
        .gesture(DragGesture(minimumDistance: 20).onEnded { drag in
            withAnimation(.spring(duration: 0.35)) { isCardExpanded = drag.translation.height < 0 }
        })
    }

    /// A tappable favourite row: rank, colour dot, name, win %.
    private func leaderRow(rank: Int, country: GlobeCountry) -> some View {
        Button { fly(to: country) } label: {
            HStack(spacing: DSLayout.spacingSmall) {
                Text("\(rank)").foregroundStyle(.secondary).frame(width: 18, alignment: .leading)
                Circle().fill(country.color).frame(width: 10, height: 10)
                Text(country.name)
                Spacer()
                Text(country.caption).monospacedDigit().fontWeight(.semibold)
            }
            .padding(.vertical, 6)
            .background(country.id == focusedID ? Color.white.opacity(0.08) : .clear,
                        in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Flies the camera down to a nation, tilted slightly the way Apple Maps frames a place.
    private func fly(to country: GlobeCountry) {
        focusedID = country.id
        withAnimation(.easeInOut(duration: 1.4)) {
            position = .camera(MapCamera(centerCoordinate: country.coordinate,
                                         distance: 6_000_000, heading: 0, pitch: 30))
        }
    }
}

/// The imagery options offered by the map-style menu, mirroring Apple Maps' choices.
enum GlobeMapStyle: String, CaseIterable, Identifiable {
    case explore, satellite, hybrid

    var id: String { rawValue }

    /// The menu label.
    var title: String {
        switch self {
        case .explore:   return "Explore"
        case .satellite: return "Satellite"
        case .hybrid:    return "Hybrid"
        }
    }

    /// The menu icon.
    var glyph: String {
        switch self {
        case .explore:   return "map"
        case .satellite: return "globe.americas.fill"
        case .hybrid:    return "square.stack.3d.up"
        }
    }

    /// The MapKit style; realistic elevation is what makes MapKit draw the 3D globe.
    var mapStyle: MapStyle {
        switch self {
        case .explore:   return .standard(elevation: .realistic, pointsOfInterest: .excludingAll)
        case .satellite: return .imagery(elevation: .realistic)
        case .hybrid:    return .hybrid(elevation: .realistic, pointsOfInterest: .excludingAll)
        }
    }
}

/// A country's odds pill on the map: colour dot, abbreviation, and win %.
private struct GlobePill: View {
    let country: GlobeCountry
    let isFocused: Bool

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(country.color).frame(width: 8, height: 8)
            Text(country.abbreviation).fontWeight(.bold)
            // Long shots drop the "<1%" so the crowded regions stay readable; the focused
            // pill always shows its number.
            if country.percent >= 0.01 || isFocused {
                Text(country.caption).foregroundStyle(.secondary)
            }
        }
        .font(.caption2)
        .monospacedDigit()
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(isFocused ? country.color : .white.opacity(0.15),
                                  lineWidth: isFocused ? 2 : 1))
        .scaleEffect(isFocused ? 1.2 : 1)
        .animation(.spring(duration: 0.3), value: isFocused)
    }
}

private extension GlobeCountry {
    /// The pill's map coordinate.
    var coordinate: CLLocationCoordinate2D { .init(latitude: lat, longitude: lon) }
    /// The country's brand colour, or the app accent when unknown.
    var color: Color { Color(hexString: colorHex) ?? DSColor.accent }
}
