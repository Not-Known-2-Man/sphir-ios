//
//  CardDetailView.swift
//  Sphir
//
//  Read-only detail for a single card.
//

import SwiftUI
import UIKit

struct CardDetailView: View {
    /// The card as navigated to; `card` below is its live version (price and
    /// collections change after a sync or "Add to collections").
    private let navigated: Card

    @EnvironmentObject private var appStore: AppStore
    @Environment(\.dismiss) private var dismiss
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
                        Text(card.price)
                            .font(SphirFont.body(22, weight: .bold))
                            .foregroundColor(SphirColor.textPrimary)
                            .accessibilityIdentifier("cardPrice")
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
    private static func firstWebURL(in fields: [String?]) -> URL? {
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

    @ViewBuilder
    private var coverImage: some View {
        if let data = card.imageData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12).stroke(SphirColor.border, lineWidth: 1)
                )
                .accessibilityLabel("Card image")
        } else {
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
                .accessibilityHidden(true)
        }
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
        VStack(alignment: .leading, spacing: 8) {
            Label(card.sourceApp.label, systemImage: card.sourceApp.iconName)
                .accessibilityLabel("Source: \(card.sourceApp.label)")
            Label(DetailDateFormatter.string(from: card.createdAt), systemImage: "calendar")
                .accessibilityLabel("Created \(DetailDateFormatter.string(from: card.createdAt))")
        }
        .font(SphirFont.body(13))
        .foregroundColor(SphirColor.mutedText)
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

    static func string(from date: Date) -> String {
        formatter.string(from: date)
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
