//
//  Skeleton.swift
//  NextOutcome
//
//  Created by Sok Pich on 23/08/2026.
//
import SwiftUI

// MARK: - Primitives

/// One placeholder shape standing in for a piece of text, an icon, or a button
/// that hasn't loaded yet.
///
/// Deliberately inert: it does **not** animate itself. The shimmer sweep is applied
/// once, higher up, by `shimmering()` — see that modifier's note on why per-block
/// animation is both slower and visually wrong.
public struct SkeletonBlock: View {
    /// The block's width. `nil` (the default) lets it stretch to fill its container,
    /// which is what a full-width text line wants.
    private let width: CGFloat?
    /// The block's height — usually the cap height of the text it replaces, not the
    /// text's full line height, so a run of blocks reads as text rather than as bars.
    private let height: CGFloat
    /// The corner radius. Defaults to a text-line radius; pass `DSLayout.chipRadius`
    /// or `DSLayout.cardRadius` when standing in for a chip or a card.
    private let cornerRadius: CGFloat

    /// Creates a placeholder block.
    /// - Parameters:
    ///   - width: Fixed width, or `nil` to fill the container. Defaults to `nil`.
    ///   - height: The block's height.
    ///   - cornerRadius: The corner radius. Defaults to `4`.
    public init(width: CGFloat? = nil, height: CGFloat, cornerRadius: CGFloat = 4) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(DSColor.skeleton)
            .frame(width: width, height: height)
    }
}

/// A circular placeholder, for avatars and gauges. See `SkeletonBlock` on why this
/// doesn't animate on its own.
public struct SkeletonCircle: View {
    /// The circle's diameter.
    private let size: CGFloat

    /// Creates a circular placeholder.
    /// - Parameter size: The diameter, matching the avatar/gauge it replaces.
    public init(size: CGFloat) {
        self.size = size
    }

    public var body: some View {
        Circle()
            .fill(DSColor.skeleton)
            .frame(width: size, height: size)
    }
}

// MARK: - Shimmer

extension View {
    /// Sweeps a soft highlight band left-to-right across this view, forever.
    ///
    /// Apply this to a *stack of skeleton shapes*, not to a card or any other view with
    /// an opaque background: the band is masked by the content's own alpha, so an opaque
    /// container would light up as one solid bar instead of only its placeholder blocks.
    /// Card-shaped skeletons therefore keep their chrome outside the shimmer and wrap only
    /// the inner block stack.
    ///
    /// One sweep animates the whole group rather than each block separately — cheaper, and
    /// it keeps the blocks in phase, which is what makes a skeleton read as a single
    /// surface that's still filling in.
    ///
    /// Honors Reduce Motion by dropping the animation entirely and leaving the blocks
    /// static; the placeholder still communicates "loading" through its shape.
    /// - Parameter isActive: Whether to shimmer. Defaults to `true`.
    public func shimmering(_ isActive: Bool = true) -> some View {
        modifier(ShimmerModifier(isActive: isActive))
    }
}

/// The sweep implementation behind `shimmering(_:)`.
///
/// The band is animated through the gradient's own `UnitPoint`s rather than by offsetting
/// a fixed-width overlay: unit points are resolution-independent, so one sweep reads the
/// same across a full-width card and a narrow column, and there's no dependency on a
/// `GeometryReader` having reported a non-zero width before the animation starts.
private struct ShimmerModifier: ViewModifier {
    /// Set when the user has asked the system to reduce motion; suppresses the sweep.
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Whether the caller wants the sweep at all.
    let isActive: Bool
    /// The band's leading edge, in unit space. Starts off-screen left.
    @State private var start = UnitPoint(x: -1.4, y: 0.5)
    /// The band's trailing edge, one content-width behind `start`.
    @State private var end = UnitPoint(x: -0.4, y: 0.5)

    /// Seconds for one full left-to-right pass.
    private static let duration: Double = 1.4

    func body(content: Content) -> some View {
        if isActive && !reduceMotion {
            content
                .overlay {
                    LinearGradient(
                        // The outer stops are the highlight at zero opacity rather than
                        // `.clear`, which interpolates through black and leaves a dirty
                        // edge trailing the band.
                        colors: [
                            DSColor.skeletonHighlight.opacity(0),
                            DSColor.skeletonHighlight,
                            DSColor.skeletonHighlight.opacity(0)
                        ],
                        startPoint: start,
                        endPoint: end
                    )
                    // Masked by the content's own alpha, so only the placeholder shapes
                    // light up — the gaps between them stay dark.
                    .mask(content)
                    .allowsHitTesting(false)
                }
                .onAppear {
                    withAnimation(.linear(duration: Self.duration).repeatForever(autoreverses: false)) {
                        start = UnitPoint(x: 1.0, y: 0.5)
                        end = UnitPoint(x: 2.0, y: 0.5)
                    }
                }
        } else {
            content
        }
    }
}

