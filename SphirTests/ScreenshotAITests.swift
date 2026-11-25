//
//  ScreenshotAITests.swift
//  SphirTests
//
//  Unit tests for ScreenshotAI response decoding and pure merge logic.
//

import Testing
import Foundation
@testable import Sphir

struct ScreenshotAITests {

    private func decode(_ json: String) throws -> ScreenshotAIResponse {
        try JSONDecoder().decode(ScreenshotAIResponse.self, from: Data(json.utf8))
    }

    private func makeCollections() -> [Collection] {
        [
            Collection(name: "Wishlist", cardCount: 2, serverID: "10"),
            Collection(name: "Recipes", cardCount: 5, serverID: "42"),
            Collection(name: "Local Only", cardCount: 1, serverID: nil)
        ]
    }

    @Test func decodesFullResponse() throws {
        let json = """
        {
            "ai": true,
            "title": "Matcha Whisk",
            "description": "Bamboo chasen whisk for ceremonial matcha.",
            "price": "$24",
            "type": "product",
            "suggested_collection_id": 42
        }
        """
        let response = try decode(json)
        #expect(response.ai == true)
        #expect(response.title == "Matcha Whisk")
        #expect(response.description == "Bamboo chasen whisk for ceremonial matcha.")
        #expect(response.price == "$24")
        #expect(response.type == "product")
        #expect(response.suggestedCollectionID == "42")
    }

    @Test func decodesNullTypeAndNullSuggestedID() throws {
        let json = """
        {
            "ai": false,
            "title": "",
            "description": "",
            "price": "",
            "type": null,
            "suggested_collection_id": null
        }
        """
        let response = try decode(json)
        #expect(response.ai == false)
        #expect(response.title == "")
        #expect(response.description == "")
        #expect(response.price == "")
        #expect(response.type == nil)
        #expect(response.suggestedCollectionID == nil)
    }

    @Test func aiTrueFillsBothTitleAndContentAndShowsLabel() {
        let collections = makeCollections()
        let response = ScreenshotAIResponse(
            ai: true,
            title: "AI Title",
            description: "AI Description"
        )

        let result = ScreenshotAI.merge(
            currentTitle: "OCR Title",
            currentContent: "OCR Content",
            ocrTitle: "OCR Title",
            ocrContent: "OCR Content",
            currentCollectionID: collections[0].id,
            response: response,
            collections: collections
        )

        #expect(result.title == "AI Title")
        #expect(result.content == "AI Description")
        #expect(result.selectedCollectionID == collections[0].id)
        #expect(result.showAILabel == true)
    }

    @Test func emptyAIFieldsKeepOCRValues() {
        let collections = makeCollections()
        let response = ScreenshotAIResponse(
            ai: true,
            title: "",
            description: "   "
        )

        let result = ScreenshotAI.merge(
            currentTitle: "OCR Title",
            currentContent: "OCR Content",
            ocrTitle: "OCR Title",
            ocrContent: "OCR Content",
            currentCollectionID: collections[0].id,
            response: response,
            collections: collections
        )

        #expect(result.title == "OCR Title")
        #expect(result.content == "OCR Content")
        #expect(result.showAILabel == true)
    }

    @Test func userEditedTitleIsKeptWhileContentIsReplaced() {
        let collections = makeCollections()
        let response = ScreenshotAIResponse(
            ai: true,
            title: "AI Title",
            description: "AI Description"
        )

        let result = ScreenshotAI.merge(
            currentTitle: "My Custom Title",
            currentContent: "OCR Content",
            ocrTitle: "OCR Title",
            ocrContent: "OCR Content",
            currentCollectionID: collections[0].id,
            response: response,
            collections: collections
        )

        #expect(result.title == "My Custom Title")
        #expect(result.content == "AI Description")
        #expect(result.showAILabel == true)
    }

    @Test func userEditedContentIsKeptWhileTitleIsReplaced() {
        let collections = makeCollections()
        let response = ScreenshotAIResponse(
            ai: true,
            title: "AI Title",
            description: "AI Description"
        )

        let result = ScreenshotAI.merge(
            currentTitle: "OCR Title",
            currentContent: "My Custom Notes",
            ocrTitle: "OCR Title",
            ocrContent: "OCR Content",
            currentCollectionID: collections[0].id,
            response: response,
            collections: collections
        )

        #expect(result.title == "AI Title")
        #expect(result.content == "My Custom Notes")
        #expect(result.showAILabel == true)
    }

    @Test func suggestedServerIDMapsToLocalCollection() {
        let collections = makeCollections()
        let response = ScreenshotAIResponse(
            ai: true,
            title: "AI Title",
            description: "AI Description",
            suggestedCollectionID: "42"
        )

        let result = ScreenshotAI.merge(
            currentTitle: "OCR Title",
            currentContent: "OCR Content",
            ocrTitle: "OCR Title",
            ocrContent: "OCR Content",
            currentCollectionID: collections[0].id,
            response: response,
            collections: collections
        )

        #expect(result.selectedCollectionID == collections[1].id)
    }

    @Test func unknownSuggestedIDLeavesSelectionUnchanged() {
        let collections = makeCollections()
        let response = ScreenshotAIResponse(
            ai: true,
            title: "AI Title",
            description: "AI Description",
            suggestedCollectionID: "999"
        )

        let result = ScreenshotAI.merge(
            currentTitle: "OCR Title",
            currentContent: "OCR Content",
            ocrTitle: "OCR Title",
            ocrContent: "OCR Content",
            currentCollectionID: collections[0].id,
            response: response,
            collections: collections
        )

        #expect(result.selectedCollectionID == collections[0].id)
    }

    @Test func aiFalseChangesNothingAndShowsNoLabel() {
        let collections = makeCollections()
        let response = ScreenshotAIResponse(
            ai: false,
            title: "Ignored Title",
            description: "Ignored Description",
            suggestedCollectionID: "42"
        )

        let result = ScreenshotAI.merge(
            currentTitle: "OCR Title",
            currentContent: "OCR Content",
            ocrTitle: "OCR Title",
            ocrContent: "OCR Content",
            currentCollectionID: collections[0].id,
            response: response,
            collections: collections
        )

        #expect(result.title == "OCR Title")
        #expect(result.content == "OCR Content")
        #expect(result.selectedCollectionID == collections[0].id)
        #expect(result.showAILabel == false)
    }
}
