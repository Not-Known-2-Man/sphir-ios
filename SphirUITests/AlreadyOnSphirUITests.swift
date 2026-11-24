//
//  AlreadyOnSphirUITests.swift
//  SphirUITests
//
//  End-to-end check against the real API (no UITEST/LOGGED_OUT flags):
//  a throwaway account signs in, clips a link another account already saved,
//  sees "Already on Sphir · 1 person saved it", saves it with one tap, and
//  then deletes itself from Settings.
//
//  Needs throwaway credentials and the link, passed to xcodebuild as
//  TEST_RUNNER_SPHIR_E2E_EMAIL, TEST_RUNNER_SPHIR_E2E_PASSWORD and
//  TEST_RUNNER_SPHIR_E2E_LINK; skipped when they are missing. Screenshots
//  go to /tmp/aos-shots/ and the xcresult.
//

import XCTest

final class AlreadyOnSphirUITests: XCTestCase {

    private var email = ""
    private var password = ""
    private var link = ""

    override func setUpWithError() throws {
        continueAfterFailure = false
        let env = ProcessInfo.processInfo.environment
        guard let email = env["SPHIR_E2E_EMAIL"], let password = env["SPHIR_E2E_PASSWORD"],
              let link = env["SPHIR_E2E_LINK"] else {
            throw XCTSkip("Set TEST_RUNNER_SPHIR_E2E_EMAIL, _PASSWORD and _LINK to run against the real API")
        }
        (self.email, self.password, self.link) = (email, password, link)
    }

    private func shot(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let dir = URL(fileURLWithPath: "/tmp/aos-shots", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: dir.appendingPathComponent("\(name).png"))
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Taps "Not Now" on the system "Save password?" prompt. The prompt is not in the
    /// app's or SpringBoard's element tree, so tap where its left button sits
    /// (centered card, "Not Now" at ~33% width, ~63% height).
    private func dismissSavePasswordPrompt(_ app: XCUIApplication) {
        sleep(2)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.33, dy: 0.626)).tap()
        sleep(1)
    }

    /// Launches the app and lands on the dashboard, signing in when needed.
    @MainActor
    private func launchSignedIn() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()

        let addCard = app.buttons["addCardButton"]
        let emailField = app.textFields["authEmailField"]
        let start = Date()
        while !addCard.exists && !emailField.exists && Date().timeIntervalSince(start) < 15 {
            usleep(250_000)
        }
        if emailField.exists {
            emailField.tap()
            emailField.typeText(email)
            let passwordField = app.secureTextFields["authPasswordField"]
            passwordField.tap()
            passwordField.typeText(password)
            app.buttons["authSubmitButton"].tap()
        }
        let getStarted = app.buttons["getStartedButton"]
        if getStarted.waitForExistence(timeout: 30) {
            // After sign-in iOS shows its own "Save password?" prompt over the app,
            // which swallows taps; dismiss it, then close onboarding.
            for _ in 0..<5 where getStarted.exists {
                if !getStarted.isHittable || getStarted.exists { dismissSavePasswordPrompt(app) }
                if getStarted.isHittable { getStarted.tap() }
                sleep(1)
            }
            if getStarted.exists { shot("0-onboarding-stuck") }
            XCTAssertFalse(getStarted.exists, "onboarding did not dismiss")
        }
        XCTAssertTrue(addCard.waitForExistence(timeout: 30), "dashboard did not appear")
        return app
    }

    @MainActor
    func test1_ClipShowsAlreadyOnSphirAndSavesWithOneTap() throws {
        let app = launchSignedIn()
        app.buttons["addCardButton"].tap()

        let urlField = app.textFields["cardURLField"]
        if !urlField.waitForExistence(timeout: 10) {
            shot("0-no-url-field")
            app.buttons["addCardButton"].tap()
        }
        XCTAssertTrue(urlField.waitForExistence(timeout: 10))
        urlField.tap()
        if !app.keyboards.element.waitForExistence(timeout: 2) { urlField.tap() }
        urlField.typeText(link + "\n")

        // The Label's identifier lands on both its icon and its text, so match the text.
        let notice = app.staticTexts["Already on Sphir · 1 person saved it"]
        XCTAssertTrue(notice.waitForExistence(timeout: 60), "Already on Sphir notice did not appear")
        sleep(2)   // let the cover image load
        shot("1-already-on-sphir")

        let save = app.buttons["saveCardButton"]
        XCTAssertTrue(save.isEnabled, "save is disabled")
        save.tap()
        XCTAssertTrue(app.staticTexts["Card Saved!"].waitForExistence(timeout: 30))
        shot("2-card-saved")
    }

    @MainActor
    func test2_DeleteAccountReturnsToSignIn() throws {
        let app = launchSignedIn()
        app.buttons["settingsButton"].tap()

        let delete = app.buttons["deleteAccountButton"]
        if !delete.waitForExistence(timeout: 5) || !delete.isHittable { app.swipeUp() }
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()

        let passwordField = app.secureTextFields["deleteAccountPasswordField"]
        XCTAssertTrue(passwordField.waitForExistence(timeout: 10))
        passwordField.tap()
        passwordField.typeText(password)
        shot("3-delete-account")
        app.buttons["confirmDeleteAccountButton"].tap()

        XCTAssertTrue(app.textFields["authEmailField"].waitForExistence(timeout: 30),
                      "sign-in screen did not appear after deleting the account")
        shot("4-after-delete")
    }
}
