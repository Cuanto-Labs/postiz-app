import XCTest

/// End-to-end happy path against `StubSocialsAPI` (via the `-uiTestStub` launch argument, see
/// `AppEnvironment.preview()` + `App/Testing/UITestFixtures.swift`): sign in with email, see the
/// one seeded connected channel, open the composer from Calendar's "+" button, type content, pick
/// the channel, schedule it, and land back on Calendar with no error surfaced. The fixture values
/// below (`"uitest@cuantolabs.com"` / `"uitest-password"` / `"UITest Channel"`) are hardcoded
/// rather than imported — this test target runs in a separate process from the App target that
/// owns `UITestFixtures`, so they're kept in sync by hand.
final class SignInComposeScheduleFlowTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-uiTestStub"]
    }

    func testSignInComposeScheduleFlow() {
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

        // Signed in, onboarding already marked seen by the fixture — lands on MainTabView.
        let calendarTab = UITestKit.tab(app, "Calendar")
        XCTAssertTrue(calendarTab.waitForExistence(timeout: 10), "Calendar tab after sign-in")

        // See the seeded connected channel on the Channels tab.
        UITestKit.tapTab(app, "Channels")
        let channelRow = app.descendants(matching: .any)["UITest Channel"]
        XCTAssertTrue(channelRow.waitForExistence(timeout: 10), "seeded channel visible")

        // Back to Calendar, open the composer.
        UITestKit.tapTab(app, "Calendar")
        let newPost = app.buttons["calendar.newPost"]
        XCTAssertTrue(newPost.waitForExistence(timeout: 10), "Calendar new-post button")
        newPost.tap()

        // The editor only renders once at least one channel is selected — pick the channel
        // chip first (see `ComposerView.content(for:)`'s "Pick at least one channel" gate).
        let channelChip = app.buttons["UITest Channel"]
        XCTAssertTrue(channelChip.waitForExistence(timeout: 10), "composer channel chip")
        channelChip.tap()

        let editor = app.textViews["Global post content"]
        XCTAssertTrue(editor.waitForExistence(timeout: 10), "composer global editor")
        editor.tap()
        editor.typeText("Scheduled from SignInComposeScheduleFlowTests")

        let addToCalendar = app.buttons["Add to calendar"]
        XCTAssertTrue(addToCalendar.waitForExistence(timeout: 5), "Add to calendar button")
        addToCalendar.tap()

        let confirmSchedule = app.buttons["Confirm schedule"]
        XCTAssertTrue(confirmSchedule.waitForExistence(timeout: 10), "Confirm schedule button")
        confirmSchedule.tap()

        // Composer + schedule sheet both dismiss on success — back on Calendar with its "+"
        // button visible again and no "Post error" surfaced.
        XCTAssertTrue(newPost.waitForExistence(timeout: 10), "back on Calendar after scheduling")
        XCTAssertFalse(app.staticTexts["Post error"].exists, "no post error after scheduling")
    }
}
