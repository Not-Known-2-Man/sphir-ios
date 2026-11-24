//
//  CardDetailView.swift
//  Sphir
//
//  Read-only detail for a single card.
//

import SwiftUI
import UIKit

/// The source of cover image to render for a card.
enum CoverSource: Equatable {
    case localData(Data)
    case remoteURL(URL)
    case placeholder
}

struct CardDetailView: View {
    /// The card as navigated to; `card` below is its live version (price and
    /// collections change after a sync or "Add to collections").
    private let navigated: Card

    @EnvironmentObject private var appStore: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var showReader = false
    @State private var showCollections = false

    init(card: Card) { navigated = card }

    private var card: Card { appStore.cards.first { $0.id == navigated.id } ?? navigated }

    /// Only a card that exists on the API can be filed in more collections.
    private var canAddToCollections: Bool {
        KeychainService.hasCredentials && card.serverID != nil
    }

    /// The card's web URL, checking every field that might hold one.
    /// (There is no `metadata.sourceURL` on `Card`; the link lives in
    /// `content`, with `imageURL` as a secondary source.)
    private var webURL: URL? {
        Self.firstWebURL(in: [card.content, card.imageURL])
    }

    var body: some View {
        VStack(spacing: 0) {
            DetailTopBar(title: CardType.isInstagramReel(card.content) && card.cardType == .social ? CardType.label(for: card.cardType, url: card.content) : card.cardType.title, backIdentifier: "cardDetailBackButton") { dismiss() }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    syncBadge

                    Text(card.title)
                        .font(SphirFont.heading(24, weight: .bold))
                        .foregroundColor(SphirColor.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    coverImage

                    if !card.price.isEmpty {
                        HStack(spacing: 12) {
                            Text(card.price)
                                .font(SphirFont.body(22, weight: .bold))
                                .foregroundColor(SphirColor.textPrimary)
                                .accessibilityIdentifier("cardPrice")

                            if Self.canBuyNow(card), let webURL {
                                Button {
                                    openURL(webURL)
                                } label: {
                                    Text("BUY NOW!")
                                        .font(SphirFont.body(12, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(Capsule().fill(SphirColor.taupe))
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("buyNowButton")
                                .accessibilityHint("Opens store page to purchase this item")
                            }
                        }
                    }

                    // Reader entry point: below the image, above the description.
                    if let webURL {
                        openInReaderButton
                        urlLink(webURL)
                    }

                    if !card.description.isEmpty {
                        Text(card.description)
                            .font(SphirFont.body(15))
                            .foregroundColor(SphirColor.mutedText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Only show the raw content when it isn't just the URL
                    // (which is already shown as a link above).
                    if !card.content.isEmpty, webURL == nil {
                        Text(card.content)
                            .font(SphirFont.body(15))
                            .foregroundColor(SphirColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !card.tags.isEmpty {
                        tagCloud
                    }

                    if canAddToCollections { addToCollectionsButton }

                    metadata
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
        .sheet(isPresented: $showCollections) {
            AddToCollectionsView(card: card)
                .environmentObject(appStore)
        }
        .fullScreenCover(isPresented: $showReader) {
            if let webURL {
                WebReaderView(url: webURL, fallbackTitle: card.title)
            }
        }
    }

    private var addToCollectionsButton: some View {
        Button {
            showCollections = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.stack.badge.plus")
                Text("Add to collections")
            }
            .font(SphirFont.body(16, weight: .semibold))
            .foregroundColor(SphirColor.taupe)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(SphirColor.taupe, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("addToCollectionsButton")
    }

    private var openInReaderButton: some View {
        Button {
            showReader = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "safari")
                Text("Open in Reader")
            }
            .font(SphirFont.body(16, weight: .semibold))
            .foregroundColor(.white)                        // #ffffff
            .frame(maxWidth: .infinity)                      // full-width
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 22)           // pill, radius 22
                    .fill(SphirColor.taupe)                  // taupe
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("openInReaderButton")
        .accessibilityHint("Opens the linked page inside Sphir")
    }

    /// The URL shown as a tappable link (opens the in-app reader).
    private func urlLink(_ url: URL) -> some View {
        Button {
            showReader = true
        } label: {
            Text(url.absoluteString)
                .font(SphirFont.body(13))
                .foregroundColor(SphirColor.taupe)
                .underline()
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("cardURLLink")
    }

    /// Returns the first field that looks like a web URL, adding an https
    /// scheme to bare domains (e.g. "apple.com").
    static func firstWebURL(in fields: [String?]) -> URL? {
        for case let value? in fields {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            if let url = URL(string: trimmed),
               let scheme = url.scheme?.lowercased(),
               scheme == "http" || scheme == "https" {
                return url
            }
            // Bare domain like "apple.com" or "www.apple.com/path".
            if trimmed.contains("."), !trimmed.contains(" "),
               let url = URL(string: "https://\(trimmed)"), url.host != nil {
                return url
            }
        }
        return nil
    }

    private var syncBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: card.syncStatus.iconName)
                .font(.system(size: 11, weight: .bold))
            Text(card.syncStatus.label)
                .font(SphirFont.body(12, weight: .semibold))
        }
        .foregroundColor(card.syncStatus.color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(card.syncStatus.color.opacity(0.12)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sync status: \(card.syncStatus.label)")
    }

    /// Remote cover (the card's og_image) for cards synced from the API, which have no
    /// local image data. Forced to https because App Transport Security blocks http.
    static func remoteCoverURL(for card: Card) -> URL? {
        ClipDraft.httpsURL(card.imageURL).flatMap(URL.init(string:))
    }

    /// Chooses which cover image representation to show: local data, remote URL, or placeholder.
    static func coverSource(for card: Card) -> CoverSource {
        if let data = card.imageData, !data.isEmpty {
            return .localData(data)
        }
        if let url = remoteCoverURL(for: card) {
            return .remoteURL(url)
        }
        return .placeholder
    }

    /// Determines if a card came from a web link.
    static func isLinkCard(_ card: Card) -> Bool {
        card.sourceApp == .safari || firstWebURL(in: [card.content, card.imageURL]) != nil
    }

    /// Determines if a product card has a price and link to show BUY NOW!
    static func canBuyNow(_ card: Card) -> Bool {
        card.cardType == .product &&
        !card.price.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        firstWebURL(in: [card.content, card.imageURL]) != nil
    }

    /// Formatted footer text matching Figma: "Safari · Added <date>".
    static func footerText(for card: Card) -> String {
        let app = card.sourceApp == .safari ? "Safari" : card.sourceApp.label
        return "\(app) · Added \(DetailDateFormatter.relativeString(from: card.createdAt))"
    }

    @ViewBuilder
    private var coverImage: some View {
        switch Self.coverSource(for: card) {
        case .localData(let data):
            if let uiImage = UIImage(data: data) {
                coverFrame(Image(uiImage: uiImage).resizable().scaledToFit())
            } else {
                coverPlaceholder
            }
        case .remoteURL(let url):
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    coverFrame(image.resizable().scaledToFit())
                } else {
                    coverPlaceholder
                }
            }
        case .placeholder:
            coverPlaceholder
        }
    }

    private var clippedBadge: some View {
        Text("CLIPPED")
            .font(SphirFont.body(10, weight: .bold).smallCaps())
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.black.opacity(0.6)))
            .padding(10)
            .accessibilityLabel("Clipped")
            .accessibilityIdentifier("clippedBadge")
    }

    private func coverFrame(_ image: some View) -> some View {
        image
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12).stroke(SphirColor.border, lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                if Self.isLinkCard(card) {
                    clippedBadge
                }
            }
            .accessibilityLabel("Card image")
    }

    private var coverPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(SphirColor.cardBackgroundAlt)
            .frame(height: 180)
            .overlay(
                Image(systemName: "photo")
                    .font(.system(size: 32))
                    .foregroundColor(SphirColor.lightTaupe)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(SphirColor.border, lineWidth: 1)
            )
            .overlay(alignment: .topTrailing) {
                if Self.isLinkCard(card) {
                    clippedBadge
                }
            }
            .accessibilityHidden(true)
    }

    private var tagCloud: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags")
                .font(SphirFont.body(13, weight: .semibold))
                .foregroundColor(SphirColor.mutedText)

            HStack(spacing: 8) {
                ForEach(card.tags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(SphirFont.body(13, weight: .medium))
                        .foregroundColor(SphirColor.taupe)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(SphirColor.taupe.opacity(0.12)))
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tags: \(card.tags.joined(separator: ", "))")
    }

    private var metadata: some View {
        HStack(spacing: 6) {
            Image(systemName: card.sourceApp == .safari ? "safari" : card.sourceApp.iconName)
                .font(.system(size: 13))
            Text(Self.footerText(for: card))
                .font(SphirFont.body(13))
        }
        .foregroundColor(SphirColor.mutedText)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.footerText(for: card))
        .accessibilityIdentifier("cardFooterRow")
    }
}

/// Shared abbreviated date formatting for detail screens.
enum DetailDateFormatter {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }

    static func relativeString(from date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Today, \(timeFormatter.string(from: date))"
        } else {
            return string(from: date)
        }
    }
}

/// Reusable back/title bar for detail screens.
struct DetailTopBar: View {
    let title: String
    var backIdentifier: String = "detailBackButton"
    let onBack: () -> Void

    var body: some View {
        ZStack {
            Text(title)
                .font(SphirFont.body(17, weight: .semibold))
                .foregroundColor(SphirColor.textPrimary)
                .accessibilityAddTraits(.isHeader)

            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(SphirFont.body(16, weight: .semibold))
                    .foregroundColor(SphirColor.taupe)
                }
                .accessibilityIdentifier(backIdentifier)
                .accessibilityLabel("Back")
                .accessibilityHint("Returns to the previous screen")
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            SphirColor.background
                .overlay(
                    Rectangle().fill(SphirColor.border).frame(height: 1),
                    alignment: .bottom
                )
        )
    }
}

#Preview {
    NavigationStack {
        CardDetailView(card: Card.samples(for: Collection.mockCollections[0])[0])
    }
    .environmentObject(AppStore())
}
