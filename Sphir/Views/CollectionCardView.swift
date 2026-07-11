//
//  CollectionCardView.swift
//  Sphir
//
//  Reusable card that displays a single collection in the dashboard grid.
//

import SwiftUI

struct CollectionCardView: View {
    let collection: Collection

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Privacy badge (top-left)
            PrivacyBadge(privacy: collection.privacy)

            // Circular icon
            Circle()
                .fill(SphirColor.taupe)
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "square.stack.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                )

            // Title
            Text(collection.name)
                .font(SphirFont.body(15, weight: .bold))
                .foregroundColor(SphirColor.textPrimary)
                .lineLimit(1)

            // Item count
            Text("\(collection.cardCount) items")
                .font(SphirFont.body(12))
                .foregroundColor(SphirColor.mutedText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(SphirColor.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(SphirColor.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(collection.name), \(collection.cardCount) items, \(collection.privacy.label)")
    }
}

#Preview {
    CollectionCardView(collection: Collection.mockCollections[0])
        .padding()
        .background(SphirColor.background)
}
