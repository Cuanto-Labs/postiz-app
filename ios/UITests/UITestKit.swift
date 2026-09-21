import XCTest

/// Shared XCUITest helpers, extracted verbatim from ShulMaker's and Zmanym's UITests
/// (see _harvest/*/KNOWLEDGE.md) so every suite app's UITests just import the flow-specific
/// string literals, not re-derive these patterns.
enum UITestKit {
    /// iPhone renders SwiftUI TabView as a bottom UITabBar (`app.tabBars.buttons[name]`);
    /// iPadOS 17+ renders it as a top tab strip whose items are NOT tabBars elements —
    /// they're plain `app.buttons[name]`. Try tabBars first, fall back to buttons.
    static func tab(_ app: XCUIApplication, _ name: String) -> XCUIElement {
        let bar = app.tabBars.buttons[name]
        return bar.exists ? bar : app.buttons[name].firstMatch
    }

    /// Taps a tab-bar item and waits for it to actually become selected. A bare `.tap()` is not
    /// reliable on this app's tab bar: it intermittently reports a `{-1, -1}` hit point (the same
    /// trap `ScreenshotUITests` sidesteps by relaunching with `-uiTestTab`), and XCUITest then
    /// taps nothing at all and the test fails looking for the next screen's content. Falls back
    /// to a normalized-coordinate tap on the item's own frame, retrying a few times.
    @discardableResult
    static func tapTab(_ app: XCUIApplication, _ name: String, timeout: TimeInterval = 10) -> Bool {
        let item = tab(app, name)
        guard item.waitForExistence(timeout: timeout) else { return false }
        for attempt in 0..<3 {
            if attempt == 0, item.isHittable {
                item.tap()
            } else {
                item.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            let deadline = Date().addingTimeInterval(3)
            while Date() < deadline {
                if item.isSelected { return true }
                usleep(200_000)
            }
        }
        return item.isSelected
    }

    /// Back via the nav-bar leading button, falling back to a swipe-right if it's missing.
    static func back(_ app: XCUIApplication) {
        let b = app.navigationBars.firstMatch.buttons.element(boundBy: 0)
        if b.waitForExistence(timeout: 5) { b.tap() } else { app.swipeRight() }
        sleep(1)
    }

    /// Human-paced wait, in seconds (fractional OK) — used instead of bot-fast taps in any
    /// recording a human/App-Review reviewer will watch.
    static func pause(_ seconds: Double) { usleep(UInt32(seconds * 1_000_000)) }

    /// Writes a numbered PNG to `dir`. Default dir comes from SHOT_DIR / TEST_RUNNER_SHOT_DIR
    /// (xcodebuild test only forwards TEST_RUNNER_-prefixed vars to the runner and strips the
    /// prefix before the test binary sees it — hence the double lookup pattern below).
    static func shotDir(default def: String) -> String {
        let env = ProcessInfo.processInfo.environment
        return env["SHOT_DIR"] ?? env["TEST_RUNNER_SHOT_DIR"] ?? def
    }

    static func shot(_ name: String, dir: String) {
        sleep(2)
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
    }

    /// Double-lookup for an env var that may arrive unprefixed (simctl launch) or
    /// TEST_RUNNER_-prefixed (xcodebuild test, prefix stripped by the runner).
    static func env(_ name: String) -> String {
        let e = ProcessInfo.processInfo.environment
        return e[name] ?? e["TEST_RUNNER_\(name)"] ?? ""
    }

    /// Layout-regression assertion for `bin/ios-layout-check` (docs/13-device-matrix.md).
    /// Catches two real, mechanically-detectable failure modes:
    ///   1. the element's frame extends past the window bounds (content clipped by the
    ///      safe area / screen edge — happens at large Dynamic Type sizes or on the
    ///      smallest device in the matrix).
    ///   2. the element exists but isn't hittable (zero-size frame, off Y=0/X=0, or hidden
    ///      behind something else) — the same `isHittable` trap as gotcha #17.
    /// This is a frame/geometry check, NOT text-truncation detection — XCUITest exposes no
    /// "is this Text view showing an ellipsis" API. A `UILabel`/SwiftUI `Text` that Auto
    /// Layout/`.lineLimit` truncates internally still reports a frame inside bounds and
    /// `isHittable == true`; catching *that* needs the companion PNG-edge heuristic in
    /// `bin/ios-layout-check` (`lib/layout_check.py`) or a human glance at the captured shot.
    static func assertNotClipped(_ app: XCUIApplication, label: XCUIElement, name: String, file: StaticString = #filePath, line: UInt = #line) {
        guard label.waitForExistence(timeout: 10) else {
            XCTFail("\(name): element never appeared", file: file, line: line)
            return
        }
        let winFrame = app.windows.firstMatch.frame
        let elFrame = label.frame
        if elFrame.width <= 0 || elFrame.height <= 0 {
            XCTFail("\(name): zero-size frame (\(elFrame)) — likely collapsed/hidden", file: file, line: line)
            return
        }
        if !winFrame.contains(elFrame) {
            XCTFail("\(name): frame \(elFrame) extends beyond window bounds \(winFrame) — likely clipped by safe area/screen edge", file: file, line: line)
        }
        if !label.isHittable {
            XCTFail("\(name): exists but not hittable — overlapped or off-screen", file: file, line: line)
        }
    }

    /// Launches via a SpringBoard icon tap (not `app.launch()`) so a device-demo recording
    /// shows a genuine cold launch from the home screen, matching what a human reviewer does.
    /// `icon.exists` can be true with a zero-size frame if the icon sits on a SpringBoard page
    /// that isn't currently visible — check `isHittable`, not `exists`.
    static func launchFromHomeScreen(_ app: XCUIApplication, iconName: String) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCUIDevice.shared.press(.home)
        pause(1.5)
        let icon = springboard.icons[iconName].firstMatch
        var hittable = false
        for _ in 0..<4 {
            if icon.waitForExistence(timeout: 3), icon.isHittable { hittable = true; break }
            pause(1.0)
        }
        if hittable {
            icon.tap()
            app.activate() // attaches to the already-running process instead of relaunching
        } else {
            app.launch()
        }
        pause(0.8)
    }
}
