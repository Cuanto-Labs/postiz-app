import XCTest

/// Walks the app's launch screen and dumps numbered PNGs for visual QA. `CuantoSocials` has no
/// persisted session on a fresh simulator, so cold launch always lands on `SignInView` (see
/// `App/Features/Auth/SignInView.swift`) — that screen's "Sign in" title is the stable anchor
/// `testWalkthrough`/`testLayoutCheck` wait for, in place of the generic `{{APP_NAME}}` launch
/// text ios-suite's starter template expects. Feature screens behind auth (Notifications, AI,
/// Analytics, Settings) aren't reachable from this unauthenticated harness — those get their
/// Dynamic Type fixes from direct source review (`ViewThatFits`/`minimumScaleFactor`/scrollable
/// `List`s) rather than an automated screenshot per docs/15-design.md's guidance that source-level
/// fixes and the render matrix are complementary, not the same check.
///
/// `testLayoutCheck` is the same walkthrough driven by `bin/ios-layout-check` across device /
/// orientation / Dynamic Type variants (see `docs/13-device-matrix.md`). It reads
/// `LAYOUT_ORIENTATION` (`portrait` | `landscapeLeft`) and `LAYOUT_TEXT_SIZE` (a
/// `UIContentSizeCategory` raw value, e.g. `UICTContentSizeCategoryAccessibilityXXXL`) via the
/// double-lookup env pattern (`UITestKit.env`, `docs/03-testing.md`), applies them before
/// launch, then walks the same screen as `testWalkthrough` with layout assertions added.
final class ScreenshotUITests: XCTestCase {
    var app: XCUIApplication!
    let dir = UITestKit.shotDir(default: "/tmp/SOCIALS-shots")

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    }

    func testWalkthrough() {
        app.launch()
        XCTAssertTrue(app.staticTexts["Sign in"].firstMatch.waitForExistence(timeout: 30), "launch screen")
        UITestKit.shot("01-sign-in", dir: dir)
    }

    /// Driven by `bin/ios-layout-check`. Not part of the App Store screenshot set — writes into
    /// whatever `dir` the caller points `SHOT_DIR`/`TEST_RUNNER_SHOT_DIR` at (ios-layout-check
    /// uses `./build/layout/<device>-<variant>/`).
    func testLayoutCheck() {
        let orientationRaw = UITestKit.env("LAYOUT_ORIENTATION")
        let textSize = UITestKit.env("LAYOUT_TEXT_SIZE")

        if !textSize.isEmpty {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", textSize]
        }

        switch orientationRaw {
        case "landscapeLeft":
            XCUIDevice.shared.orientation = .landscapeLeft
        case "landscapeRight":
            XCUIDevice.shared.orientation = .landscapeRight
        default:
            XCUIDevice.shared.orientation = .portrait
        }

        app.launch()
        let title = app.staticTexts["Sign in"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 30), "launch screen (layout check)")
        UITestKit.assertNotClipped(app, label: title, name: "sign-in title")
        UITestKit.shot("01-sign-in", dir: dir)
    }
}
