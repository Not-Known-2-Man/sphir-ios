//
//  SphirUITests.swift
//  SphirUITests
//
//  Created by Saul Alejandro on 09/07/26.
//

import XCTest

final class SphirUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testAddCardFlowIncrementsCollectionCount() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST"]
        app.launch()

        // The first mock collection ("Reading List") starts at 12 items.
        XCTAssertTrue(
            app.staticTexts["12 items"].waitForExistence(timeout: 5),
            "Dashboard should show the initial count of 12 items."
        )

        // Dashboard → +Card
        app.buttons["addCardButton"].tap()

        // Step 1: Select Type → Text
        let textType = app.buttons["cardType_text"]
        XCTAssertTrue(textType.waitForExistence(timeout: 3), "Card type list should appear.")
        textType.tap()

        // Step 2: Select Source → Paste URL (leads to the manual card form;
        // Photos/Camera/Screenshots open system pickers instead).
        let urlSource = app.buttons["cardSource_url"]
        XCTAssertTrue(urlSource.waitForExistence(timeout: 3), "Source list should appear.")
        urlSource.tap()

        // Step 3: Form → enter a title and save.
        let titleField = app.textFields["cardTitleField"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3), "Card form should appear.")
        titleField.tap()
        if !app.keyboards.element.waitForExistence(timeout: 2) {
            titleField.tap()
        }
        titleField.typeText("My Test Card")

        // Use the nav-bar Done (stays above the keyboard).
        app.buttons["navDoneButton"].tap()

        // Step 4: Success overlay.
        XCTAssertTrue(
            app.staticTexts["Card Saved!"].waitForExistence(timeout: 5),
            "Success screen should appear after saving."
        )
        // Tap "Back to Dashboard" if it's still up; otherwise the 3s
        // auto-dismiss returns us to the dashboard on its own.
        let backButton = app.buttons["backToDashboardButton"]
        if backButton.waitForExistence(timeout: 1) {
            backButton.tap()
        }

        // Back on the dashboard the count should have incremented to 13.
        XCTAssertTrue(
            app.staticTexts["13 items"].waitForExistence(timeout: 5),
            "Collection count should increment to 13 after adding a card."
        )
        XCTAssertFalse(
            app.staticTexts["12 items"].exists,
            "The stale 12-item count should no longer be shown."
        )
    }

    @MainActor
    func testCreateCollectionAppearsInGrid() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST"]
        app.launch()

        // The dashboard starts with 4 mock collections.
        XCTAssertTrue(
            app.staticTexts["Reading List"].waitForExistence(timeout: 5),
            "Dashboard should show the initial collections."
        )
        XCTAssertFalse(app.staticTexts["Field Notes"].exists)

        // Dashboard → +Collection
        app.buttons["addCollectionButton"].tap()

        // Fill the form and continue.
        let titleField = app.textFields["collectionTitleField"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3), "Collection form should appear.")
        titleField.tap()
        titleField.typeText("Field Notes")

        app.buttons["collectionContinueButton"].tap()

        // Success confirmation, then auto-return to the dashboard.
        XCTAssertTrue(
            app.staticTexts["Collection Created!"].waitForExistence(timeout: 3),
            "Success screen should appear after creating a collection."
        )

        // New collection should now be in the grid.
        XCTAssertTrue(
            app.staticTexts["Field Notes"].waitForExistence(timeout: 5),
            "The new collection should appear in the dashboard grid."
        )
    }

    @MainActor
    func testCollectionAndCardNavigation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST"]
        app.launch()

        // Dashboard → open a collection.
        let collection = app.staticTexts["Reading List"]
        XCTAssertTrue(collection.waitForExistence(timeout: 5))
        collection.tap()

        // Collection detail shows the description and a card row.
        XCTAssertTrue(
            app.staticTexts["Articles and posts saved for later."].waitForExistence(timeout: 3),
            "Collection detail should show the description."
        )
        let cardRow = app.staticTexts["Highlights Reel"]
        XCTAssertTrue(cardRow.waitForExistence(timeout: 3))
        cardRow.tap()

        // Card detail shows tags + sync status.
        XCTAssertTrue(
            app.staticTexts["#video"].waitForExistence(timeout: 3),
            "Card detail should show tags."
        )
        XCTAssertTrue(app.staticTexts["Tags"].exists)

        // Back to collection, then back to dashboard.
        app.buttons["cardDetailBackButton"].tap()
        XCTAssertTrue(app.staticTexts["Articles and posts saved for later."].waitForExistence(timeout: 3))
        app.buttons["collectionDetailBackButton"].tap()
        XCTAssertTrue(app.staticTexts["Good morning, Alex"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testSearchFiltersCollectionsAndCards() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Reading List"].waitForExistence(timeout: 5))

        let search = app.textFields["searchField"]
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        search.tap()
        if !app.keyboards.element.waitForExistence(timeout: 2) {
            search.tap()
        }
        search.typeText("Reading")

        // Matching collection stays; non-matching one is filtered out.
        XCTAssertTrue(app.staticTexts["Reading List"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Inspiration"].exists)

        // A seeded card whose title contains the query shows in the results.
        XCTAssertTrue(
            app.staticTexts["Reading List: Getting Started"].waitForExistence(timeout: 3),
            "A matching card should appear in the Cards results."
        )
    }

    @MainActor
    func testDeleteCardViaContextMenu() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST"]
        app.launch()

        app.staticTexts["Reading List"].tap()
        XCTAssertTrue(app.staticTexts["Articles and posts saved for later."].waitForExistence(timeout: 3))

        // Reading List seeds 12 cards.
        XCTAssertTrue(app.staticTexts["12 items"].waitForExistence(timeout: 3))

        let row = app.buttons.containing(
            NSPredicate(format: "label CONTAINS %@", "Wishlist Item")
        ).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        row.press(forDuration: 1.0)

        app.buttons["Delete"].firstMatch.tap()        // context-menu item
        let confirm = app.alerts.buttons["Delete"]     // confirmation alert
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        confirm.tap()

        // Deleting one card drops the collection's count.
        XCTAssertTrue(
            app.staticTexts["11 items"].waitForExistence(timeout: 3),
            "Count should drop to 11 after deleting a card."
        )
    }

    @MainActor
    func testEditCardViaContextMenu() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST"]
        app.launch()

        app.staticTexts["Reading List"].tap()
        XCTAssertTrue(app.staticTexts["Articles and posts saved for later."].waitForExistence(timeout: 3))

        let row = app.buttons.containing(
            NSPredicate(format: "label CONTAINS %@", "Key Contact")
        ).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        row.press(forDuration: 1.0)

        app.buttons["Edit"].firstMatch.tap()

        let titleField = app.textFields["editTitleField"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        titleField.tap()
        if !app.keyboards.element.waitForExistence(timeout: 2) {
            titleField.tap()
        }
        // Clear the pre-filled title, then set a unique one.
        if let current = titleField.value as? String, !current.isEmpty {
            titleField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        let uniqueTitle = "Renamed Card XYZ"
        titleField.typeText(uniqueTitle)

        app.buttons["editSaveButton"].tap()

        XCTAssertTrue(
            app.staticTexts[uniqueTitle].waitForExistence(timeout: 3),
            "Edited title should appear in the card list."
        )
    }

    @MainActor
    func testOnboardingShowsThenDismisses() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST", "SHOW_ONBOARDING"]
        app.launch()

        XCTAssertTrue(
            app.staticTexts["Welcome to Sphir"].waitForExistence(timeout: 5),
            "Onboarding should appear on first launch."
        )
        app.buttons["getStartedButton"].tap()

        XCTAssertTrue(
            app.staticTexts["Good morning, Alex"].waitForExistence(timeout: 3),
            "Dashboard should appear after Get Started."
        )
    }

    @MainActor
    func testSignUpShowsOnboardingThenDashboard() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST", "LOGGED_OUT", "SHOW_ONBOARDING"]
        app.launch()

        // Auth screen (Sign In by default) → switch to Sign Up.
        let toggle = app.buttons["authToggleButton"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "Auth screen should appear when logged out.")
        toggle.tap()

        let nameField = app.textFields["authNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.tap()
        if !app.keyboards.element.waitForExistence(timeout: 2) { nameField.tap() }
        nameField.typeText("Dana")

        app.textFields["authEmailField"].tap()
        app.textFields["authEmailField"].typeText("dana@example.com")

        app.secureTextFields["authPasswordField"].tap()
        app.secureTextFields["authPasswordField"].typeText("secret")

        app.buttons["authSubmitButton"].tap()

        // First-time user → onboarding → dashboard with their name.
        XCTAssertTrue(app.staticTexts["Welcome to Sphir"].waitForExistence(timeout: 5))
        app.buttons["getStartedButton"].tap()

        // Dashboard should appear…
        XCTAssertTrue(
            app.buttons["addCardButton"].waitForExistence(timeout: 8),
            "Dashboard should appear after onboarding."
        )
        // …greeting the signed-up user by name.
        let greeting = app.staticTexts
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Good morning"))
            .firstMatch
        XCTAssertTrue(greeting.waitForExistence(timeout: 3))
        XCTAssertTrue(greeting.label.contains("Dana"), "Greeting was: \(greeting.label)")
    }

    @MainActor
    func testSignInSkipsOnboarding() throws {
        let app = XCUIApplication()
        // LOGGED_OUT (no SHOW_ONBOARDING) → returning user who has seen onboarding.
        app.launchArguments = ["UITEST", "LOGGED_OUT"]
        app.launch()

        let emailField = app.textFields["authEmailField"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
        emailField.tap()
        if !app.keyboards.element.waitForExistence(timeout: 2) { emailField.tap() }
        emailField.typeText("dana@example.com")

        app.secureTextFields["authPasswordField"].tap()
        app.secureTextFields["authPasswordField"].typeText("secret")

        app.buttons["authSubmitButton"].tap()

        // Straight to the dashboard — no onboarding.
        XCTAssertTrue(
            app.staticTexts["Good morning, Dana"].waitForExistence(timeout: 5),
            "Sign In should go directly to the dashboard."
        )
        XCTAssertFalse(app.staticTexts["Welcome to Sphir"].exists, "Onboarding should be skipped.")
    }

    @MainActor
    func testSignOutReturnsToAuth() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Good morning, Alex"].waitForExistence(timeout: 5))
        app.buttons["settingsButton"].tap()

        let signOut = app.buttons["signOutButton"]
        XCTAssertTrue(signOut.waitForExistence(timeout: 3))
        signOut.tap()

        XCTAssertTrue(
            app.textFields["authEmailField"].waitForExistence(timeout: 5),
            "Signing out should return to the auth screen."
        )
    }

    @MainActor
    func testNotificationsEmptyState() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST"]
        app.launch()

        app.buttons["notificationsButton"].tap()
        XCTAssertTrue(
            app.staticTexts["No new notifications"].waitForExistence(timeout: 3),
            "Bell should open the notifications empty state."
        )
    }

    /// Requires network in the simulator. Types a URL and waits for the
    /// fetched title to auto-populate.
    @MainActor
    func testPasteURLFetchesMetadata() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST"]
        app.launch()

        app.buttons["addCardButton"].tap()
        app.buttons["cardType_text"].tap()
        app.buttons["cardSource_url"].tap()

        let urlField = app.textFields["cardURLField"]
        XCTAssertTrue(urlField.waitForExistence(timeout: 3))
        urlField.tap()
        if !app.keyboards.element.waitForExistence(timeout: 2) {
            urlField.tap()
        }
        urlField.typeText("https://apple.com\n")

        // The title field's value should become "Apple" once metadata loads.
        let titleField = app.textFields["cardTitleField"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        let populated = NSPredicate(format: "value == %@", "Apple")
        expectation(for: populated, evaluatedWith: titleField)
        waitForExpectations(timeout: 20)
    }

    /// Requires network. Creates a URL card, opens it, and launches the
    /// in-app reader.
    @MainActor
    func testOpenInReaderLoadsPage() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST"]
        app.launch()

        // Create a card from a URL.
        app.buttons["addCardButton"].tap()
        let textType = app.buttons["cardType_text"]
        XCTAssertTrue(textType.waitForExistence(timeout: 3))
        textType.tap()
        let urlSource = app.buttons["cardSource_url"]
        XCTAssertTrue(urlSource.waitForExistence(timeout: 3))
        urlSource.tap()

        let urlField = app.textFields["cardURLField"]
        XCTAssertTrue(urlField.waitForExistence(timeout: 3))
        urlField.tap()
        if !app.keyboards.element.waitForExistence(timeout: 2) { urlField.tap() }
        urlField.typeText("https://apple.com\n")

        // Confirm metadata fetched, then save.
        let titleField = app.textFields["cardTitleField"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 3))
        expectation(for: NSPredicate(format: "value == %@", "Apple"), evaluatedWith: titleField)
        waitForExpectations(timeout: 20)
        app.buttons["navDoneButton"].tap()

        // The success screen auto-dismisses back to the dashboard. Open the
        // Reading List collection card (its label begins with "Reading List").
        let readingList = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Reading List"))
            .firstMatch
        XCTAssertTrue(readingList.waitForExistence(timeout: 8))
        readingList.tap()

        let appleCard = app.staticTexts["Apple"].firstMatch
        XCTAssertTrue(appleCard.waitForExistence(timeout: 5))
        appleCard.tap()

        // Open in Reader → WKWebView reader appears.
        let openReader = app.buttons["openInReaderButton"]
        XCTAssertTrue(openReader.waitForExistence(timeout: 3), "Open in Reader button should show for URL cards.")
        openReader.tap()

        XCTAssertTrue(
            app.buttons["readerBackButton"].waitForExistence(timeout: 5),
            "The in-app reader should open."
        )
    }

    @MainActor
    func testDeepLinkOpensCollection() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST"]
        // Reading List has a stable seeded id.
        app.launchEnvironment = ["DEEPLINK": "sphir://collection/00000000-0000-0000-0000-000000000001"]
        app.launch()

        // The collection detail should be pushed automatically.
        XCTAssertTrue(
            app.staticTexts["Articles and posts saved for later."].waitForExistence(timeout: 5),
            "Deep link should open the Reading List collection detail."
        )
        XCTAssertTrue(app.buttons["collectionDetailBackButton"].exists)
    }

    @MainActor
    func testGroupsTabSwitching() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Reading List"].waitForExistence(timeout: 5))

        // Switch to Groups.
        app.buttons["Groups"].tap()
        XCTAssertTrue(
            app.staticTexts["Rockets"].waitForExistence(timeout: 3),
            "Groups tab should show the mock Sphirs."
        )
        XCTAssertTrue(app.staticTexts["All Things Canning"].exists)

        // Switch back to Collections.
        app.buttons["Collections"].tap()
        XCTAssertTrue(
            app.staticTexts["Reading List"].waitForExistence(timeout: 3),
            "Collections tab should return."
        )
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
