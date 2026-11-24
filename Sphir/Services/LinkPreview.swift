//
//  LinkPreview.swift
//  Sphir
//
//  GET /api/v1/preview response (S8). Shared with SphirShare. Decoding is
//  tolerant so it also works against an API that only returns the old
//  title/description/image/url fields.
//

import Foundation

/// `already_on_sphir`: how many people saved this link and the stored card
/// (never who saved it).
struct AlreadyOnSphir: Decodable, Equatable {
    var count: Int
    var title: String
    var image: String
    var price: String

    init(count: Int, title: String, image: String, price: String) {
        self.count = count; self.title = title; self.image = image; self.price = price
    }

    private enum CodingKeys: String, CodingKey { case count, title, image, price }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func str(_ k: CodingKeys) -> String { (try? c.decode(String.self, forKey: k)) ?? "" }
        count = (try? c.decode(Int.self, forKey: .count)) ?? 0
        title = str(.title); image = str(.image); price = str(.price)
    }

    var notice: String {
        "Already on Sphir · \(count) \(count == 1 ? "person" : "people") saved it"
    }
}

struct LinkPreview: Decodable, Equatable {
    var url: String
    var title: String
    var description: String
    var image: String
    var type: String
    var tags: [String]
    var price: String
    var site: String
    var published: String
    /// Set when someone already saved this link (S1/S4).
    var alreadyOnSphir: AlreadyOnSphir?
    /// True when the AI filled the card (S5/S6).
    var ai = false
    /// The user's own collection the AI suggests (server folder id).
    var suggestedCollectionID: String?

    init(url: String = "", title: String = "", description: String = "", image: String = "",
         type: String = "link", tags: [String] = [], price: String = "",
         site: String = "", published: String = "") {
        self.url = url; self.title = title; self.description = description
        self.image = image; self.type = type; self.tags = tags
        self.price = price; self.site = site; self.published = published
    }

    private enum CodingKeys: String, CodingKey {
        case url, title, description, image, type, tags, price, site, published
        case alreadyOnSphir = "already_on_sphir", ai, suggestedCollectionID = "suggested_collection_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func str(_ k: CodingKeys) -> String { (try? c.decode(String.self, forKey: k)) ?? "" }
        url = str(.url)
        title = str(.title)
        description = str(.description)
        image = str(.image)
        let t = str(.type)
        type = t.isEmpty ? "link" : t
        tags = (try? c.decode([String].self, forKey: .tags)) ?? []
        price = str(.price)
        site = str(.site)
        published = str(.published)
        let saved = try? c.decode(AlreadyOnSphir.self, forKey: .alreadyOnSphir)
        alreadyOnSphir = (saved?.count ?? 0) > 0 ? saved : nil
        ai = (try? c.decode(Bool.self, forKey: .ai)) ?? false
        if let id = try? c.decode(Int.self, forKey: .suggestedCollectionID) {
            suggestedCollectionID = String(id)
        } else if let id = try? c.decode(String.self, forKey: .suggestedCollectionID), !id.isEmpty {
            suggestedCollectionID = id
        }
    }
}
