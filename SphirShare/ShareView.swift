//
//  ShareView.swift
//  SphirShare
//
//  SwiftUI UI for the "Save to Sphir" share sheet. Fetches rich link
//  metadata (title + thumbnail) while the user picks a collection.
//

import SwiftUI

struct ShareView: View {
    let urlString: String?
    let collections: [SharedCollectionDTO]
    /// (collectionID, title, description, imageData)
    let onSave: (UUID?, String, String, Data?) -> Void
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

                preview
                titleField
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
            await fetchMetadata()
        }
    }

    // MARK: - Metadata

    private func fetchMetadata() async {
        guard let urlString else { return }
        isLoadingMetadata = true
        let metadata = await MetadataService.fetch(urlString: urlString)
        if let fetchedTitle = metadata?.title, !fetchedTitle.isEmpty {
            title = fetchedTitle
        }
        imageData = metadata?.imageData
        isLoadingMetadata = false
    }

    // MARK: - Preview (image + URL)

    private var preview: some View {
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
                    ProgressView()
                        .tint(ShareColor.taupe)
                } else {
                    Image(systemName: "link")
                        .font(.system(size: 28))
                        .foregroundColor(ShareColor.mutedText)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(ShareColor.border, lineWidth: 1))

            HStack(spacing: 8) {
                Image(systemName: "link")
                    .foregroundColor(ShareColor.mutedText)
                Text(urlString ?? "No link found")
                    .font(ShareFont.body(12))
                    .foregroundColor(urlString == nil ? ShareColor.mutedText : ShareColor.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
            }
        }
    }

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
                onSave(selectedCollectionID, title, descriptionText, imageData)
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
