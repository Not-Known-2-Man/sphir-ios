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

    /// Marks where a demo chapter starts so post-production can caption it.
    private func section(_ title: String) {
        print("DEMO_SECTION|\(Date().timeIntervalSince1970)|\(title)")
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
        type(url + "\n", into: app.textFields["cardURLField"])

        // Wait for the preview card to fill in the title.
        let title = app.descendants(matching: .any)["clipTitleField"]
        expectation(for: NSPredicate(format: "value CONTAINS %@", expectedTitle), evaluatedWith: title)
        waitForExpectations(timeout: 30)
        pause(2.5)

        tap(app.buttons["saveCardButton"])
        XCTAssertTrue(app.staticTexts["Card Saved!"].waitForExistence(timeout: 20))
        pause(2)
        tap(app.buttons["Done"])
        XCTAssertTrue(app.staticTexts["Card Saved!"].waitForNonExistence(timeout: 15))
        pause()
    }

    /// Drag between two points given as fractions of the screen.
    private func drag(_ target: XCUIApplication, from: CGVector, to: CGVector) {
        let start = target.coordinate(withNormalizedOffset: from)
        start.press(forDuration: 0.4, thenDragTo: target.coordinate(withNormalizedOffset: to),
                    withVelocity: 250, thenHoldForDuration: 0.3)
    }

    /// Screenshot + crop tool inside the app: pick a screenshot, select only
    /// the paragraph that matters, and let OCR turn it into a card.
    private func addCroppedScreenshotCard(title: String) {
        waitHittable(app.buttons["addCardButton"])
        tap(app.buttons["addCardButton"])
        pause(1.5)
        tap(app.buttons["addCardPhotoButton"])
        pause(4)

        // The photo picker runs out of process: tap the newest photo (the
        // sample screenshot added with `simctl addmedia`) by position. Retry
        // in case the picker was still settling.
        let extract = app.buttons["extractThisButton"]
        for _ in 0..<4 where !extract.exists {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.163, dy: 0.425)).tap()
            _ = extract.waitForExistence(timeout: 6)
        }
        XCTAssertTrue(extract.waitForExistence(timeout: 10))
        pause(2)

        // Shrink the selection to the article's first paragraph.
        drag(app, from: CGVector(dx: 0.233, dy: 0.26), to: CGVector(dx: 0.06, dy: 0.44))
        pause(1)
        drag(app, from: CGVector(dx: 0.764, dy: 0.789), to: CGVector(dx: 0.93, dy: 0.67))
        pause(2)
        tap(app.buttons["extractThisButton"])

        // OCR fills the title and the extracted text.
        let titleField = app.textFields["Card title"]
        expectation(for: NSPredicate(format: "value != %@ AND value.length > 0", "Card title"), evaluatedWith: titleField)
        waitForExpectations(timeout: 20)
        pause(3)
        replaceText(in: titleField, with: title)
        app.typeText("\n")
        pause(2)

        tap(app.buttons.matching(NSPredicate(format: "label == %@", "Save")).firstMatch)
        XCTAssertTrue(app.staticTexts["Card Saved!"].waitForExistence(timeout: 20))
        pause(2)
        // The success screen returns to the dashboard by itself after 3 s.
        XCTAssertTrue(app.staticTexts["Card Saved!"].waitForNonExistence(timeout: 15))
        pause()
    }

    /// Share sheet + crop tool from Safari: snip one part of a web page into
    /// Sphir without opening the app, then come back to find it saved.
    /// Share a screenshot from Photos, crop a region and let OCR read it.
    private func snipFromPhotos() {
        let photos = XCUIApplication(bundleIdentifier: "com.apple.mobileslideshow")
        photos.terminate()
        photos.launch()
        pause(4)
        // The Wikipedia screenshot is the last item in the library grid.
        photos.coordinate(withNormalizedOffset: CGVector(dx: 0.165, dy: 0.54)).tap()
        pause(3)
        let share = photos.buttons.matching(NSPredicate(format: "label == %@", "Share")).firstMatch
        // The viewer may open with its toolbar hidden; a tap toggles it.
        for _ in 0..<3 where !share.waitForExistence(timeout: 3) {
            photos.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            pause(1)
        }
        tap(share)
        pause(2)
        let sphir = photos.cells["Sphir"].exists ? photos.cells["Sphir"] : photos.buttons["Sphir"]
        tap(sphir)
        pause(3)

        tap(photos.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Select area")).firstMatch)
        let snip = photos.buttons.matching(NSPredicate(format: "label == %@", "Snip it")).firstMatch
        XCTAssertTrue(snip.waitForExistence(timeout: 15))
        pause(3)
        // Widen the box (x 0.152-0.85, y 0.407-0.636) over the whole paragraph.
        drag(photos, from: CGVector(dx: 0.152, dy: 0.407), to: CGVector(dx: 0.02, dy: 0.425))
        pause(1)
        drag(photos, from: CGVector(dx: 0.85, dy: 0.636), to: CGVector(dx: 0.98, dy: 0.65))
        pause(2)
        tap(snip)

        // On-device OCR fills title and description from the cropped region.
        let save = photos.buttons.matching(NSPredicate(format: "label == %@", "Save and send to Sphir")).firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 20))
        pause(6)
        save.tap()
        XCTAssertTrue(photos.staticTexts["Snipped!"].waitForExistence(timeout: 15))
        pause(4)

        app.activate()
        XCTAssertTrue(app.buttons["addCardButton"].waitForExistence(timeout: 20))
        pause(3)
    }

    private func snipFromSafari(_ url: String) {
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        safari.open(URL(string: url)!)
        XCTAssertTrue(safari.wait(for: .runningForeground, timeout: 15))
        XCTAssertTrue(safari.buttons["MoreMenuButton"].waitForExistence(timeout: 20))
        pause(4)

        tap(safari.buttons["MoreMenuButton"])
        pause(1.5)
        tap(safari.buttons.matching(NSPredicate(format: "label == %@", "Share")).firstMatch)
        pause(2)
        tap(safari.cells.matching(NSPredicate(format: "label == %@", "Sphir")).firstMatch)
        pause(3)

        tap(safari.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Extract specific part")).firstMatch)
        XCTAssertTrue(safari.buttons.matching(NSPredicate(format: "label == %@", "Snip it")).firstMatch
            .waitForExistence(timeout: 15))
        // Let the page render under the crop box before adjusting it.
        let paragraph = safari.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "concentrated form"))
            .firstMatch
        _ = paragraph.waitForExistence(timeout: 15)
        pause(3)

        // The crop box opens at x 0.152-0.85, y 0.407-0.636. Fit it to a
        // full-width strip, then move it onto the first paragraph.
        drag(safari, from: CGVector(dx: 0.85, dy: 0.636), to: CGVector(dx: 0.98, dy: 0.56))
        pause(1)
        drag(safari, from: CGVector(dx: 0.152, dy: 0.407), to: CGVector(dx: 0.02, dy: 0.407))
        pause(1)
        // The page lays out differently with or without Wikipedia's app
        // banner, so move the strip to where the paragraph actually is.
        let matches = safari.staticTexts
            .containing(NSPredicate(format: "label CONTAINS %@", "concentrated form")).allElementsBoundByIndex
        // Safari's own page (behind the sheet) also matches; the share
        // extension's copy comes last in the hierarchy.
        if let extensionParagraph = matches.last {
            let screen = safari.frame.size
            let boxTop = 0.407 * screen.height
            let targetTop = extensionParagraph.frame.minY - 22
            let delta = (targetTop - boxTop) / screen.height
            drag(safari, from: CGVector(dx: 0.5, dy: 0.4835), to: CGVector(dx: 0.5, dy: 0.4835 + delta))
        }
        pause(2)
        tap(safari.buttons.matching(NSPredicate(format: "label == %@", "Snip it")).firstMatch)

        // Metadata extraction, then save.
        let save = safari.buttons.matching(NSPredicate(format: "label == %@", "Save and send to Sphir")).firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 20))
        pause(5)
        save.tap()
        XCTAssertTrue(safari.staticTexts["Snipped!"].waitForExistence(timeout: 15))
        pause(4)

        // Back to Sphir: the snip is imported and synced on return.
        app.activate()
        XCTAssertTrue(app.buttons["addCardButton"].waitForExistence(timeout: 20))
        pause(3)
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

        section("Sign up")
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

        section("Create Sphirs")
        // Create Sphirs (collections) — the first tap after login must work.
        createCollection("Tech Inspiration")
        createCollection("Weekend Plans")

        section("Card from a link")
        // Save cards straight from links; the preview fills in title and image.
        addURLCard("https://www.apple.com", expectedTitle: "Apple")
        addURLCard("https://github.com", expectedTitle: "GitHub")

        section("Crop tool: screenshot")
        // Crop tool 1: inside the app, from a screenshot (with OCR).
        addCroppedScreenshotCard(title: "Espresso notes")

        section("Snippet: Safari")
        // Crop tool 2: from any app through the iOS share sheet.
        snipFromSafari("https://en.m.wikipedia.org/wiki/Espresso")
        section("Snippet: Photos")
        snipFromPhotos()

        section("Browse and read")
        // Open the Sphir and a card.
        let sphir = app.staticTexts["Tech Inspiration"].firstMatch
        waitHittable(sphir)
        sphir.tap()
        pause(2.5)

        // GitHub reads cleanly; apple.com adds a location-based region banner.
        tap(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "GitHub")).firstMatch)
        pause(3)

        // Read the page inside the app.
        tap(app.buttons["openInReaderButton"])
        pause(5)
        tap(app.buttons["readerBackButton"])
        pause(1.5)
        tap(app.buttons["cardDetailBackButton"])
        pause(1.5)

        section("Edit a card")
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

        section("Search")
        // Search across Sphirs and cards.
        type("Apple", into: app.textFields["searchField"])
        pause(1.5)
        // Tap the keyboard's Search key so the results are fully visible.
        app.typeText("\n")
        XCTAssertTrue(app.staticTexts["Apple"].firstMatch.waitForExistence(timeout: 5))
        pause(4)
        replaceText(in: app.textFields["searchField"], with: "")
        app.typeText("\n")
        pause(1.5)

        section("Notifications and settings")
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
