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
        UITestKit.shot("07-sign-in", dir: dir)
    }

    /// The App Store screenshot set. Runs the app behind `-uiTestStub` (`AppEnvironment.preview()`
    /// + `UITestFixtures`, same fixtures `SignInComposeScheduleFlowTests` drives) so the store
    /// listing shows the app actually in use — a signed-out sign-in screen on its own reads as an
    /// empty app to a reviewer (Guideline 2.3.3). Fixture literals are hardcoded for the same
    /// reason as in that test: the UITest target can't import the App target's fixtures.
    func testAppStoreScreenshots() {
        app.launchArguments += ["-uiTestStub"]
        app.launch()

        let email = app.textFields["signIn.email"]
        XCTAssertTrue(email.waitForExistence(timeout: 30), "sign-in email field")
        email.tap()
        email.typeText("uitest@cuantolabs.com")
        let password = app.secureTextFields["signIn.password"]
        XCTAssertTrue(password.waitForExistence(timeout: 5), "sign-in password field")
        password.tap()
        password.typeText("uitest-password")
        app.buttons["signIn.submit"].tap()

        let calendarTab = UITestKit.tab(app, "Calendar")
        XCTAssertTrue(calendarTab.waitForExistence(timeout: 20), "Calendar tab after sign-in")
        UITestKit.shot("01-calendar", dir: dir)

        // Composer, with a channel picked so the editor itself renders (ComposerView gates the
        // editor behind "Pick at least one channel").
        let newPost = app.buttons["calendar.newPost"]
        XCTAssertTrue(newPost.waitForExistence(timeout: 10), "Calendar new-post button")
        newPost.tap()
        let channelChip = app.buttons["UITest Channel"]
        XCTAssertTrue(channelChip.waitForExistence(timeout: 10), "composer channel chip")
        channelChip.tap()
        let editor = app.textViews["Global post content"]
        XCTAssertTrue(editor.waitForExistence(timeout: 10), "composer global editor")
        editor.tap()
        editor.typeText("Product launch goes live Thursday — same copy, every channel.")
        UITestKit.shot("02-composer", dir: dir)

        // Schedule sheet on top of the filled composer.
        let addToCalendar = app.buttons["Add to calendar"]
        XCTAssertTrue(addToCalendar.waitForExistence(timeout: 5), "Add to calendar button")
        addToCalendar.tap()
        XCTAssertTrue(app.buttons["Confirm schedule"].waitForExistence(timeout: 10), "schedule sheet")
        UITestKit.shot("03-schedule", dir: dir)
        app.buttons["Confirm schedule"].tap()
        XCTAssertTrue(newPost.waitForExistence(timeout: 15), "back on Calendar after scheduling")

        for (tabName, shotName) in [("Channels", "04-channels"), ("Media", "05-media"),
                                    ("Notifications", "06-notifications")] {
            let tab = UITestKit.tab(app, tabName)
            guard tab.waitForExistence(timeout: 10) else {
                XCTFail("\(tabName) tab missing")
                continue
            }
            // TabView tab-bar buttons can report a {-1,-1} hit point and swallow `.tap()`
            // silently (gotchas #18's sibling failure mode) — tap the element's own centre.
            tab.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            UITestKit.shot(shotName, dir: dir)
        }
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
