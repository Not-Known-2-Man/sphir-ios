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
            .onChange(of: covers) { _, _ in failedCovers = [] }
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .clipped()
            .overlay(alignment: .topLeading) {
                PrivacyBadge(privacy: collection.privacy)
                    .padding(10)
            }
    }

    /// Indexes of the covers whose image could not be shown.
    @State private var failedCovers: Set<Int> = []

    @ViewBuilder
    private var coverContent: some View {
        // The mosaic shows three covers; with fewer, only the first is shown.
        if covers.isEmpty || failedCovers.count >= (covers.count >= 3 ? 3 : 1) {
            // No image, or none of them loaded: one centered Sphir mark.
            emptyCover()
        } else if covers.count >= 3 {
            GeometryReader { proxy in
                let gap: CGFloat = 2
                let totalWidth = proxy.size.width
                let rightWidth = max(0, (totalWidth - gap) / 3)
                let leftWidth = max(0, totalWidth - gap - rightWidth)
                let rightHeight = max(0, (proxy.size.height - gap) / 2)

                HStack(spacing: gap) {
                    coverPiece(at: 0)
                        .frame(width: leftWidth, height: proxy.size.height)
                        .clipped()

                    VStack(spacing: gap) {
                        coverPiece(at: 1)
                            .frame(width: rightWidth, height: rightHeight)
                            .clipped()

                        coverPiece(at: 2)
                            .frame(width: rightWidth, height: rightHeight)
                            .clipped()
                    }
                    .frame(width: rightWidth, height: proxy.size.height)
                }
            }
        } else {
            coverPiece(at: 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        }
    }

    /// A collection without images shows the Sphir mark.
    private func emptyCover() -> some View {
        Rectangle()
            .fill(SphirColor.cardBackgroundAlt)
            .overlay(
                Image("SphirMark")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 60, maxHeight: 60)
                    .padding(8)
                    .accessibilityHidden(true)
            )
    }

    /// A plain tile; a broken image marks its cover as failed so that when
    /// every cover fails the collection shows the Sphir mark instead.
    private func failedPiece(_ index: Int) -> some View {
        Rectangle()
            .fill(SphirColor.cardBackgroundAlt)
            .onAppear { failedCovers.insert(index) }
    }

    @ViewBuilder
    private func coverPiece(at index: Int) -> some View {
        switch covers[index] {
        case .localData(let data):
            if let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                failedPiece(index)
            }
        case .remoteURL(let url):
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFill()
                } else if phase.error != nil {
                    failedPiece(index)
                } else {
                    Rectangle().fill(SphirColor.cardBackgroundAlt)
                }
            }
        case .placeholder:
            failedPiece(index)
        }
    }
}

#Preview {
    CollectionCardView(collection: Collection.mockCollections[0])
        .padding()
        .background(SphirColor.background)
}
