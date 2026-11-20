//
//  LinkPreview.swift
//  Sphir
//
//  GET /api/v1/preview response (S8). Shared with SphirShare. Decoding is
//  tolerant so it also works against an API that only returns the old
//  title/description/image/url fields.
//

import Foundation

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

    init(url: String = "", title: String = "", description: String = "", image: String = "",
         type: String = "link", tags: [String] = [], price: String = "",
         site: String = "", published: String = "") {
        self.url = url; self.title = title; self.description = description
        self.image = image; self.type = type; self.tags = tags
        self.price = price; self.site = site; self.published = published
    }

    private enum CodingKeys: String, CodingKey {
        case url, title, description, image, type, tags, price, site, published
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
    }
}
