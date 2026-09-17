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

    override func tearDown() {
        app.terminate()
        super.tearDown()
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
        XCTAssertTrue(
            app.staticTexts["Studio day. Three shoots, one calendar."].waitForExistence(timeout: 15),
            "seeded week on Calendar")
        UITestKit.shot("01-calendar", dir: dir)

        relaunch(tab: "channels", expectedNavBar: "Channels")
        XCTAssertTrue(app.descendants(matching: .any)["@cuantolabs"].waitForExistence(timeout: 15),
                      "seeded channel on Channels tab")
        UITestKit.shot("02-channels", dir: dir)

        relaunch(tab: "calendar", expectedNavBar: "Calendar")
        let newPost = app.buttons["calendar.newPost"]
        XCTAssertTrue(newPost.waitForExistence(timeout: 15), "Calendar new-post button")
        newPost.tap()

        let channelChip = app.buttons["@cuantolabs"]
        XCTAssertTrue(channelChip.waitForExistence(timeout: 20), "composer channel chip")
        channelChip.tap()
        let editor = app.textViews["Global post content"]
        XCTAssertTrue(editor.waitForExistence(timeout: 15), "composer global editor")
        editor.tap()
        editor.typeText("Product launch goes live Thursday — same copy, every channel.")
        UITestKit.shot("03-composer", dir: dir)

        let addToCalendar = app.buttons["Add to calendar"]
        XCTAssertTrue(addToCalendar.waitForExistence(timeout: 10), "Add to calendar button")
        addToCalendar.tap()
        XCTAssertTrue(app.buttons["Confirm schedule"].waitForExistence(timeout: 15), "schedule sheet")
        UITestKit.shot("04-schedule", dir: dir)
        app.buttons["Confirm schedule"].tap()
        XCTAssertTrue(newPost.waitForExistence(timeout: 20), "back on Calendar after scheduling")

        // MediaLibraryView sets its own `.navigationTitle("Media Library")`, which wins over
        // MainTabView's outer "Media" on the same NavigationStack.
        relaunch(tab: "media", expectedNavBar: "Media Library")
        // Wait for seeded content, not just the nav bar: the list loads a beat after the screen
        // appears, and shooting on the nav bar alone caught the "No media yet." empty state.
        XCTAssertTrue(
            app.descendants(matching: .any)["Media: launch-week-1080.png"].waitForExistence(timeout: 15),
            "seeded media library item")
        UITestKit.shot("05-media", dir: dir)

        relaunch(tab: "notifications", expectedNavBar: "Notifications")
        // `NotificationRow` labels its content element "<read state>: <content>", so match the
        // prefix rather than the bare fixture string.
        let seededNotification = app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "Your Instagram post published")
        ).firstMatch
        XCTAssertTrue(seededNotification.waitForExistence(timeout: 15), "seeded notification")
        UITestKit.shot("06-notifications", dir: dir)

        // Hero composer shot: Instagram + LinkedIn selected, one valid 1:1 image already
        // attached — exercises the multi-channel picker, the media tray, and both providers'
        // `ChannelPreviewCard`s with real state instead of an empty composer.
        relaunch(tab: "calendar", expectedNavBar: "Calendar", media: "valid")
        app.buttons["calendar.newPost"].tap()
        // "Cuanto Labs" mirrors `UITestFixtures.instagramChannelName` — hardcoded for the same
        // reason as the other fixture literals in this file (the UITest target can't import the
        // App target's fixtures).
        XCTAssertTrue(app.buttons["Cuanto Labs, selected"].waitForExistence(timeout: 20),
                      "composer hero: Instagram chip selected")
        UITestKit.shot("08-composer-media", dir: dir)

        // Same seed, a 16:9 image instead — trips Instagram's aspect-ratio rule, so the tray
        // shows the inline violation blocking the post.
        relaunch(tab: "calendar", expectedNavBar: "Calendar", media: "violation")
        app.buttons["calendar.newPost"].tap()
        XCTAssertTrue(app.buttons["Cuanto Labs, selected"].waitForExistence(timeout: 20),
                      "composer violation: Instagram chip selected")
        XCTAssertTrue(
            app.staticTexts["Instagram needs a 1:1, 4:5 or 1.91:1 crop — this is 16:9."]
                .waitForExistence(timeout: 15), "Instagram aspect-ratio violation text")
        UITestKit.shot("09-composer-violation", dir: dir)
    }

    /// Fully relaunches the app into `tab` via `-uiTestTab` instead of tapping the tab bar:
    /// `TabView`'s tab-bar buttons report a `{-1,-1}` hit point on this app, so both `.tap()` and
    /// the element's own coordinate are silently swallowed. `-uiTestTab` also signs the stub
    /// session in directly (see `AppEnvironment.preview()`), so the relaunch lands straight on
    /// `expectedNavBar` without re-driving the sign-in form. Asserts the destination nav bar so a
    /// wrong frame fails the test instead of silently saving the wrong screen.
    private func relaunch(tab: String, expectedNavBar: String, media: String? = nil) {
        app.terminate()
        app = XCUIApplication()
        var args = ["-uiTestStub", "-uiTestTab", tab]
        if let media {
            args += ["-uiTestMedia", media]
        }
        app.launchArguments = args
        app.launch()
        XCTAssertTrue(app.navigationBars[expectedNavBar].waitForExistence(timeout: 20),
                      "\(expectedNavBar) did not become the active tab")
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
        // Only ios-layout-check (which always sets these) wants this frame; otherwise it would
        // drop a second sign-in PNG into the App Store screenshot set.
        if !orientationRaw.isEmpty || !textSize.isEmpty {
            UITestKit.shot("01-sign-in", dir: dir)
        }
    }
}