// MARK: - Styles

/// The shape of the content a skeleton stands in for.
///
/// Each case mirrors a real component's geometry closely enough that the swap to loaded
/// content doesn't move anything — the point of a skeleton over a spinner is that the
/// layout is already correct before the data lands.
public enum SkeletonStyle: Equatable, Sendable {
    /// An `EventCard`-shaped feed card: icon, title lines, chance gauge, Yes/No buttons,
    /// and a volume footer. Use for the markets feed and the hub card lists.
    case feedCard
    /// A `GameCard`-shaped fixture card under a dated section header: status line, two
    /// team rows, and a row of odds buttons. Use for the sports feeds.
    case gameCard
    /// A compact list row: rank, avatar, two text lines, and a trailing value. Use for
    /// leaderboards, movers, holders, comments, and activity.
    case row
    /// A portfolio dashboard: value/PnL header card, a section header, and position rows.
    case dashboard
    /// A single reserved region of a fixed height, for charts and other content whose
    /// internals can't be usefully sketched.
    /// - Parameter height: The height the loaded content will occupy.
    case block(height: CGFloat)
}

/// Where a skeleton sits, which decides whether it supplies its own margins.
public enum SkeletonPlacement: Equatable, Sendable {
    /// The skeleton stands in for a whole content area: it applies the standard screen
    /// margins and pins itself to the top of the space it's given.
    case screen
    /// The skeleton sits inside a container that already provides margins (a padded
    /// `ScrollView` body, a card, a detail strip), so it adds none of its own.
    case inline
}

// MARK: - SkeletonView

/// The placeholder shown while a screen's first payload is in flight.
///
/// Prefer this over `StateView(.loading)` whenever the incoming content is a list of
/// uniform rows or cards — the shape is known before the data is, so there's no reason
/// to show a spinner and then reflow. Keep `StateView(.loading)` for short inline waits,
/// for content whose shape isn't predictable, and for anything re-fetched on every
/// keystroke, where a shimmer would strobe.
public struct SkeletonView: View {
    /// The shape being stood in for.
    private let style: SkeletonStyle
    /// How many rows/cards to draw. Only meaningful for the repeating styles.
    private let count: Int
    /// Whether this supplies its own screen margins.
    private let placement: SkeletonPlacement

    /// Creates a skeleton placeholder.
    /// - Parameters:
    ///   - style: The shape of the content being awaited.
    ///   - count: How many rows/cards to draw (for `.dashboard`, how many position rows
    ///     below the header). Defaults to `6`; ignored by `.block`.
    ///   - placement: Whether to apply screen margins. Defaults to `.screen`.
    public init(_ style: SkeletonStyle, count: Int = 6, placement: SkeletonPlacement = .screen) {
        self.style = style
        self.count = count
        self.placement = placement
    }

    public var body: some View {
        switch placement {
        case .screen:
            // Wrapped in a scroll view — a disabled one, since there's nothing to reach —
            // because that is what makes the placeholder accept the height it's offered.
            // A bare stack of cards reports its full content height as its minimum, which
            // overflows the screen's `VStack` and shifts the whole shell (top bar and rail
            // included) upward for the duration of the load. The scroll view takes whatever
            // it's proposed and clips, so the chrome stays put and the last card runs off
            // the bottom edge the way a real feed does.
            ScrollView {
                labeled
                    .padding(.horizontal, DSLayout.margin)
                    .padding(.vertical, DSLayout.spacing)
            }
            .scrollDisabled(true)
            .scrollIndicators(.hidden)
        case .inline:
            labeled
        }
    }

    /// The skeleton body, full-width and announced to VoiceOver as one "Loading" element
    /// rather than as two dozen anonymous shapes.
    private var labeled: some View {
        body(for: style)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Loading")
    }

    @ViewBuilder
    private func body(for style: SkeletonStyle) -> some View {
        switch style {
        case .feedCard:
            VStack(spacing: DSLayout.spacing) {
                ForEach(0..<count, id: \.self) { _ in feedCard }
            }
        case .gameCard:
            VStack(alignment: .leading, spacing: DSLayout.spacing) {
                SkeletonBlock(width: 120, height: 10).shimmering()
                ForEach(0..<count, id: \.self) { _ in gameCard }
            }
        case .row:
            VStack(spacing: DSLayout.spacingSmall) {
                ForEach(0..<count, id: \.self) { _ in row }
            }
            .shimmering()
        case .dashboard:
            dashboard.shimmering()
        case .block(let height):
            SkeletonBlock(height: height, cornerRadius: DSLayout.cardRadius)
                .shimmering()
        }
    }

