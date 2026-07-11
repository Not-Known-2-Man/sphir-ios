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
        titleField.typeText("My Test Card")

        // Use the nav-bar Done (stays above the keyboard).
        app.buttons["navDoneButton"].tap()

        // Step 4: Success overlay.
        XCTAssertTrue(
            app.staticTexts["Card Saved!"].waitForExistence(timeout: 3),
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
