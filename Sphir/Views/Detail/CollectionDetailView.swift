//
//  CollectionDetailView.swift
//  Sphir
//
//  Detail for a collection: header info plus 2-column grid of cards matching Figma.
//

import SwiftUI
import UIKit

struct CollectionDetailView: View {
    let collection: Collection

    @EnvironmentObject private var appStore: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var editingCard: Card?
    @State private var pendingDelete: Card?

    private var cards: [Card] { appStore.cards(in: collection.id) }

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 14, alignment: .top),
        GridItem(.flexible(), spacing: 14, alignment: .top)
    ]

    var body: some View {
        VStack(spacing: 0) {
            DetailTopBar(title: "Collection", backIdentifier: "collectionDetailBackButton") { dismiss() }

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    if cards.isEmpty {
                        EmptyStateView(
                            icon: "tray",
                            title: "No cards yet",
                            message: "Add one with “+ Card”, or share a link to Sphir."
                        )
                    } else {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(cards) { card in
                                NavigationLink(value: card) {
                                    CardTileView(card: card)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button {
                                        editingCard = card
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        pendingDelete = card
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(SphirColor.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $editingCard) { card in
            EditCardView(card: card)
                .environmentObject(appStore)
        }
        .alert(
            "Delete card?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { card in
            Button("Delete", role: .destructive) {
                appStore.deleteCard(id: card.id)
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDelete = nil
            }
        } message: { card in
            Text("“\(card.title)” will be removed. This can't be undone.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(collection.name)
                .font(SphirFont.heading(28, weight: .bold))
                .foregroundColor(SphirColor.textPrimary)
                .accessibilityAddTraits(.isHeader)

            if !collection.description.isEmpty {
                Text(collection.description)
                    .font(SphirFont.body(14))
                    .foregroundColor(SphirColor.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 5) {
                Image(systemName: collection.privacy.iconName)
                    .font(.system(size: 11))
                Text("\(collection.privacy.label) · \(cards.count) items")
                    .font(SphirFont.body(12, weight: .medium))
            }
            .foregroundColor(SphirColor.mutedText)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(SphirColor.cardBackgroundAlt))
            .overlay(Capsule().stroke(SphirColor.border, lineWidth: 1))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(collection.privacy.label), \(cards.count) items")
        }
        .padding(.bottom, 4)
    }
}

/// A 2-column card tile matching the Figma collection grid.
struct CardTileView: View {
    let card: Card

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cover

            VStack(alignment: .leading, spacing: 4) {
                Text(CardType.label(for: card.cardType, url: card.content))
                    .font(SphirFont.body(10, weight: .bold).smallCaps())
                    .foregroundColor(SphirColor.taupe)
                    .lineLimit(1)

                Text(card.title)
                    .font(SphirFont.body(13, weight: .bold))
                    .foregroundColor(SphirColor.textPrimary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(SphirColor.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(SphirColor.border, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var cover: some View {
        switch CardDetailView.coverSource(for: card) {
        case .localData(let data):
            if let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 120)
                    .frame(maxWidth: .infinity)
                    .clipped()
            } else {
                coverPlaceholder
            }
        case .remoteURL(let url):
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(height: 120)
                        .frame(maxWidth: .infinity)
                        .clipped()
                } else {
                    coverPlaceholder
                }
            }
        case .placeholder:
            coverPlaceholder
        }
    }

    private var coverPlaceholder: some View {
        Rectangle()
            .fill(SphirColor.cardBackgroundAlt)
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            .overlay(
                Image(systemName: card.cardType.iconName)
                    .font(.system(size: 24))
                    .foregroundColor(SphirColor.lightTaupe)
            )
    }
}

/// A single card row inside a collection or dashboard.
struct CardRowView: View {
    let card: Card

    var body: some View {
        HStack(spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 3) {
                Text(card.title)
                    .font(SphirFont.body(15, weight: .semibold))
                    .foregroundColor(SphirColor.textPrimary)
                    .lineLimit(1)

                if !card.description.isEmpty {
                    Text(card.description)
                        .font(SphirFont.body(12))
                        .foregroundColor(SphirColor.mutedText)
                        .lineLimit(2)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: card.sourceApp.iconName)
                            .font(.system(size: 10))
                        Text(card.sourceApp.label)
                        Text("·")
                        Text(DetailDateFormatter.string(from: card.createdAt))
                    }
                    .font(SphirFont.body(12))
                    .foregroundColor(SphirColor.mutedText)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(SphirColor.mutedText)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(SphirColor.cardBackground))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(SphirColor.border, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let data = card.imageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            Circle()
                .fill(SphirColor.taupe.opacity(0.12))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: card.cardType.iconName)
                        .font(.system(size: 16))
                        .foregroundColor(SphirColor.taupe)
                )
        }
    }
}

#Preview {
    NavigationStack {
        CollectionDetailView(collection: Collection.mockCollections[0])
            .environmentObject(AppStore())
    }
}
