import XCTest

/// THROWAWAY — real-backend end-to-end smoke test for this session's manual E2E verification.
/// Drives the actual app UI (no `-uiTestStub`) against a real local backend at
/// `http://localhost:3800` (see Project.yml Debug.API_BASE_URL, temporarily overridden for this
/// run). Not part of the permanent suite — `trash` this file when done.
final class E2ERealBackendUITests: XCTestCase {
    var app: XCUIApplication!
    let dir = "/tmp/socials-sim-real"

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    }

    /// `XCUIElement.tap()` on this app's `TabView` tab-bar buttons resolves via "scroll to
    /// visible" hit-point computation, which reliably returns `{-1, -1}` for these buttons and
    /// silently no-ops (no thrown error, tab stays put) — confirmed via xcresult accessibility
    /// snapshots showing the Calendar tab still selected after tapping "Notifications"/"More".
    /// Tapping a coordinate derived directly from the element's own frame bypasses that broken
    /// hit-point path.
    func tapTabBarButton(_ element: XCUIElement) {
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    func shot(_ name: String) {
        let shot = app.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.lifetime = .keepAlways
        add(attachment)
        try? shot.pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
    }

    func testFullFlow() {
        // iOS Simulator shows a system "Save Password?" sheet (separate process) right after
        // credentials are submitted. Interruption monitors only fire when the app is poked
        // (tap/query) after the alert appears, so every wait below is a small polling loop.
        addUIInterruptionMonitor(withDescription: "Save Password") { alert in
            let notNow = alert.buttons["Not Now"]
            if notNow.exists {
                notNow.tap()
                return true
            }
            return false
        }

        app.launch()

        // 1. Sign in
        let emailField = app.textFields["signIn.email"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 30), "sign-in screen")
        emailField.tap()
        emailField.typeText("e2e-user1-1789649058@example.com")

        let passwordField = app.secureTextFields["signIn.password"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 5))
        passwordField.tap()
        passwordField.typeText("TestPass!2345")

        shot("01-sign-in-filled")

        app.buttons["signIn.submit"].tap()
        app.tap() // poke the app so the interruption monitor gets a chance to dismiss Save Password

        // 1b. First-launch onboarding carousel (OnboardingView): welcome -> schedule ->
        // analytics -> pick-a-channel, then "Get started". Only shown once per fresh session.
        let welcomeTitle = app.staticTexts["Welcome to Postiz"]
        if welcomeTitle.waitForExistence(timeout: 15) {
            shot("01b-onboarding-welcome")
            let firstChannelHeader = app.staticTexts["Connect your first channel"]
            var attempts = 0
            while !firstChannelHeader.exists && attempts < 6 {
                let next = app.buttons["Next"]
                XCTAssertTrue(next.waitForExistence(timeout: 10))
                // Panel switch is animated; tapping mid-transition resolves a {-1,-1} hit point
                // and silently no-ops (no thrown error, no panel advance) — retry until the
                // "Connect your first channel" panel is actually showing instead of counting taps.
                Thread.sleep(forTimeInterval: 0.6)
                next.tap()
                attempts += 1
            }
            XCTAssertTrue(firstChannelHeader.waitForExistence(timeout: 10), "reached pick-a-channel panel")

            let firstProvider = app.buttons.matching(
                NSPredicate(format: "label BEGINSWITH 'Select '")
            ).firstMatch
            XCTAssertTrue(firstProvider.waitForExistence(timeout: 15), "onboarding provider list")
            shot("01c-onboarding-providers")

            let getStarted = app.buttons["Get started"]
            XCTAssertTrue(getStarted.waitForExistence(timeout: 5))
            // The provider button's AX frame is briefly reported off-screen (negative y) right as
            // the .firstChannel panel finishes its transition-in — a coordinate tap computed from
            // that stale frame lands off-screen and silently fails to select (Get started stays
            // disabled, no thrown error). Retry the tap, re-reading isEnabled each time, instead of
            // trusting a single tap.
            var selectAttempts = 0
            while !getStarted.isEnabled && selectAttempts < 5 {
                Thread.sleep(forTimeInterval: 0.6)
                // Provider list is now in a real ScrollView (app fix), so plain .tap() can use
                // AX's scroll-to-visible correctly.
                firstProvider.tap()
                selectAttempts += 1
            }
            XCTAssertTrue(getStarted.isEnabled, "get started enabled once provider selected")
            getStarted.tap()
        }

        // 2. Calendar (default landing tab post sign-in)
        let calendarTitle = app.navigationBars["Calendar"]
        XCTAssertTrue(calendarTitle.waitForExistence(timeout: 30), "calendar screen after sign-in")
        shot("02-calendar")

        // 3. Composer: create draft
        app.buttons["calendar.newPost"].tap()

        // ComposerView only renders the "Post content" editor once a channel is selected
        // (see ComposerView.content(for:)'s `if !selectedChannels.isEmpty` branch) — the
        // picker chip must be tapped first.
        let channelChip = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'E2E Test Channel'")
        ).firstMatch
        XCTAssertTrue(channelChip.waitForExistence(timeout: 10), "seeded E2E channel chip")
        channelChip.tap()

        // ComposerEditorPane's accessibilityLabel is "Global post content" on the default
        // .global tab (ComposerView.tabContent), not "Post content".
        let postContent = app.textViews["Global post content"]
        XCTAssertTrue(postContent.waitForExistence(timeout: 10), "composer sheet")

        postContent.tap()
        postContent.typeText("E2E real-backend smoke test draft")
        shot("03-composer-filled")

        let saveDraft = app.buttons["Save draft"]
        XCTAssertTrue(saveDraft.waitForExistence(timeout: 5))
        XCTAssertTrue(saveDraft.isEnabled, "save draft should be enabled once channel+content set")
        saveDraft.tap()

        XCTAssertTrue(postContent.waitForNonExistence(timeout: 15), "composer dismissed after draft save")

        XCTAssertTrue(calendarTitle.waitForExistence(timeout: 15), "back on calendar after draft save")
        shot("04-calendar-after-draft")

        // 4. Notifications tab
        let notificationsTab = app.tabBars.buttons["Notifications"]
        let notificationsNavBar = app.navigationBars["Notifications"]
        var notificationsAttempts = 0
        while !notificationsNavBar.exists && notificationsAttempts < 4 {
            tapTabBarButton(notificationsTab)
            notificationsAttempts += 1
            _ = notificationsNavBar.waitForExistence(timeout: 3)
        }
        XCTAssertTrue(notificationsNavBar.waitForExistence(timeout: 10), "Notifications screen")
        shot("05-notifications")

        // 5. More -> Settings -> Account details
        // MainTabView's "More" tab is a List of NavigationLink rows (commit 5eddf43e) —
        // NavigationLink row labels are exposed to AX as buttons, not static text.
        let moreTab = app.tabBars.buttons["More"]
        let settingsLink = app.buttons["Settings"]
        // Tapping straight after the Notifications tab occasionally lands on a stale tab-bar
        // hit point ({-1,-1}) while the previous tab's transition is still settling — retry
        // the tap instead of trusting it landed once.
        var moreAttempts = 0
        while !settingsLink.exists && moreAttempts < 4 {
            tapTabBarButton(moreTab)
            moreAttempts += 1
            _ = settingsLink.waitForExistence(timeout: 3)
        }
        XCTAssertTrue(settingsLink.waitForExistence(timeout: 10), "More screen")
        shot("06-more")

        settingsLink.tap()
        // SettingsView's rows are also NavigationLinks — a button, not a staticText.
        let accountDetails = app.buttons["Account details"]
        XCTAssertTrue(accountDetails.waitForExistence(timeout: 10), "Settings screen")
        shot("07-settings")

        accountDetails.tap()
        XCTAssertTrue(app.navigationBars.element.waitForExistence(timeout: 10), "Account details screen")
        shot("08-account-details")
    }
}
