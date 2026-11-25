//
//  ScreenshotAI.swift
//  Sphir
//
//  Response model and pure merge logic for POST /api/v1/ai/card-from-text.
//

import Foundation

struct ScreenshotAIResponse: Decodable, Equatable {
    var ai: Bool
    var title: String
    var description: String
    var price: String
    var type: String?
    var suggestedCollectionID: String?

    init(
        ai: Bool = false,
        title: String = "",
        description: String = "",
        price: String = "",
        type: String? = nil,
        suggestedCollectionID: String? = nil
    ) {
        self.ai = ai
        self.title = title
        self.description = description
        self.price = price
        self.type = type
        self.suggestedCollectionID = suggestedCollectionID
    }

    private enum CodingKeys: String, CodingKey {
        case ai, title, description, price, type
        case suggestedCollectionID = "suggested_collection_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ai = (try? c.decode(Bool.self, forKey: .ai)) ?? false
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        description = (try? c.decode(String.self, forKey: .description)) ?? ""
        price = (try? c.decode(String.self, forKey: .price)) ?? ""
        if let t = try? c.decode(String.self, forKey: .type), !t.isEmpty {
            type = t
        } else {
            type = nil
        }
        if let id = try? c.decode(Int.self, forKey: .suggestedCollectionID) {
            suggestedCollectionID = String(id)
        } else if let id = try? c.decode(String.self, forKey: .suggestedCollectionID), !id.isEmpty {
            suggestedCollectionID = id
        } else {
            suggestedCollectionID = nil
        }
    }
}

enum ScreenshotAI {
    struct MergeResult: Equatable {
        let title: String
        let content: String
        let selectedCollectionID: UUID?
        let showAILabel: Bool
    }

    /// Merges an AI response into the screenshot form without overwriting fields
    /// the user has already edited since OCR populated them.
    static func merge(
        currentTitle: String,
        currentContent: String,
        ocrTitle: String,
        ocrContent: String,
        currentCollectionID: UUID?,
        response: ScreenshotAIResponse,
        collections: [Collection]
    ) -> MergeResult {
        guard response.ai else {
            return MergeResult(
                title: currentTitle,
                content: currentContent,
                selectedCollectionID: currentCollectionID,
                showAILabel: false
            )
        }

        let nextTitle: String
        if currentTitle == ocrTitle,
           !response.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            nextTitle = response.title
        } else {
            nextTitle = currentTitle
        }

        let nextContent: String
        if currentContent == ocrContent,
           !response.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            nextContent = response.description
        } else {
            nextContent = currentContent
        }

        let nextCollectionID: UUID?
        if let suggestedID = response.suggestedCollectionID,
           !suggestedID.isEmpty,
           let matched = collections.first(where: { $0.serverID == suggestedID }) {
            nextCollectionID = matched.id
        } else {
            nextCollectionID = currentCollectionID
        }

        return MergeResult(
            title: nextTitle,
            content: nextContent,
            selectedCollectionID: nextCollectionID,
            showAILabel: true
        )
    }
}

// Lives here, not in NetworkService.swift: that file is also compiled into
// SphirShare, which does not include this app-only feature.
extension NetworkService {
    /// POST /api/v1/ai/card-from-text {text}
    func cardFromText(text: String) async throws -> ScreenshotAIResponse {
        try await request(
            "/api/v1/ai/card-from-text",
            method: .post,
            body: CardFromTextRequest(text: text)
        )
    }
}

private struct CardFromTextRequest: Encodable {
    let text: String
}
