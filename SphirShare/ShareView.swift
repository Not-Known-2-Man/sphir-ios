//
//  ShareView.swift
//  SphirShare
//
//  SwiftUI UI for the "Save to Sphir" share sheet.
//

import SwiftUI

struct ShareView: View {
    let urlString: String?
    let collections: [SharedCollectionDTO]
    let onSave: (UUID?) -> Void
    let onCancel: () -> Void

    @State private var selectedCollectionID: UUID?

    private var selectedCollection: SharedCollectionDTO? {
        collections.first { $0.id == selectedCollectionID }
    }

    var body: some View {
        ZStack {
            // Dimmed backdrop.
            Color.black.opacity(0.45).ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Save to Sphir")
                    .font(ShareFont.heading(18, weight: .bold))
                    .foregroundColor(ShareColor.textPrimary)

                urlPreview
                collectionPicker

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
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 22)
                                            .stroke(ShareColor.taupe, lineWidth: 1)
                                    )
                            )
                    }

                    Button {
                        onSave(selectedCollectionID)
                    } label: {
                        Text("Save")
                            .font(ShareFont.body(16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 22)
                                    .fill(ShareColor.taupe)
                            )
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(ShareColor.background)
            )
            .padding(.horizontal, 24)
        }
        .onAppear {
            if selectedCollectionID == nil {
                selectedCollectionID = collections.first?.id
            }
        }
    }

    private var urlPreview: some View {
        HStack(spacing: 8) {
            Image(systemName: "link")
                .foregroundColor(ShareColor.mutedText)
            Text(urlString ?? "No link found")
                .font(ShareFont.body(13))
                .foregroundColor(urlString == nil ? ShareColor.mutedText : ShareColor.textPrimary)
                .lineLimit(2)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(ShareColor.cardBackgroundAlt))
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
}
