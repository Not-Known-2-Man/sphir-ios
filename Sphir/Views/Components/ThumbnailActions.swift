//
//  ThumbnailActions.swift
//  Sphir
//
//  Actions on a card or collection thumbnail: a visible "..." menu plus the
//  same items on long press. Share sends the content outside Sphir through the
//  iOS share sheet.
//

import SwiftUI

/// What the share action sends for a card or a collection.
enum ShareContent {
    enum Item: Equatable {
        case url(URL)
        case text(String)
    }

    /// A card with a link shares the link; otherwise its title and description.
    static func item(for card: Card) -> Item {
        if let url = CardDetailView.firstWebURL(in: [card.content, card.imageURL]) {
            return .url(url)
        }
        return .text(joined([card.title, card.description], separator: "\n\n"))
    }

    /// The collection name and description, then one line per card with its link.
    static func text(for collection: Collection, cards: [Card]) -> String {
        let header = joined([collection.name, collection.description], separator: "\n")
        let lines = cards.map { card -> String in
            if let url = CardDetailView.firstWebURL(in: [card.content, card.imageURL]) {
                return "• \(card.title): \(url.absoluteString)"
            }
            return "• \(card.title)"
        }
        return lines.isEmpty ? header : header + "\n\n" + lines.joined(separator: "\n")
    }

    private static func joined(_ parts: [String], separator: String) -> String {
        parts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: separator)
    }
}

/// Share item for a card: a link with the card title as subject, or plain text.
private struct CardShareButton: View {
    let card: Card

    var body: some View {
        switch ShareContent.item(for: card) {
        case .url(let url):
            ShareLink(item: url, subject: Text(card.title)) { Label("Share", systemImage: "square.and.arrow.up") }
        case .text(let text):
            ShareLink(item: text) { Label("Share", systemImage: "square.and.arrow.up") }
        }
    }
}

/// The round "..." button drawn over a thumbnail's top-right corner.
private struct ThumbnailMenuLabel: View {
    var body: some View {
        Image(systemName: "ellipsis")
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(SphirColor.textPrimary)
            .frame(width: 30, height: 30)
            .background(Circle().fill(SphirColor.cardBackground.opacity(0.92)))
            .overlay(Circle().stroke(SphirColor.border, lineWidth: 1))
            .padding(8)
            .contentShape(Rectangle())
    }
}

/// Card actions: share, edit (add more info), add to collections and delete.
private struct CardActionsModifier: ViewModifier {
    let card: Card
    let menuAlignment: Alignment

    @EnvironmentObject private var appStore: AppStore
    @State private var showEdit = false
    @State private var showCollections = false
    @State private var confirmDelete = false

    /// Only a synced card of a signed-in user can join collections on the API.
    private var canAddToCollections: Bool {
        KeychainService.hasCredentials && card.serverID != nil
    }

    @ViewBuilder
    private var items: some View {
        CardShareButton(card: card)
        Button { showEdit = true } label: { Label("Edit", systemImage: "pencil") }
        if canAddToCollections {
            Button { showCollections = true } label: { Label("Add to collections", systemImage: "rectangle.stack.badge.plus") }
        }
        Button(role: .destructive) { confirmDelete = true } label: { Label("Delete", systemImage: "trash") }
    }

    func body(content: Content) -> some View {
        content
            .contextMenu { items }
            .overlay(alignment: menuAlignment) {
                Menu { items } label: { ThumbnailMenuLabel() }
                    .accessibilityLabel("More actions")
                    .accessibilityIdentifier("cardActionsMenu")
            }
            .sheet(isPresented: $showEdit) {
                EditCardView(card: card).environmentObject(appStore)
            }
            .sheet(isPresented: $showCollections) {
                AddToCollectionsView(card: card).environmentObject(appStore)
            }
            .alert("Delete card?", isPresented: $confirmDelete) {
                Button("Delete", role: .destructive) { appStore.deleteCard(id: card.id) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("“\(card.title)” will be removed. This can't be undone.")
            }
    }
}

/// Collection actions: share the collection as text.
private struct CollectionActionsModifier: ViewModifier {
    let collection: Collection

    @EnvironmentObject private var appStore: AppStore

    @ViewBuilder
    private var items: some View {
        ShareLink(item: ShareContent.text(for: collection, cards: appStore.cards(in: collection.id)),
                  subject: Text(collection.name)) {
            Label("Share", systemImage: "square.and.arrow.up")
        }
    }

    func body(content: Content) -> some View {
        content
            .contextMenu { items }
            .overlay(alignment: .topTrailing) {
                Menu { items } label: { ThumbnailMenuLabel() }
                    .accessibilityLabel("More actions")
                    .accessibilityIdentifier("collectionActionsMenu")
            }
    }
}

extension View {
    /// Adds the card actions menu ("..." button and long press) to a thumbnail;
    /// `menuAlignment` places the "..." button (top-right on tiles, right on rows).
    func cardActions(_ card: Card, menuAlignment: Alignment = .topTrailing) -> some View {
        modifier(CardActionsModifier(card: card, menuAlignment: menuAlignment))
    }

    /// Adds the collection actions menu ("..." button and long press) to a thumbnail.
    func collectionActions(_ collection: Collection) -> some View {
        modifier(CollectionActionsModifier(collection: collection))
    }
}
