//
//  DemoRecordingUITests.swift
//  SphirUITests
//
//  Paced walkthrough of the real app against the Render pilot API, meant to
//  be screen-recorded. Skipped unless DEMO_EMAIL and DEMO_PASSWORD are set
//  (pass them as TEST_RUNNER_DEMO_EMAIL / TEST_RUNNER_DEMO_PASSWORD to
//  xcodebuild). It writes real data (and with DEMO_SIGNUP=1 creates a real
//  account), so it never runs by default. Start from a logged-out app.
//

import XCTest

final class DemoRecordingUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func pause(_ seconds: Double = 1.5) {
        Thread.sleep(forTimeInterval: seconds)
    }

    private func tap(_ element: XCUIElement, timeout: TimeInterval = 15) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Missing \(element)")
        element.tap()
    }

    private func type(_ text: String, into field: XCUIElement) {
        XCTAssertTrue(field.waitForExistence(timeout: 15), "Missing field \(field)")
        for _ in 0..<4 {
            field.tap()
            Thread.sleep(forTimeInterval: 0.6)
            if (field.value(forKey: "hasKeyboardFocus") as? Bool) == true { break }
        }
        field.typeText(text)
    }

    /// Replace a text field's contents: put the cursor at the end, then delete.
    private func replaceText(in field: XCUIElement, with text: String) {
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        _ = app.keyboards.element.waitForExistence(timeout: 3)
        // Select everything (Cmd+A), then type over it.
        field.typeKey("a", modifierFlags: .command)
        Thread.sleep(forTimeInterval: 0.5)
        field.typeText(text.isEmpty ? XCUIKeyboardKey.delete.rawValue : text)
    }

    private func closeModal() {
        tap(app.buttons.matching(NSPredicate(format: "label == %@", "Close")).firstMatch)
    }

    private func waitHittable(_ element: XCUIElement, timeout: TimeInterval = 15) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists && element.isHittable { return }
            Thread.sleep(forTimeInterval: 0.5)
        }
        print("DEMO_TREE\n\(app.debugDescription)")
        XCTFail("Not hittable: \(element)")
    }

    private func createCollection(_ name: String) {
        waitHittable(app.buttons["addCollectionButton"])
        tap(app.buttons["addCollectionButton"])
        pause(1)
        type(name, into: app.textFields["collectionTitleField"])
        pause(1)
        tap(app.buttons["collectionContinueButton"])
        XCTAssertTrue(app.staticTexts["Collection Created!"].waitForExistence(timeout: 20))
        pause(2.5)
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 20))
        pause()
    }

    private func addURLCard(_ url: String, expectedTitle: String) {
        waitHittable(app.buttons["addCardButton"])
        tap(app.buttons["addCardButton"])
        pause(1.5)
        tap(app.buttons["cardType_text"])
        pause(1.5)
        tap(app.buttons["cardSource_url"])
        pause(1)
        type(url + "\n", into: app.textFields["cardURLField"])

        // Wait for the link preview to fill in the title.
        let title = app.textFields["cardTitleField"]
        expectation(for: NSPredicate(format: "value CONTAINS %@", expectedTitle), evaluatedWith: title)
        waitForExpectations(timeout: 30)
        pause(2.5)

        tap(app.buttons["navDoneButton"])
        XCTAssertTrue(app.staticTexts["Card Saved!"].waitForExistence(timeout: 20))
        pause(2)
        let back = app.buttons["backToDashboardButton"]
        if back.exists { back.tap() }
        XCTAssertTrue(app.staticTexts["Card Saved!"].waitForNonExistence(timeout: 15))
        pause()
    }

    @MainActor
    func testRecordFullAppDemo() throws {
        let env = ProcessInfo.processInfo.environment
        guard let email = env["DEMO_EMAIL"], let password = env["DEMO_PASSWORD"],
              !email.isEmpty, !password.isEmpty else {
            throw XCTSkip("Demo recording only runs with DEMO_EMAIL and DEMO_PASSWORD set.")
        }

        app = XCUIApplication()
        // English UI and English link previews, whatever the simulator locale.
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        // Splash → sign in (or sign up with DEMO_SIGNUP=1).
        if env["DEMO_SIGNUP"] == "1" {
            tap(app.buttons["authToggleButton"], timeout: 20)
            pause()
            type("Demo", into: app.textFields["authNameField"])
        } else {
            XCTAssertTrue(app.textFields["authEmailField"].waitForExistence(timeout: 20))
            pause(2)
        }
        type(email, into: app.textFields["authEmailField"])
        type(password, into: app.secureTextFields["authPasswordField"])
        pause(1)
        tap(app.buttons["authSubmitButton"])

        // Onboarding → dashboard: a single tap must be enough.
        let welcome = app.staticTexts["Welcome to Sphir"]
        XCTAssertTrue(welcome.waitForExistence(timeout: 30))

        // iOS offers to save the password after a login; answer like a user.
        // While that system sheet is up it takes every tap.
        let notNow = app.buttons.matching(
            NSPredicate(format: "label IN %@", ["Not Now", "Ahora no"])
        ).firstMatch
        if notNow.waitForExistence(timeout: 8) {
            pause(1.5)
            notNow.tap()
        }
        pause(3)
        tap(app.buttons["getStartedButton"])
        if !welcome.waitForNonExistence(timeout: 8) { print("DEMO_TREE\n\(app.debugDescription)") }
        XCTAssertFalse(welcome.exists, "Onboarding should close after one tap")
        XCTAssertTrue(app.buttons["addCardButton"].waitForExistence(timeout: 20))
        pause(2.5)

        // Create Sphirs (collections) — the first tap after login must work.
        createCollection("Tech Inspiration")
        createCollection("Weekend Plans")

        // Save cards straight from links; the preview fills in title and image.
        addURLCard("https://www.apple.com", expectedTitle: "Apple")
        addURLCard("https://github.com", expectedTitle: "GitHub")

        // Open the Sphir and a card.
        let sphir = app.staticTexts["Tech Inspiration"].firstMatch
        waitHittable(sphir)
        sphir.tap()
        pause(2.5)

        tap(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Apple")).firstMatch)
        pause(3)

        // Read the page inside the app.
        tap(app.buttons["openInReaderButton"])
        pause(5)
        tap(app.buttons["readerBackButton"])
        pause(1.5)
        tap(app.buttons["cardDetailBackButton"])
        pause(1.5)

        // Rename a card from its context menu.
        let githubRow = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "GitHub")).firstMatch
        XCTAssertTrue(githubRow.waitForExistence(timeout: 15))
        githubRow.press(forDuration: 1.0)
        pause(1.5)
        tap(app.buttons.matching(NSPredicate(format: "label == %@", "Edit")).firstMatch)
        pause(1)
        replaceText(in: app.textFields["editTitleField"], with: "GitHub - code ideas")
        pause(1)
        tap(app.buttons["editSaveButton"])
        XCTAssertTrue(app.staticTexts["GitHub - code ideas"].waitForExistence(timeout: 20))
        pause(2.5)

        tap(app.buttons["collectionDetailBackButton"])
        pause(2)

        // Search across Sphirs and cards.
        type("Apple", into: app.textFields["searchField"])
        pause(3)
        replaceText(in: app.textFields["searchField"], with: "")
        app.typeText("\n")
        pause(1.5)

        // Notifications and settings.
        tap(app.buttons["notificationsButton"])
        pause(2.5)
        closeModal()
        pause(1)
        tap(app.buttons["settingsButton"])
        pause(3)
        closeModal()
        pause(3)
    }
}
