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
    let imageURL: String?
    /// Display price (e.g. "$29.99"); "" when the API has none.
    let price: String
    /// Site name and publication date (YYYY-MM-DD); "" when the API has none.
    let site: String
    let published: String
    /// Every collection of the card, primary first (`folder_ids`, S8/T2);
    /// falls back to the single `folder_id` for older APIs.
    let folderServerIDs: [String]
    /// The private lock (`is_private`); a missing or malformed value reads as locked.
    let isPrivate: Bool

    private enum CodingKeys: String, CodingKey {
        case id, title, description, website, email, tags, price, site, published
        case folderID = "folder_id"
        case folderIDs = "folder_ids"
        case ogImage = "og_image"
        case isPrivate = "is_private"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        serverID = (try? c.decode(FlexibleID.self, forKey: .id))?.value
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        description = (try? c.decode(String.self, forKey: .description)) ?? ""
        website = (try? c.decode(String.self, forKey: .website)) ?? ""
        email = (try? c.decode(String.self, forKey: .email)) ?? ""
        folderServerID = (try? c.decode(FlexibleID.self, forKey: .folderID))?.value
        let og = (try? c.decode(String.self, forKey: .ogImage)) ?? ""
        imageURL = og.isEmpty ? nil : og
        price = (try? c.decode(String.self, forKey: .price)) ?? ""
        site = (try? c.decode(String.self, forKey: .site)) ?? ""
        published = (try? c.decode(String.self, forKey: .published)) ?? ""
        isPrivate = (try? c.decode(Bool.self, forKey: .isPrivate)) ?? true
        if let ids = try? c.decode([FlexibleID].self, forKey: .folderIDs) {
            folderServerIDs = ids.map(\.value).filter { !$0.isEmpty }
        } else {
            folderServerIDs = folderServerID.map { [$0] } ?? []
        }

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
        // The card type round-trips through a hidden "_<type>" tag (S8).
        let typeTagged = tags.first { $0.hasPrefix("_") && CardType(rawValue: String($0.dropFirst())) != nil }
        let type = typeTagged.flatMap { CardType(rawValue: String($0.dropFirst())) } ?? .business
        let visibleTags = tags.filter { !$0.hasPrefix("_") }
        return Card(
            title: title.isEmpty ? "Untitled" : title,
            description: description,
            content: website,
            cardType: type,
            sourceApp: .safari,
            imageURL: imageURL,
            price: price,
            site: site,
            published: published,
            tags: visibleTags,
            syncStatus: .synced,
            serverID: serverID,
            folderServerIDs: folderServerIDs,
            isPrivate: isPrivate
        )
    }
}

/// What an edit does to the card image. Only an explicit change reaches
/// og_image: a text-only edit never clears or overwrites an image set elsewhere.
enum CardImageChange: Equatable {
    case unchanged
    case replaced
    case removed
}

struct BusinessRequest: Encodable {
    let title: String
    let description: String
    let website: String
    let email: String
    let tags: [String]
    let folderID: String?
    let ogImage: String?
    let price: String?
    /// nil when empty so an update never clears what the server already has.
    let site: String?
    let published: String?
    let isPrivate: Bool

    enum CodingKeys: String, CodingKey {
        case title, description, website, email, tags, price, site, published
        case folderID = "folder_id"
        case ogImage = "og_image"
        case isPrivate = "is_private"
    }

    /// `price` overrides the card's own price (the clip draft passes its edited one).
    /// `imageChange` is for updates: nil (create paths) keeps sending the card's http image;
    /// `.unchanged` omits og_image, `.replaced` sends the card's new URL, `.removed` sends "".
    init(card: Card, folderServerID: String? = nil, price: String? = nil, imageChange: CardImageChange? = nil) {
        let own = card.price.isEmpty ? nil : card.price
        self.price = price ?? own
        site = card.site.isEmpty ? nil : card.site
        published = card.published.isEmpty ? nil : card.published
        isPrivate = card.isPrivate
        title = card.title
        description = card.description
        website = card.content
        email = ""
        // Store the card type as a hidden "_<type>" tag; own cards (.originalScribe) too.
        tags = card.tags.filter { !$0.hasPrefix("_") } + [card.cardType.typeTag]
        folderID = folderServerID
        let httpImage = card.imageURL.flatMap { $0.hasPrefix("http://") || $0.hasPrefix("https://") ? $0 : nil }
        switch imageChange {
        case nil, .replaced?: ogImage = httpImage
        case .unchanged?:     ogImage = nil
        case .removed?:       ogImage = ""
        }
    }
}

