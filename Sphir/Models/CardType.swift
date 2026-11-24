//
//  CardType.swift
//  Sphir
//
//  Card kinds + display metadata. Pure Foundation; compiled into the app and
//  SphirShare.
//

import Foundation

/// The kind of content a card holds.
enum CardType: String, CaseIterable, Codable {
    case text
    case media
    case business
    case product
    case originalScribe
    case article
    case video
    case recipe
    case social
}

extension CardType {
    /// Emoji shown at the leading edge of the option row.
    var emoji: String {
        switch self {
        case .text:           return "📝"
        case .media:          return "🎬"
        case .business:       return "💼"
        case .product:        return "📦"
        case .originalScribe: return "✍️"
        case .article:        return "📰"
        case .video:          return "▶️"
        case .recipe:         return "🍳"
        case .social:         return "💬"
        }
    }

    var title: String {
        switch self {
        case .text:           return "Text"
        case .media:          return "Media"
        case .business:       return "Business"
        case .product:        return "Product"
        case .originalScribe: return "Original Scribe"
        case .article:        return "Article"
        case .video:          return "Video"
        case .recipe:         return "Recipe"
        case .social:         return "Social"
        }
    }

    var subtitle: String {
        switch self {
        case .text:           return "Articles, blogs, documents"
        case .media:          return "Videos, audio, images"
        case .business:       return "Contacts, companies"
        case .product:        return "Items, services"
        case .originalScribe: return "Your own content"
        case .article:        return "News, blog posts"
        case .video:          return "YouTube, Vimeo, TikTok"
        case .recipe:         return "Recipes and cooking"
        case .social:         return "Instagram, X, Facebook"
        }
    }

    /// SF Symbol representing the card type.
    var iconName: String {
        switch self {
        case .text:           return "doc.text"
        case .media:          return "play.rectangle"
        case .business:       return "briefcase"
        case .product:        return "shippingbox"
        case .originalScribe: return "pencil.and.outline"
        case .article:        return "newspaper"
        case .video:          return "play.rectangle.fill"
        case .recipe:         return "fork.knife"
        case .social:         return "bubble.left.and.bubble.right"
        }
    }

    /// Maps an S8 preview `type` to a CardType. "link" (and unknown values)
    /// map to `.text`, the existing generic web-link type.
    init(previewType: String) {
        switch previewType.lowercased() {
        case "article": self = .article
        case "product": self = .product
        case "video":   self = .video
        case "recipe":  self = .recipe
        case "social":  self = .social
        default:        self = .text
        }
    }

    /// Hidden tag used to persist the card type on the API (web convention).
    var typeTag: String { "_\(rawValue)" }
}
