//
//  ScreenshotCapture.swift
//  NextOutcomeUITests
//
//  Writes deliverable PNGs to the host filesystem during a screenshot run.
//
//  Distinct from `attachScreenshot(of:named:)` in UITestHelpers, which attaches images to
//  the test report for debugging a failure. This path produces the images that ship in
//  the README, so it writes real files under stable names.
//

import XCTest

enum ScreenshotCapture {

    /// Where captured PNGs land on the *host*.
    ///
    /// `SIMULATOR_HOST_HOME` is exported into the simulator and points at the host's home
    /// directory, which the test runner can write to. `scripts/screenshots.sh` collects
    /// from the matching host path.
    static let directory: URL = {
        let host = ProcessInfo.processInfo.environment["SIMULATOR_HOST_HOME"]
            ?? NSHomeDirectory()
        return URL(fileURLWithPath: host)
            .appendingPathComponent("Library/Caches/nextoutcome-screenshots", isDirectory: true)
    }()
}

extension XCTestCase {

    /// Captures the current screen as `<name>.png`.
    ///
    /// Fails the test rather than returning quietly if the write fails — a screenshot run
    /// that silently produces nothing is worse than one that stops.
    /// - Parameters:
    ///   - name: The output filename, without extension. Matches the v1 filenames.
    ///   - app: The application under test.
    func capture(_ name: String,
                 of app: XCUIApplication,
                 file: StaticString = #filePath,
                 line: UInt = #line) {
        let directory = ScreenshotCapture.directory
        do {
            try FileManager.default.createDirectory(at: directory,
                                                    withIntermediateDirectories: true)
            let png = XCUIScreen.main.screenshot().pngRepresentation
            try png.write(to: directory.appendingPathComponent("\(name).png"))
        } catch {
            XCTFail("Could not write screenshot '\(name)': \(error)", file: file, line: line)
        }
    }

    /// Waits until the screen has stopped changing, then captures nothing — callers follow
    /// this with `capture`.
    ///
    /// Real content first (a "Vol" caption proves live cards are rendered), then a short
    /// settle beyond that so a just-arrived row is laid out before the shutter.
    /// - Parameters:
    ///   - app: The application under test.
    ///   - timeout: How long to wait for content. Defaults to the warm-load budget.
    func settle(_ app: XCUIApplication, timeout: TimeInterval = UIWait.load) {
        _ = app.anyVolumeLabel.waitForExistence(timeout: timeout)
        Thread.sleep(forTimeInterval: 0.6)
    }

    /// Launches the app in screenshot mode, optionally deep-linked into a category hub.
    /// - Parameters:
    ///   - slug: The category slug for `-preselectCategory`, or `nil` for a plain launch.
    ///   - tagID: The category's tag ID. Required when `slug` is given.
    /// - Returns: The launched application.
    func launchForScreenshots(preselecting slug: String? = nil,
                              tagID: String? = nil) -> XCUIApplication {
        if let slug, let tagID {
            return .launched(preselecting: slug, tagID: tagID,
                             extraArguments: ["-screenshotMode"])
        }
        let app = XCUIApplication()
        app.launchArguments += ["-screenshotMode"]
        app.launch()
        return app
    }

    /// Skips the test when a market that only exists during a live event is absent.
    ///
    /// Three v1 shots are tied to events that have concluded. Skipping keeps the run green
    /// and reports the gap by name, instead of capturing a different market under an old
    /// filename.
    /// - Parameters:
    ///   - element: The element proving the market is on screen.
    ///   - named: The screenshot name, used in the skip message.
    func requireMarket(_ element: XCUIElement, named: String) throws {
        guard element.waitForExistence(timeout: UIWait.load) else {
            throw XCTSkip("SKIPPED-SHOT \(named): the market is not currently live")
        }
    }
}
