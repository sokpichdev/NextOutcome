//
//  DSNumberPad.swift
//  NextOutcome
//
//  Created by Sok Pich on 28/06/2026.

import SwiftUI

/// The app's custom numeric keyboard: a 4×3 grid of raised, tactile keys that drives
/// amount entry without ever summoning the system keyboard.
///
/// The pad reports *keystrokes*, not values — the caller owns the entered amount and
/// decides what a digit means. Keys are `DSRaisedButtonStyle` surfaces and fire a
/// haptic tick on tap; backspace additionally clears the whole amount on long press.
public struct DSNumberPad: View {
    /// Which extra key fills the bottom-leading slot next to `0`.
    public enum SecondaryKey: Equatable {
        /// Leave the slot empty.
        case none
        /// A "00" key that appends two zeroes — handy for whole-dollar amounts.
        case doubleZero
        /// A decimal-separator key, localized to the current locale.
        case decimal
    }

    /// One key on the pad. Modelled explicitly rather than as a raw string so the
    /// grid's layout and its behaviour can't drift apart.
    private enum Key: Hashable {
        case digit(Int)
        case secondary(SecondaryKey)
        case backspace
        case blank
    }

    /// Which extra key to show in the bottom-leading slot.
    private let secondaryKey: SecondaryKey
    /// Called with the tapped digit (0–9).
    private let onDigit: (Int) -> Void
    /// Called when the secondary key is tapped. Unused when `secondaryKey` is `.none`.
    private let onSecondary: () -> Void
    /// Called when backspace is tapped.
    private let onBackspace: () -> Void
    /// Called when backspace is long-pressed — clears the whole entry.
    private let onClear: () -> Void

    /// Bumped on every keystroke to drive `.sensoryFeedback`, which fires on change.
    @State private var tapTick = 0
    /// Bumped when a long-press clear fires, for its heavier haptic.
    @State private var clearTick = 0

    /// Creates a number pad.
    /// - Parameters:
    ///   - secondaryKey: Which extra key to show beside `0`. Defaults to `.doubleZero`.
    ///   - onDigit: Called with the tapped digit (0–9).
    ///   - onSecondary: Called when the secondary key is tapped. Defaults to no-op.
    ///   - onBackspace: Called when backspace is tapped.
    ///   - onClear: Called when backspace is long-pressed. Defaults to no-op, which
    ///     also suppresses the long-press gesture.
    public init(
        secondaryKey: SecondaryKey = .doubleZero,
        onDigit: @escaping (Int) -> Void,
        onSecondary: @escaping () -> Void = {},
        onBackspace: @escaping () -> Void,
        onClear: (() -> Void)? = nil
    ) {
        self.secondaryKey = secondaryKey
        self.onDigit = onDigit
        self.onSecondary = onSecondary
        self.onBackspace = onBackspace
        self.onClear = onClear ?? {}
        self.supportsClear = onClear != nil
    }

    /// Whether the caller supplied an `onClear`, enabling the long-press-to-clear gesture.
    private let supportsClear: Bool

    /// The key grid, top row first.
    private var rows: [[Key]] {
        [
            [.digit(1), .digit(2), .digit(3)],
            [.digit(4), .digit(5), .digit(6)],
            [.digit(7), .digit(8), .digit(9)],
            [secondaryKey == .none ? .blank : .secondary(secondaryKey), .digit(0), .backspace]
        ]
    }

    public var body: some View {
        VStack(spacing: DSLayout.spacingMedium) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: DSLayout.spacingMedium) {
                    ForEach(row, id: \.self) { key in
                        keyView(key)
                    }
                }
            }
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: tapTick)
        .sensoryFeedback(.impact(weight: .medium), trigger: clearTick)
    }

    /// Builds one key. A blank slot renders as empty space that still holds its column
    /// width, so the grid stays aligned.
    /// - Parameter key: The key to build.
    @ViewBuilder
    private func keyView(_ key: Key) -> some View {
        switch key {
        case .blank:
            // Matches a raised key's full height — face plus lip — so a pad with no
            // secondary key keeps its bottom row aligned with the rows above.
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: Self.keyHeight + DSDepth.small)
        case .backspace:
            backspaceKey
        case .digit(let value):
            keyButton(label: Text(verbatim: "\(value)")) {
                onDigit(value)
            }
        case .secondary(let kind):
            keyButton(label: Text(verbatim: secondaryLabel(kind))) {
                onSecondary()
            }
        }
    }

    /// Backspace gets its own builder because it carries a long-press-to-clear gesture
    /// on top of the plain tap the other keys use.
    private var backspaceKey: some View {
        keyButton(label: Image(systemName: "delete.left.fill"), action: onBackspace)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.45)
                    .onEnded { _ in
                        guard supportsClear else { return }
                        clearTick &+= 1
                        onClear()
                    }
            )
            .accessibilityLabel("Delete")
            .accessibilityHint(supportsClear ? "Double tap to delete. Touch and hold to clear the amount." : "")
    }

    /// Builds a raised key with the shared face/lip treatment, firing a haptic tick
    /// before invoking `action`.
    /// - Parameters:
    ///   - label: The key's content.
    ///   - action: What the key does.
    private func keyButton(label: some View, action: @escaping () -> Void) -> some View {
        Button {
            tapTick &+= 1
            action()
        } label: {
            label
                .font(Self.keyFont)
                .foregroundStyle(DSColor.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: Self.keyHeight)
        }
        .buttonStyle(
            DSRaisedButtonStyle(
                face: DSColor.surfaceElevated,
                lip: DSLip.surface,
                cornerRadius: DSLayout.chipRadius + 4,
                depth: DSDepth.small
            )
        )
    }

    /// The label for the secondary key. `.decimal` follows the user's locale rather
    /// than hardcoding "." so the pad matches how they read the amount above it.
    /// - Parameter kind: Which secondary key is in use.
    private func secondaryLabel(_ kind: SecondaryKey) -> String {
        switch kind {
        case .none: ""
        case .doubleZero: "00"
        case .decimal: Locale.current.decimalSeparator ?? "."
        }
    }

    /// The height of every key. Comfortably above the 44pt minimum touch target.
    private static let keyHeight: CGFloat = 52
    /// Monospaced so digits don't shift width between keys.
    private static let keyFont = Font.system(size: 26, weight: .semibold, design: .rounded)
}

#if DEBUG
#Preview("Number pad") {
    @Previewable @State var entry = ""
    return VStack(spacing: DSLayout.spacingLarge) {
        Text(entry.isEmpty ? "0" : entry)
            .font(.system(size: 44, weight: .bold, design: .monospaced))
            .foregroundStyle(DSColor.textPrimary)
        DSNumberPad(
            onDigit: { entry.append("\($0)") },
            onSecondary: { entry.append("00") },
            onBackspace: { _ = entry.popLast() },
            onClear: { entry = "" }
        )
    }
    .padding(DSLayout.margin)
    .frame(maxHeight: .infinity)
    .background(DSColor.background)
}
#endif
