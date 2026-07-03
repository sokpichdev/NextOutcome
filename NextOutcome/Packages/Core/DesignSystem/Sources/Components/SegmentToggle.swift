import SwiftUI

/// Pill-shaped segmented control. Segments can show a red "live" dot (e.g. live orderbook tab).
public struct SegmentToggle: View {
    public struct Segment {
        public let title: String
        public let showsLiveDot: Bool

        public init(title: String, showsLiveDot: Bool = false) {
            self.title = title
            self.showsLiveDot = showsLiveDot
        }
    }

    private let segments: [Segment]
    @Binding private var selection: Int

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