/// PUT /api/v1/businesses/:id/folders body. Server ids are integers.
struct BusinessFoldersRequest: Encodable {
    let folderIDs: [String]

    enum CodingKeys: String, CodingKey { case folderIDs = "folder_ids" }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(folderIDs.map { Int($0).map(AnyEncodable.init) ?? AnyEncodable($0) }, forKey: .folderIDs)
    }
}

private struct ImageUploadRequest: Encodable {
    let data: String
}

private struct ImageUploadResponse: Decodable {
    let url: String
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

    /// Every card of the account: reads pages (API max 100 per page) until one
    /// comes back short. Any page error fails the whole fetch, so a sync never
    /// reconciles against a partial list. A card created between two pages
    /// shifts the rest by one; repeated ids are dropped.
    static func fetchAllCards(
        perPage: Int = 100,
        maxPages: Int = 100,
        fetchPage: (_ page: Int, _ perPage: Int) async throws -> [BusinessDTO] = { try await fetchCards(page: $0, perPage: $1) }
    ) async throws -> [BusinessDTO] {
        var all: [BusinessDTO] = []
        var seen = Set<String>()
        for page in 1...maxPages {
            let batch = try await fetchPage(page, perPage)
            for dto in batch where dto.serverID.map({ seen.insert($0).inserted }) ?? true {
                all.append(dto)
            }
            if batch.count < perPage { break }
        }
        return all
    }

    /// POST /api/v1/businesses — returns the created business (with id).
    /// Pass the MySQL folder serverID so folder_id is stored correctly.
    static func createCard(_ card: Card, folderServerID: String? = nil) async throws -> Card {
        let dto: BusinessDTO = try await NetworkService.shared.request(
            "/api/v1/businesses",
            method: .post,
            body: BusinessRequest(card: card, folderServerID: folderServerID)
        )
        return dto.toCard()
    }

    /// POST /api/v1/businesses from a clip draft — returns the created business
    /// (id, folder_ids). Sends type tag, og_image and price.
    static func createCard(_ request: BusinessRequest) async throws -> BusinessDTO {
        try await NetworkService.shared.request("/api/v1/businesses", method: .post, body: request)
    }

    /// PUT /api/v1/businesses/{id}/folders — replaces the card's collections
    /// (first id = primary). Returns the card with its `folder_ids`.
    static func setFolders(serverID: String, folderIDs: [String]) async throws -> BusinessDTO {
        try await NetworkService.shared.request(
            "/api/v1/businesses/\(serverID)/folders",
            method: .put,
            body: BusinessFoldersRequest(folderIDs: folderIDs)
        )
    }

    /// PUT /api/v1/businesses/{id}. og_image is only sent for an explicit image change.
    static func updateCard(serverID: String, card: Card, imageChange: CardImageChange = .unchanged,
                           using service: NetworkService = .shared) async throws {
        let _: BusinessDTO = try await service.request(
            "/api/v1/businesses/\(serverID)",
            method: .put,
            body: BusinessRequest(card: card, imageChange: imageChange)
        )
    }

    /// POST /api/v1/images {data: "data:image/jpeg;base64,..."} -> 201 {id, url}.
    /// Returns the image URL to store as the card's og_image. Needs a signed-in user.
    static func uploadImage(_ jpeg: Data, using service: NetworkService = .shared) async throws -> String {
        let response: ImageUploadResponse = try await service.request(
            "/api/v1/images",
            method: .post,
            body: ImageUploadRequest(data: "data:image/jpeg;base64,\(jpeg.base64EncodedString())")
        )
        return response.url
    }

    /// DELETE /api/v1/businesses/{id}
    static func deleteCard(serverID: String) async throws {
        _ = try await NetworkService.shared.request(
            "/api/v1/businesses/\(serverID)",
            method: .delete
        ) as EmptyResponse
    }
}