    // MARK: Feed card

    /// Mirrors `EventCard`: 40pt icon, a two-line title with a status caption, a chance
    /// gauge, the Yes/No button pair, and the volume/market-count footer.
    private var feedCard: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSLayout.spacing) {
                HStack(alignment: .top, spacing: DSLayout.spacing) {
                    SkeletonBlock(
                        width: DSLayout.iconsize,
                        height: DSLayout.iconsize,
                        cornerRadius: DSLayout.chipRadius
                    )
                    VStack(alignment: .leading, spacing: DSLayout.spacingXSmall) {
                        SkeletonBlock(height: 13)
                        SkeletonBlock(width: 150, height: 13)
                        SkeletonBlock(width: 90, height: 10)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    SkeletonCircle(size: 44)
                }
                HStack(spacing: DSLayout.spacingSmall) {
                    SkeletonBlock(height: 34, cornerRadius: DSLayout.chipRadius)
                    SkeletonBlock(height: 34, cornerRadius: DSLayout.chipRadius)
                }
                HStack {
                    SkeletonBlock(width: 64, height: 10)
                    Spacer()
                    SkeletonBlock(width: 56, height: 10)
                }
            }
            // Only the blocks shimmer — the card's surface and border are real chrome and
            // stay put, so the sweep doesn't read as a bar crossing the whole card.
            .shimmering()
        }
    }

    // MARK: Game card

    /// Mirrors `GameCard`: a status/volume line, two team rows, and three odds buttons.
    private var gameCard: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DSLayout.spacing) {
                HStack(spacing: DSLayout.spacingSmall) {
                    SkeletonBlock(width: 70, height: 10)
                    Spacer()
                    SkeletonBlock(width: 54, height: 10)
                }
                teamRow
                teamRow
                HStack(spacing: DSLayout.spacingSmall) {
                    SkeletonBlock(height: 34, cornerRadius: DSLayout.chipRadius)
                    SkeletonBlock(height: 34, cornerRadius: DSLayout.chipRadius)
                    SkeletonBlock(height: 34, cornerRadius: DSLayout.chipRadius)
                }
            }
            .shimmering()
        }
    }

    /// One team line inside `gameCard`: crest, name, score.
    private var teamRow: some View {
        HStack(spacing: DSLayout.spacingMedium) {
            SkeletonBlock(width: 28, height: 20)
            SkeletonBlock(width: 130, height: 12)
            Spacer(minLength: DSLayout.spacing)
            SkeletonBlock(width: 22, height: 14)
        }
    }

    // MARK: Row

    /// Mirrors the compact list rows (`MoverRow`, `LeaderboardRow`, holder/activity rows):
    /// rank, 40pt avatar, two text lines, and a right-aligned value pair.
    private var row: some View {
        HStack(spacing: DSLayout.spacingMedium) {
            SkeletonBlock(width: 14, height: 12)
            SkeletonBlock(
                width: DSLayout.iconsize,
                height: DSLayout.iconsize,
                cornerRadius: DSLayout.chipRadius
            )
            VStack(alignment: .leading, spacing: DSLayout.spacingXSmall) {
                SkeletonBlock(height: 12)
                SkeletonBlock(width: 110, height: 10)
            }
            Spacer(minLength: DSLayout.spacing)
            VStack(alignment: .trailing, spacing: DSLayout.spacingXSmall) {
                SkeletonBlock(width: 52, height: 12)
                SkeletonBlock(width: 34, height: 10)
            }
        }
        .padding(.vertical, DSLayout.spacingSmall)
    }

    // MARK: Dashboard

    /// Mirrors the portfolio dashboard: the `ValuePnLHeader` card, an "Open positions"
    /// section header, and a run of position rows.
    private var dashboard: some View {
        VStack(alignment: .leading, spacing: DSLayout.spacing) {
            SkeletonBlock(height: 110, cornerRadius: DSLayout.cardRadius)
            SkeletonBlock(width: 100, height: 10)
                .padding(.top, DSLayout.spacing)
            ForEach(0..<count, id: \.self) { _ in row }
        }
    }
}

#if DEBUG
#Preview("Skeletons — feed") {
    ScrollView { SkeletonView(.feedCard, count: 3) }
        .background(DSColor.background)
}

#Preview("Skeletons — games") {
    ScrollView { SkeletonView(.gameCard, count: 3) }
        .background(DSColor.background)
}

#Preview("Skeletons — rows") {
    ScrollView { SkeletonView(.row, count: 8) }
        .background(DSColor.background)
}

#Preview("Skeletons — dashboard") {
    ScrollView { SkeletonView(.dashboard, count: 4) }
        .background(DSColor.background)
}
#endif
