//
//  CardAPIService.swift
//  Sphir
//
//  Businesses API → Card model.
//

import Foundation

/// A coding key built at runtime (to probe common list-wrapper keys).
private struct DynamicKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

/// Accepts either a bare array or a `{ data | businesses | results: [...] }`
/// wrapper for the businesses list.
struct BusinessListResponse: Decodable {
    let items: [BusinessDTO]

    init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(),
           let array = try? single.decode([BusinessDTO].self) {
            items = array
            return
        }
        if let keyed = try? decoder.container(keyedBy: DynamicKey.self) {
            for name in ["data", "businesses", "results"] {
                if let key = DynamicKey(stringValue: name),
                   let array = try? keyed.decode([BusinessDTO].self, forKey: key) {
                    items = array
                    return
                }
            }
        }
        items = []
    }
}

struct BusinessDTO: Decodable {
    let serverID: String?
    let title: String
    let description: String
    let website: String
    let email: String
    let tags: [String]
    let folderServerID: String?

    private enum CodingKeys: String, CodingKey {
        case id, title, description, website, email, tags
        case folderID = "folder_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        serverID = (try? c.decode(FlexibleID.self, forKey: .id))?.value
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        description = (try? c.decode(String.self, forKey: .description)) ?? ""
        website = (try? c.decode(String.self, forKey: .website)) ?? ""
        email = (try? c.decode(String.self, forKey: .email)) ?? ""
        folderServerID = (try? c.decode(FlexibleID.self, forKey: .folderID))?.value

        // Tags may be an array of strings or a comma-separated string.
        if let array = try? c.decode([String].self, forKey: .tags) {
            tags = array
        } else if let string = try? c.decode(String.self, forKey: .tags) {
            tags = string.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        } else {
            tags = []
        }
    }

    func toCard() -> Card {
        Card(
            title: title.isEmpty ? "Untitled" : title,
            description: description,
            content: website,
            cardType: .business,
            sourceApp: .safari,
            tags: tags,
            syncStatus: .synced,
            serverID: serverID
        )
    }
}

private struct BusinessRequest: Encodable {
    let title: String
    let description: String
    let website: String
    let email: String
    let tags: [String]

    init(card: Card) {
        title = card.title
        description = card.description
        website = card.content
        email = ""
        tags = card.tags
    }
}

enum CardAPIService {
    /// GET /api/v1/users/get_businesses
    static func fetchCards(page: Int = 1, perPage: Int = 50) async throws -> [BusinessDTO] {
        let response: BusinessListResponse = try await NetworkService.shared.request(
            "/api/v1/users/get_businesses",
            query: ["page": "\(page)", "per_page": "\(perPage)"]
        )
        return response.items
    }

    /// POST /api/v1/businesses — returns the created business (with id).
    static func createCard(_ card: Card) async throws -> Card {
        let dto: BusinessDTO = try await NetworkService.shared.request(
            "/api/v1/businesses",
            method: .post,
            body: BusinessRequest(card: card)
        )
        return dto.toCard()
    }

    /// PUT /api/v1/businesses/{id}
    static func updateCard(serverID: String, card: Card) async throws {
        let _: BusinessDTO = try await NetworkService.shared.request(
            "/api/v1/businesses/\(serverID)",
            method: .put,
            body: BusinessRequest(card: card)
        )
    }

    /// DELETE /api/v1/businesses/{id}
    static func deleteCard(serverID: String) async throws {
        _ = try await NetworkService.shared.request(
            "/api/v1/businesses/\(serverID)",
            method: .delete
        ) as EmptyResponse
    }
}
