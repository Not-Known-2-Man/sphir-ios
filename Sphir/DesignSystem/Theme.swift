//
//  Theme.swift
//  Sphir
//
//  Design tokens for the Sphir visual language.
//

import SwiftUI

/// Centralized color palette matching the Sphir design tokens.
enum SphirColor {
    static let background = Color(red: 245/255, green: 242/255, blue: 238/255) // #f5f2ee
    static let cardBackground = Color.white                                    // #ffffff
    static let cardBackgroundAlt = Color(red: 250/255, green: 248/255, blue: 245/255) // #faf8f5
    static let textPrimary = Color(red: 42/255, green: 40/255, blue: 37/255)   // #2a2825
    static let taupe = Color(red: 139/255, green: 123/255, blue: 104/255)      // #8b7b68
    static let lightTaupe = Color(red: 201/255, green: 184/255, blue: 154/255) // #c9b89a
    static let mutedText = Color(red: 138/255, green: 130/255, blue: 121/255)  // #8a8279
    static let border = Color(red: 232/255, green: 227/255, blue: 220/255)     // #e8e3dc
    static let success = Color(red: 76/255, green: 175/255, blue: 80/255)      // #4CAF50
}

extension Color {
    /// Create a color from a hex string like "#1E6B7A" or "1E6B7A".
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = Double((value & 0xFF0000) >> 16) / 255
        let g = Double((value & 0x00FF00) >> 8) / 255
        let b = Double(value & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

extension SyncStatus {
    /// Accent color for the sync-status badge.
    var color: Color {
        switch self {
        case .synced:  return SphirColor.success
        case .syncing: return SphirColor.taupe
        case .offline: return SphirColor.mutedText
        }
    }
}

/// Typography helpers. Headings approximate Playfair Display via a serif design;
/// if the Playfair Display font is later bundled, `.custom` will pick it up.
enum SphirFont {
    /// Serif heading font, falling back to the system serif design.
    static func heading(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// Body font using the system default (SF Pro).
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}
