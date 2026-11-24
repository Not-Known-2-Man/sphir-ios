//
//  CollectionCardView.swift
//  Sphir
//
//  Reusable card that displays a single collection in the dashboard grid.
//

import SwiftUI
import UIKit

struct CollectionCardView: View {
    let collection: Collection
    var covers: [CoverSource] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            coverView

            VStack(alignment: .leading, spacing: 4) {
                // Title
                Text(collection.name)
                    .font(SphirFont.body(15, weight: .bold))
                    .foregroundColor(SphirColor.textPrimary)
                    .lineLimit(1)

                // Item count
                Text(Collection.itemCountLabel(collection.cardCount))
                    .font(SphirFont.body(12))
                    .foregroundColor(SphirColor.mutedText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 14)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(SphirColor.cardBackground)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(SphirColor.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(collection.name), \(Collection.itemCountLabel(collection.cardCount)), \(collection.privacy.label)")
    }

    private var coverView: some View {
        coverContent
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .clipped()
            .overlay(alignment: .topLeading) {
                PrivacyBadge(privacy: collection.privacy)
                    .padding(10)
            }
    }

    @ViewBuilder
    private var coverContent: some View {
        if covers.count >= 3 {
            GeometryReader { proxy in
                let gap: CGFloat = 2
                let totalWidth = proxy.size.width
                let rightWidth = max(0, (totalWidth - gap) / 3)
                let leftWidth = max(0, totalWidth - gap - rightWidth)
                let rightHeight = max(0, (proxy.size.height - gap) / 2)

                HStack(spacing: gap) {
                    coverPiece(for: covers[0])
                        .frame(width: leftWidth, height: proxy.size.height)
                        .clipped()

                    VStack(spacing: gap) {
                        coverPiece(for: covers[1])
                            .frame(width: rightWidth, height: rightHeight)
                            .clipped()

                        coverPiece(for: covers[2])
                            .frame(width: rightWidth, height: rightHeight)
                            .clipped()
                    }
                    .frame(width: rightWidth, height: proxy.size.height)
                }
            }
        } else if let first = covers.first {
            coverPiece(for: first)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else {
            Rectangle()
                .fill(SphirColor.cardBackgroundAlt)
                .overlay(
                    Circle()
                        .fill(SphirColor.taupe)
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "square.stack.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        )
                )
        }
    }

    @ViewBuilder
    private func coverPiece(for source: CoverSource) -> some View {
        switch source {
        case .localData(let data):
            if let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle()
                    .fill(SphirColor.cardBackgroundAlt)
            }
        case .remoteURL(let url):
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(SphirColor.cardBackgroundAlt)
                }
            }
        case .placeholder:
            Rectangle()
                .fill(SphirColor.cardBackgroundAlt)
        }
    }
}

#Preview {
    CollectionCardView(collection: Collection.mockCollections[0])
        .padding()
        .background(SphirColor.background)
}
