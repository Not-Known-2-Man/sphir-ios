//
//  ShareTheme.swift
//  SphirShare
//
//  Local copy of the Sphir design tokens for the share extension
//  (the main app's Theme.swift is not part of the extension target).
//

import SwiftUI

enum ShareColor {
    static let background = Color(red: 245/255, green: 242/255, blue: 238/255) // #f5f2ee
    static let cardBackground = Color.white
    static let cardBackgroundAlt = Color(red: 250/255, green: 248/255, blue: 245/255) // #faf8f5
    static let textPrimary = Color(red: 42/255, green: 40/255, blue: 37/255)   // #2a2825
    static let taupe = Color(red: 139/255, green: 123/255, blue: 104/255)      // #8b7b68
    static let mutedText = Color(red: 138/255, green: 130/255, blue: 121/255)  // #8a8279
    static let brown = Color(red: 92/255, green: 61/255, blue: 46/255)         // #5C3D2E
    static let sage = Color(red: 111/255, green: 154/255, blue: 98/255)        // #6F9A62
    static let sageLight = Color(red: 222/255, green: 233/255, blue: 213/255)  // #DEE9D5
    static let border = Color(red: 232/255, green: 227/255, blue: 220/255)     // #e8e3dc
}

enum ShareFont {
    static func heading(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}
