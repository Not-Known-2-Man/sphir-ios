//
//  CardSource.swift
//  Sphir
//
//  Capture-method choices presented in the "+Card" flow (Step 2).
//  Distinct from `SourceApp`, which records provenance on a saved card.
//

import Foundation

/// How the user is adding content in the card-creation flow.
enum CardSource: String, CaseIterable, Identifiable {
    case photos
    case camera
    case url
    case screenshots

    var id: String { rawValue }

    /// Emoji shown at the leading edge of the option row.
    var emoji: String {
        switch self {
        case .photos:      return "📷"
        case .camera:      return "📸"
        case .url:         return "🔗"
        case .screenshots: return "🖼️"
        }
    }

    var title: String {
        switch self {
        case .photos:      return "From Photos"
        case .camera:      return "Take Photo"
        case .url:         return "Paste URL"
        case .screenshots: return "From Screenshots or Photos"
        }
    }

    var subtitle: String {
        switch self {
        case .photos:      return "Choose from your library"
        case .camera:      return "Use your camera"
        case .url:         return "Share a link"
        case .screenshots: return "Extract text with OCR"
        }
    }
}
