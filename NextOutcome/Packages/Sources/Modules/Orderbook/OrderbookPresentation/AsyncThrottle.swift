//
//  AsyncThrottle.swift
//  NextOutcome
//
//  Created by Sok Pich on 20/08/2026.
//

import Foundation

/// Rate-limits a socket-fed sequence down to something a screen can actually show.
///
/// The CLOB book and the RTDS price feed both tick far faster than 60fps during active
/// trading — tens of frames a second, each one landing in `@MainActor` `@Observable` state
/// and invalidating every view reading it. Nothing downstream benefits: a chart that
/// redraws 100 times a second renders the same pixels as one that redraws 20 times, at
/// five times the cost.
///
/// The policy is *leading-edge with newest-wins coalescing*:
/// - the first value of a quiet period is emitted immediately, so the UI never feels laggy;
/// - during the cooldown, later values overwrite each other rather than queueing, so the
///   screen shows the freshest state rather than replaying a backlog;
/// - the last value is always delivered, so a feed that stops mid-cooldown still leaves the
///   final price on screen rather than one tick behind.
///
/// Deliberately *not* an unbounded buffer drained one element per interval: with a producer
/// faster than the interval, that decimates but never catches up, so the display falls
/// further behind real time the longer the screen stays open.
extension AsyncSequence where Element: Sendable, Self: Sendable {
    /// Throttles this sequence to at most one element per `interval`.
    /// - Parameters:
    ///   - interval: The minimum spacing between emissions.
    ///   - clock: The clock used for the cooldown. Injectable for tests.
    /// - Returns: A stream carrying the same elements, coalesced to `interval`.
    func throttled(
        for interval: Duration,
        clock: ContinuousClock = ContinuousClock()
    ) -> AsyncStream<Element> {
        // A non-positive interval means "don't throttle" — the seam tests use so they can
        // drive a view model through cooperative scheduling instead of wall-clock waits.
        guard interval > .zero else { return passthrough() }

        return AsyncStream { continuation in
            let box = ThrottleBox<Element>()

            let upstream = Task {
                do {
                    for try await element in self { await box.set(element) }
                } catch {
                    // A failing upstream ends the throttled stream the same way a finished
                    // one does; typed error propagation isn't part of this contract.
                }
                await box.finish()
            }

            let emitter = Task {
                while let element = await box.next() {
                    continuation.yield(element)
                    do { try await clock.sleep(for: interval) } catch { break }
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                upstream.cancel()
                emitter.cancel()
            }
        }
    }

    /// This sequence republished as an `AsyncStream`, unthrottled.
    private func passthrough() -> AsyncStream<Element> {
        AsyncStream { continuation in
            let task = Task {
                do {
                    for try await element in self { continuation.yield(element) }
                } catch {}
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

/// The hand-off between the draining task and the emitting task: holds *one* pending
/// element (newest wins) and parks the emitter when there's nothing to send.
private actor ThrottleBox<Element: Sendable> {
    /// The newest element not yet emitted, if any.
    private var latest: Element?
    /// Whether upstream has finished (or been cancelled).
    private var isFinished = false
    /// The parked emitter, waiting for the next element.
    private var waiter: CheckedContinuation<Element?, Never>?

    /// Stores an element, replacing any pending one, or hands it straight to a parked emitter.
    func set(_ element: Element) {
        if let waiter {
            self.waiter = nil
            waiter.resume(returning: element)
        } else {
            latest = element
        }
    }

    /// Marks upstream done, releasing a parked emitter.
    func finish() {
        isFinished = true
        if let waiter {
            self.waiter = nil
            waiter.resume(returning: nil)
        }
    }

    /// The next element to emit, or `nil` once upstream is finished and nothing is pending.
    /// Parks until one of those is true.
    func next() async -> Element? {
        if let element = latest {
            latest = nil
            return element
        }
        if isFinished { return nil }
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                // `finish()` may have landed between the check above and this resume point.
                if isFinished {
                    continuation.resume(returning: nil)
                } else {
                    waiter = continuation
                }
            }
        } onCancel: {
            // A cancelled emitter must not stay parked on a continuation nobody will resume.
            Task { await self.finish() }
        }
    }
}

/// How often socket-fed state is allowed to republish into SwiftUI.
///
/// Both feeds tick faster than this; the numbers are the *display* rate, chosen so the
/// screen still reads as live while the render loop does a fraction of the work.
public enum LiveFeedRate {
    /// Prices, candles and book snapshots: 20 Hz. Fast enough that a moving price looks
    /// continuous, slow enough that each roll animation (150ms) can finish a good part of
    /// its transition before the next value retargets it.
    public static let display: Duration = .milliseconds(50)
    /// The order book ladder: 10 Hz. It's twenty rows of text rather than a single value,
    /// and no one reads depth at 20 frames a second.
    public static let ladder: Duration = .milliseconds(100)
}
