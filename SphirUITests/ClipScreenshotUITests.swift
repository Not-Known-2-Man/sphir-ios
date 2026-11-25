//
//  ClipScreenshotUITests.swift
//  SphirUITests
//
//  Walks the in-app clip (+Card -> preview card -> saved screen) and saves
//  PNGs to /tmp/clip-shots/ (and as xcresult attachments) for design review.
//  Launches in UITEST mode: no API login, so the preview uses the on-device
//  metadata fallback; with a local API (LOCAL_API) the card also shows tags
//  and price.
//

import XCTest

final class ClipScreenshotUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func shot(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let dir = URL(fileURLWithPath: "/tmp/clip-shots", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: dir.appendingPathComponent("\(name).png"))
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testClipScreens() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UITEST"]
        app.launch()

        let addCard = app.buttons["addCardButton"]
        XCTAssertTrue(addCard.waitForExistence(timeout: 10))
        addCard.tap()

        XCTAssertTrue(app.buttons["addCardWriteButton"].waitForExistence(timeout: 8))
        shot("1-add-card")

        let urlField = app.textFields["cardURLField"]
        urlField.tap()
        if !app.keyboards.element.waitForExistence(timeout: 2) { urlField.tap() }
        urlField.typeText("https://apple.com\n")

        let title = app.descendants(matching: .any)["clipTitleField"]
        XCTAssertTrue(title.waitForExistence(timeout: 20))
        let filled = NSPredicate(format: "value CONTAINS %@", "Apple")
        expectation(for: filled, evaluatedWith: title)
        waitForExpectations(timeout: 25)
        sleep(2)   // let the cover image load
        shot("2-preview-card")

        app.buttons["saveCardButton"].tap()
        XCTAssertTrue(app.staticTexts["Successfully clipped"].waitForExistence(timeout: 10))
        sleep(1)
        shot("3-card-saved")
    }
}
