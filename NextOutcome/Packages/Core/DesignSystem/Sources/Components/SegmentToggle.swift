import SwiftUI

/// Pill-shaped segmented control. Segments can show a red "live" dot (e.g. live orderbook tab).
///
/// A custom alternative to SwiftUI's built-in `Picker(.segmented)`, styled to
/// match the app's dark theme, with equal-width segments and an optional pulsing
/// red dot to mark a "live" tab (e.g. distinguishing a live orderbook tab from a
/// historical one).
public struct SegmentToggle: View {
    /// Describes a single segment's label and whether it should show a "live" dot.
    public struct Segment {
        /// The text shown for this segment.
        public let title: String
        /// Whether to show a small red dot before the title, typically to
        /// indicate this segment shows live/real-time data.
        public let showsLiveDot: Bool

        /// Creates a segment description.
        /// - Parameters:
        ///   - title: The label to display.
        ///   - showsLiveDot: Whether to show the live indicator dot. Defaults to `false`.
        public init(title: String, showsLiveDot: Bool = false) {
            self.title = title
            self.showsLiveDot = showsLiveDot
        }
    }

    /// The segments to display, in order.
    private let segments: [Segment]
    /// The index into `segments` of the currently selected one.
    @Binding private var selection: Int

    /// Creates a segmented toggle.
    /// - Parameters:
    ///   - segments: The segments to display.
    ///   - selection: A binding to the selected segment's index.
    public init(segments: [Segment], selection: Binding<Int>) {
        self.segments = segments
        self._selection = selection
    }

    public var body: some View {
        HStack(spacing: DSLayout.spacingXSmall) {
            ForEach(segments.indices, id: \.self) { index in
                segmentButton(for: index)
            }
        }
        .padding(DSLayout.spacingXSmall)
        .background(DSColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: DSLayout.chipRadius))
    }

    /// Builds a single segment button, showing an accent-gradient background
    /// when selected and an optional live dot before its title.
    /// - Parameter index: The index of the segment within `segments` to render.
    /// - Returns: A button that sets `selection` to `index` when tapped.
    private func segmentButton(for index: Int) -> some View {
        let segment = segments[index]
        let isSelected = selection == index
        return Button {
            selection = index
        } label: {
            HStack(spacing: DSLayout.spacingXSmall) {
                if segment.showsLiveDot {
                    Circle()
                        .fill(DSColor.negative)
                        .frame(width: DSLayout.spacingXSmall, height: DSLayout.spacingXSmall)
                }
                Text(segment.title)
                    .font(DSFont.subheadline.bold())
            }
            .foregroundStyle(isSelected ? .white : DSColor.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DSLayout.spacingSmall)
            .background(isSelected ? AnyView(DSGradient.accent) : AnyView(Color.clear))
            .clipShape(RoundedRectangle(cornerRadius: DSLayout.chipRadius))
        }
        .buttonStyle(.plain)
    }
}
