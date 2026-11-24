//
//  CollectionCover.swift
//  Sphir
//
//  Helper to extract cover image sources from collection cards.
//

import Foundation

enum CollectionCover {
    static func sources(for cards: [Card]) -> [CoverSource] {
        Array(
            cards
                .map { CardDetailView.coverSource(for: $0) }
                .filter { $0 != .placeholder }
                .prefix(3)
        )
    }
}
