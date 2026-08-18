//
//  RollingNumber.swift
//  NextOutcome
//
//  Created by Sok Pich on 18/08/2026.
//

import SwiftUI

/// Timings for the design system's animations, alongside the colour/font/layout tokens.
public enum DSAnimation {
    /// The digit roll used by `rollingNumber(_:)`.
    ///
    /// Short and non-bouncy on purpose: these numbers sit inside dense card rows, and a
    /// spring that overshoots reads as the layout wobbling rather than the value updating.
    public static let rollingNumber: Animation = .snappy(duration: 0.3)

    /// The roll for numbers that update many times a second — a socket-fed spot price, a
    /// per-second countdown.
    ///
    /// Deliberately faster than `rollingNumber`: a roll still in flight when the next tick
    /// lands gets retargeted, so at the default duration a live price never settles and
    /// reads as a permanent blur instead of a value that moved.
    public static let liveNumber: Animation = .snappy(duration: 0.15)
}

/// A digit-roll transition for numbers that change while they're on screen — a volume that
/// ticks up on refresh, a liquidity figure that moves as the book fills.
public extension View {
    /// Rolls this view's digits up (when `value` rises) or down (when it falls).
    ///
    /// Apply it to the `Text` showing the number, passing the number *itself* — not its
    /// formatted string. SwiftUI derives the roll's direction by comparing the old and new
    /// values, which a `String` can't give it:
    /// ```swift
    /// Text("\(MarketFormatting.compactUSD(event.volume)) Vol.")
    ///     .rollingNumber(event.volume)
    /// ```
    ///
    /// Only *changes* animate. A first render is silent, and so is a card scrolling back
    /// into a lazy stack, since that's a fresh view rather than a changed one.
    ///
    /// Digits are monospaced so the label keeps its width mid-roll: with proportional
    /// figures each frame of the transition is a slightly different size, which nudges
    /// whatever sits beside the number and turns one value updating into a row twitching.
    /// - Parameters:
    ///   - value: The number this view is displaying.
    ///   - animation: The roll's timing. Defaults to `DSAnimation.rollingNumber`.
    /// - Returns: The view, rolling its digits whenever `value` changes.
    func rollingNumber(_ value: Double, animation: Animation = DSAnimation.rollingNumber) -> some View {
        self
            .monospacedDigit()
            .contentTransition(.numericText(value: value))
            .animation(animation, value: value)
    }

    /// `Decimal` overload, for the money values the domain layer deals in.
    /// - Parameters:
    ///   - value: The number this view is displaying.
    ///   - animation: The roll's timing. Defaults to `DSAnimation.rollingNumber`.
    /// - Returns: The view, rolling its digits whenever `value` changes.
    func rollingNumber(_ value: Decimal, animation: Animation = DSAnimation.rollingNumber) -> some View {
        rollingNumber(NSDecimalNumber(decimal: value).doubleValue, animation: animation)
    }

    /// Rolls a clock's digits downward as it ticks.
    ///
    /// The timer-specific spelling of the transition, which *fixes* the direction rather
    /// than deriving it per digit — what a clock wants, since 1:00 → 0:59 is one decrease
    /// even though the seconds digits jump from 00 up to 59.
    /// - Parameters:
    ///   - secondsRemaining: What's left on the clock; the tick that drives the roll.
    ///   - animation: The roll's timing. Defaults to `DSAnimation.liveNumber`.
    /// - Returns: The view, rolling its digits down on each tick.
    func rollingCountdown(_ secondsRemaining: Int, animation: Animation = DSAnimation.liveNumber) -> some View {
        self
            .monospacedDigit()
            .contentTransition(.numericText(countsDown: true))
            .animation(animation, value: secondsRemaining)
    }
}
