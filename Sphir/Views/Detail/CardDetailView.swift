//
//  CardDetailView.swift
//  Sphir
//
//  Read-only detail for a single card.
//

import SwiftUI
import UIKit

struct CardDetailView: View {
    let card: Card

    @Environment(\.dismiss) private var dismiss
    @State private var showReader = false

    /// The card's web URL, if its content is an http(s) link.
    private var webURL: URL? {
        let trimmed = card.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return nil }
        return url
    }

    var body: some View {
        VStack(spacing: 0) {
            DetailTopBar(title: card.cardType.title, backIdentifier: "cardDetailBackButton") { dismiss() }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    syncBadge

                    Text(card.title)
                        .font(SphirFont.heading(24, weight: .bold))
                        .foregroundColor(SphirColor.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    coverImage

                    if let webURL {
                        openInReaderButton(url: webURL)
                    }

                    if !card.description.isEmpty {
                        Text(card.description)
                            .font(SphirFont.body(15))
                            .foregroundColor(SphirColor.mutedText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !card.content.isEmpty {
                        Text(card.content)
                            .font(SphirFont.body(15))
                            .foregroundColor(SphirColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !card.tags.isEmpty {
                        tagCloud
                    }

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
        .fullScreenCover(isPresented: $showReader) {
            if let webURL {
                WebReaderView(url: webURL, fallbackTitle: card.title)
            }
        }
    }

    private func openInReaderButton(url: URL) -> some View {
        Button {
            showReader = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "safari")
                Text("Open in Reader")
            }
            .font(SphirFont.body(16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 22).fill(SphirColor.taupe))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("openInReaderButton")
        .accessibilityHint("Opens the linked page inside Sphir")
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
}
