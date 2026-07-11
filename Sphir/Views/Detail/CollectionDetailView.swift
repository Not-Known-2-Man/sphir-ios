//
//  CollectionDetailView.swift
//  Sphir
//
//  Detail for a collection: header info plus the cards it contains.
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

    var body: some View {
        VStack(spacing: 0) {
            DetailTopBar(title: "Collection", backIdentifier: "collectionDetailBackButton") { dismiss() }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    ForEach(cards) { card in
                        NavigationLink(value: card) {
                            CardRowView(card: card)
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
                .font(SphirFont.heading(22, weight: .bold))
                .foregroundColor(SphirColor.textPrimary)

            if !collection.description.isEmpty {
                Text(collection.description)
                    .font(SphirFont.body(14))
                    .foregroundColor(SphirColor.mutedText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                PrivacyBadge(privacy: collection.privacy)
                Text("\(cards.count) items")
                    .font(SphirFont.body(12))
                    .foregroundColor(SphirColor.mutedText)
            }
        }
        .padding(.bottom, 4)
    }
}

/// A single card row inside a collection.
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
