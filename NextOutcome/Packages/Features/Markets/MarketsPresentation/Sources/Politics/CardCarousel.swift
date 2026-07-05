//
//  CardCarousel.swift
//  NextOutcome
//
//  Created by Sok Pich on 05/07/2026.
//

import SwiftUI
import DesignSystem

/// A single-card-at-a-time carousel: swipe left/right, or tap the chevron buttons, to change
/// cards — matching the web's "Referendums"/"Biggest races" carousels.
struct CardCarousel<Card: View>: View {
    /// How many cards are in the carousel.
    let count: Int
    /// The currently-shown card index.
    @Binding var index: Int
    /// Builds the card view for a given index.
    @ViewBuilder let card: (Int) -> Card

    /// The horizontal drag distance so far, for a subtle follow-the-finger offset.
    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: DSLayout.spacing) {
            card(index)
                .offset(x: dragOffset)
                .animation(.interactiveSpring(), value: dragOffset)
                .gesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in state = value.translation.width }
                        .onEnded { value in
                            if value.translation.width < -40 { advance(by: 1) }
                            else if value.translation.width > 40 { advance(by: -1) }
                        }
                )
            HStack(spacing: DSLayout.spacing) {
                chevronButton(systemName: "chevron.left") { advance(by: -1) }
                chevronButton(systemName: "chevron.right") { advance(by: 1) }
            }
        }
    }

    /// Moves the index by `delta`, clamped to the valid range (no wraparound).
    private func advance(by delta: Int) {
        index = min(max(index + delta, 0), max(count - 1, 0))
    }

    private func chevronButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(DSFont.subheadline.bold())
                .foregroundStyle(DSColor.textPrimary)
                .frame(width: 36, height: 36)
                .background(DSColor.surfaceElevated)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
