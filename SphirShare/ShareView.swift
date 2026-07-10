//
//  ShareView.swift
//  SphirShare
//
//  "Save to Sphir" share sheet. Handles two kinds of shared content:
//   - a web URL (Safari) → fetches title, og:description, and thumbnail
//   - text (Mail body / Messages) → captures the body text
//

import SwiftUI

/// What the extension extracted from the host.
struct SharedContent {
    var urlString: String?
    var text: String?

    var isLink: Bool { !(urlString ?? "").isEmpty }
}

/// What the user confirmed in the sheet, handed back for saving.
struct SharePayload {
    let collectionID: UUID?
    let title: String
    let description: String
    let urlString: String?
    let bodyText: String?
    let imageData: Data?
}

struct ShareView: View {
    let content: SharedContent
    let collections: [SharedCollectionDTO]
    let onSave: (SharePayload) -> Void
    let onCancel: () -> Void

    @State private var selectedCollectionID: UUID?
    @State private var title: String = ""
    @State private var descriptionText: String = ""
    @State private var imageData: Data?
    @State private var isLoadingMetadata = false

    private var selectedCollection: SharedCollectionDTO? {
        collections.first { $0.id == selectedCollectionID }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Save to Sphir")
                    .font(ShareFont.heading(18, weight: .bold))
                    .foregroundColor(ShareColor.textPrimary)

                if content.isLink {
                    linkPreview
                } else {
                    textPreview
                }

                titleField

                if content.isLink {
                    descriptionField
                }

                collectionPicker
                buttons
            }
            .padding(20)
            .background(RoundedRectangle(cornerRadius: 12).fill(ShareColor.background))
            .padding(.horizontal, 24)
        }
        .task {
            if selectedCollectionID == nil {
                selectedCollectionID = collections.first?.id
            }
            await prepare()
        }
    }

    // MARK: - Preparation

    private func prepare() async {
        if content.isLink, let urlString = content.urlString {
            isLoadingMetadata = true
            let metadata = await MetadataService.fetch(urlString: urlString)
            if let fetchedTitle = metadata?.title, !fetchedTitle.isEmpty {
                title = fetchedTitle
            }
            if let fetchedDescription = metadata?.description {
                descriptionText = fetchedDescription
            }
            imageData = metadata?.imageData
            isLoadingMetadata = false
        } else if let text = content.text {
            // Text share: seed the title from the first non-empty line.
            let firstLine = text
                .split(whereSeparator: \.isNewline)
                .first
                .map(String.init) ?? ""
            title = firstLine.isEmpty ? "Shared Text" : String(firstLine.prefix(80))
        }
    }

    // MARK: - Link Preview

    private var linkPreview: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(ShareColor.cardBackgroundAlt)
                    .frame(height: 140)

                if let imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else if isLoadingMetadata {
                    ProgressView().tint(ShareColor.taupe)
                } else {
                    Image(systemName: "link")
                        .font(.system(size: 28))
                        .foregroundColor(ShareColor.mutedText)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(ShareColor.border, lineWidth: 1))

            HStack(spacing: 8) {
                Image(systemName: "link").foregroundColor(ShareColor.mutedText)
                Text(content.urlString ?? "")
                    .font(ShareFont.body(12))
                    .foregroundColor(ShareColor.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Text Preview

    private var textPreview: some View {
        ScrollView {
            Text(content.text ?? "")
                .font(ShareFont.body(13))
                .foregroundColor(ShareColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 120)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(ShareColor.cardBackgroundAlt))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(ShareColor.border, lineWidth: 1))
    }

    // MARK: - Fields

    private var titleField: some View {
        HStack {
            if isLoadingMetadata && title.isEmpty {
                ProgressView().tint(ShareColor.taupe)
                Text("Fetching title…")
                    .font(ShareFont.body(15))
                    .foregroundColor(ShareColor.mutedText)
                Spacer()
            } else {
                TextField("Title", text: $title)
                    .font(ShareFont.body(15, weight: .semibold))
                    .foregroundColor(ShareColor.textPrimary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(ShareColor.cardBackground))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(ShareColor.border, lineWidth: 1))
    }

    private var descriptionField: some View {
        TextField("Description", text: $descriptionText, axis: .vertical)
            .font(ShareFont.body(13))
            .foregroundColor(ShareColor.mutedText)
            .lineLimit(2...4)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12).fill(ShareColor.cardBackground))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(ShareColor.border, lineWidth: 1))
    }

    private var collectionPicker: some View {
        Menu {
            ForEach(collections) { collection in
                Button {
                    selectedCollectionID = collection.id
                } label: {
                    if collection.id == selectedCollectionID {
                        Label(collection.name, systemImage: "checkmark")
                    } else {
                        Text(collection.name)
                    }
                }
            }
        } label: {
            HStack {
                Text(selectedCollection?.name ?? "Select a collection")
                    .font(ShareFont.body(15))
                    .foregroundColor(selectedCollection == nil ? ShareColor.mutedText : ShareColor.textPrimary)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12))
                    .foregroundColor(ShareColor.mutedText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12).fill(ShareColor.cardBackground))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(ShareColor.border, lineWidth: 1))
        }
    }

    private var buttons: some View {
        HStack(spacing: 12) {
            Button(action: onCancel) {
                Text("Cancel")
                    .font(ShareFont.body(16, weight: .semibold))
                    .foregroundColor(ShareColor.taupe)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 22)
                            .fill(ShareColor.cardBackground)
                            .overlay(RoundedRectangle(cornerRadius: 22).stroke(ShareColor.taupe, lineWidth: 1))
                    )
            }

            Button {
                onSave(
                    SharePayload(
                        collectionID: selectedCollectionID,
                        title: title,
                        description: descriptionText,
                        urlString: content.urlString,
                        bodyText: content.text,
                        imageData: imageData
                    )
                )
            } label: {
                Text("Save")
                    .font(ShareFont.body(16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 22).fill(ShareColor.taupe))
            }
        }
    }
}
