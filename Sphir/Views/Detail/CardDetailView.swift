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
    @State private var showEdit = false

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

                    if card.isPrivate { CardLockBadge(showsLabel: true) }

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

                    if let row = Self.sourceRowText(for: card) {
                        sourceRow(row)
                    }

                    aboutSection

                    actionButtons(webURL)

                    let memberships = Self.collections(for: card, in: appStore.collections)
                    if !memberships.isEmpty {
                        collectionsSection(memberships)
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
        .sheet(isPresented: $showEdit) {
            EditCardView(card: card)
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

    /// "<site> · <domain>" row under the cover; opens the in-app reader.
    private func sourceRow(_ text: String) -> some View {
        Button {
            showReader = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "link")
                    .font(.system(size: 12, weight: .semibold))
                Text(text)
                    .font(SphirFont.body(14, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
            }
            .foregroundColor(SphirColor.taupe)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Source: \(text)")
        .accessibilityHint("Opens the linked page inside Sphir")
        .accessibilityIdentifier("cardURLLink")
    }

    private func chip(_ text: String, systemImage: String? = nil) -> some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 11, weight: .semibold))
            }
            Text(text).font(SphirFont.body(13, weight: .medium))
        }
        .foregroundColor(SphirColor.taupe)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(SphirColor.taupe.opacity(0.12)))
    }

    private var infoChips: [String] {
        var chips = [CardType.label(for: card.cardType, url: card.content)]
        if !card.price.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { chips.append(card.price) }
        if let published = Self.publishedText(card.published) { chips.append(published) }
        return chips
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About")
                .font(SphirFont.body(13, weight: .semibold))
                .foregroundColor(SphirColor.mutedText)
            if card.description.isEmpty {
                Text(Self.emptyDescriptionHint)
                    .font(SphirFont.body(15))
                    .foregroundColor(SphirColor.mutedText.opacity(0.8))
                    .accessibilityIdentifier("cardDescriptionHint")
            } else {
                Text(card.description)
                    .font(SphirFont.body(15))
                    .foregroundColor(SphirColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            FlowChips(spacing: 8) {
                ForEach(infoChips, id: \.self) { chip($0) }
            }
            .accessibilityIdentifier("cardInfoChips")
        }
    }

    private func collectionsSection(_ collections: [Collection]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("In collections")
                .font(SphirFont.body(13, weight: .semibold))
                .foregroundColor(SphirColor.mutedText)
            FlowChips(spacing: 8) {
                ForEach(collections) { collection in
                    NavigationLink(value: collection) {
                        chip(collection.name, systemImage: "rectangle.stack")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .accessibilityIdentifier("cardCollectionsSection")
    }

    private func actionButtons(_ url: URL?) -> some View {
        VStack(spacing: 10) {
            if url != nil { openInReaderButton }
            HStack(spacing: 10) {
                Group {
                    if let url {
                        ShareLink(item: url) { secondaryLabel("Share", "square.and.arrow.up") }
                    } else {
                        ShareLink(item: card.title) { secondaryLabel("Share", "square.and.arrow.up") }
                    }
                }
                .accessibilityIdentifier("cardShareButton")
                Button { showEdit = true } label: { secondaryLabel("Edit", "pencil") }
                    .accessibilityIdentifier("cardEditButton")
            }
            .buttonStyle(.plain)
        }
    }

    private func secondaryLabel(_ title: LocalizedStringKey, _ icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(title)
        }
        .font(SphirFont.body(16, weight: .semibold))
        .foregroundColor(SphirColor.taupe)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 22).stroke(SphirColor.taupe, lineWidth: 1.5))
    }

    static let emptyDescriptionHint = String(localized: "No description yet. Tap Edit to add one.")

    /// "<site> · <domain>"; just the domain when the site is missing or the same host. Nil without a link.
    static func sourceRowText(for card: Card) -> String? {
        guard let url = firstWebURL(in: [card.content, card.imageURL]),
              let domain = ClipDraft.host(of: url.absoluteString) else { return nil }
        let site = card.site.trimmingCharacters(in: .whitespacesAndNewlines)
        var bare = site.lowercased()
        if bare.hasPrefix("www.") { bare.removeFirst(4) }
        return site.isEmpty || bare == domain ? domain : "\(site) · \(domain)"
    }

    /// "Published Mar 5, 2024" for a valid YYYY-MM-DD, else nil.
    static func publishedText(_ iso: String) -> String? {
        let text = ClipDraft.displayDate(iso, format: "MMM d, yyyy")
        return text.isEmpty ? nil : String(localized: "Published \(text)")
    }

    /// Every collection the card is in (primary collection plus folder ids), in list order.
    static func collections(for card: Card, in all: [Collection]) -> [Collection] {
        all.filter { card.isIn(collectionID: $0.id, serverID: $0.serverID) }
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

    /// Footer: "Saved from Safari · <relative date>".
    static func footerText(for card: Card) -> String {
        let app = card.sourceApp == .safari ? "Safari" : card.sourceApp.label
        let date = DetailDateFormatter.relativeString(from: card.createdAt)
        return String(localized: "Saved from \(app) · \(date)")
    }

    @ViewBuilder
    private var coverImage: some View {
        switch Self.coverSource(for: card) {
        case .localData(let data):
            if let uiImage = UIImage(data: data) {
                coverFrame(Image(uiImage: uiImage).resizable().scaledToFit())
            } else {
                coverPlaceholder()
            }
        case .remoteURL(let url):
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    coverFrame(image.resizable().scaledToFit())
                } else {
                    coverPlaceholder(showsLogo: phase.error != nil)
                }
            }
        case .placeholder:
            coverPlaceholder()
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

    /// A card without an image shows the Sphir mark; while an image loads the cover stays plain.
    private func coverPlaceholder(showsLogo: Bool = true) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(SphirColor.cardBackgroundAlt)
            .frame(height: 180)
            .overlay(
                Image("SphirMark")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .opacity(showsLogo ? 1 : 0)
                    .accessibilityHidden(true)
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

/// Left-aligned layout that wraps chips onto new lines.
struct FlowChips: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(width: bounds.width, subviews: subviews)
        for (index, origin) in result.origins.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
            rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: maxX, height: y + rowHeight), origins)
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
            let timeStr = timeFormatter.string(from: date)
            return String(localized: "Today, \(timeStr)")
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
            Text(LocalizedStringKey(title))
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
