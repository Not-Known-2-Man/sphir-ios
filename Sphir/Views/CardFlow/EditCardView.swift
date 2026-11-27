//
//  EditCardView.swift
//  Sphir
//
//  Edit an existing card's title, description, content, tags, and image.
//

import SwiftUI

struct EditCardView: View {
    let card: Card

    @EnvironmentObject private var appStore: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var descriptionText: String
    @State private var content: String
    @State private var tags: String
    @State private var isPrivate: Bool
    /// JPEG of an image picked here; uploaded when the card is saved.
    @State private var newImage: Data?
    @State private var removesImage = false
    @State private var isSaving = false
    @State private var imageError: String?
    @State private var showSourceDialog = false
    @State private var showLibrary = false
    @State private var showCamera = false
    /// Uploads a JPEG and returns its URL (POST /api/v1/images).
    var uploadImage: (Data) async throws -> String = { try await CardAPIService.uploadImage($0) }

    init(card: Card) {
        self.card = card
        _title = State(initialValue: card.title)
        _descriptionText = State(initialValue: card.description)
        _content = State(initialValue: card.content)
        _tags = State(initialValue: card.tags.joined(separator: ", "))
        _isPrivate = State(initialValue: card.isPrivate)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            FlowModalHeader(title: "Edit Card") { dismiss() }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    imageSection
                    field(label: "Title") {
                        TextField("Card title", text: $title)
                            .textFieldStyle(.plain)
                            .accessibilityIdentifier("editTitleField")
                    }
                    field(label: "Description") {
                        TextField("Add description…", text: $descriptionText, axis: .vertical)
                            .textFieldStyle(.plain)
                            .lineLimit(2...5)
                    }
                    field(label: "Content") {
                        TextField("Content", text: $content, axis: .vertical)
                            .textFieldStyle(.plain)
                            .lineLimit(3...10)
                    }
                    field(label: "Tags") {
                        TextField("Add tags (comma separated)", text: $tags)
                            .textFieldStyle(.plain)
                    }
                    PrivateCardToggle(isPrivate: $isPrivate)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }

            saveButton
        }
        .background(SphirColor.background.ignoresSafeArea())
    }

    // MARK: Image

    private var showsImage: Bool {
        newImage != nil || (!removesImage && (card.imageData != nil || card.imageURL != nil))
    }

    private var imageChanged: Bool { newImage != nil || removesImage }

    private var imageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Image")
                .font(SphirFont.body(13, weight: .semibold))
                .foregroundColor(SphirColor.mutedText)
            imagePreview
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .background(SphirColor.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(SphirColor.border, lineWidth: 1))
            HStack(spacing: 12) {
                Button { showSourceDialog = true } label: {
                    Label(showsImage ? "Change image" : "Add image", systemImage: "photo.badge.plus")
                }
                .accessibilityIdentifier("editChangeImageButton")
                if showsImage {
                    Button(role: .destructive) { newImage = nil; removesImage = true; imageError = nil } label: {
                        Label("Remove image", systemImage: "trash")
                    }
                    .accessibilityIdentifier("editRemoveImageButton")
                }
                if imageChanged {
                    Button { newImage = nil; removesImage = false; imageError = nil } label: { Text("Keep current") }
                        .accessibilityIdentifier("editKeepImageButton")
                }
            }
            .font(SphirFont.body(14, weight: .semibold))
            .foregroundColor(SphirColor.taupe)
            .disabled(isSaving)
            if let imageError {
                Text(imageError)
                    .font(SphirFont.body(13))
                    .foregroundColor(.red)
                    .accessibilityIdentifier("editImageError")
            }
        }
        .confirmationDialog("Card image", isPresented: $showSourceDialog) {
            Button("Choose from library") { showLibrary = true }
            if CameraPicker.isAvailable { Button("Take photo") { showCamera = true } }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showLibrary) {
            PhotoPicker(onPick: { data in picked(data); showLibrary = false }, onCancel: { showLibrary = false })
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(
                onCapture: { image, _ in
                    if let data = image.jpegData(compressionQuality: 0.9) { picked(data) }
                    showCamera = false
                },
                onCancel: { showCamera = false })
                .ignoresSafeArea()
        }
    }

    @ViewBuilder private var imagePreview: some View {
        if let newImage, let image = UIImage(data: newImage) {
            Image(uiImage: image).resizable().scaledToFill()
        } else if showsImage, let data = card.imageData, let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFill()
        } else if showsImage, let urlString = card.imageURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                if let image = phase.image { image.resizable().scaledToFill() } else { ProgressView() }
            }
        } else {
            Image("SphirMark").resizable().scaledToFit().frame(height: 48).accessibilityHidden(true)
        }
    }

    /// A picked photo replaces the shown image; non-image data changes nothing.
    private func picked(_ data: Data) {
        guard let jpeg = ImageCompression.jpegForUpload(data) else {
            imageError = "Couldn't use that image. Try another one."
            return
        }
        newImage = jpeg
        removesImage = false
        imageError = nil
    }

    private func save() {
        guard !isSaving else { return }
        var updated = card
        updated.title = title
        updated.description = descriptionText
        updated.content = content
        updated.isPrivate = isPrivate
        updated.tags = tags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if let newImage {
            // Upload first: if it fails the card keeps its old image and the user sees why.
            isSaving = true
            imageError = nil
            Task {
                do {
                    updated.imageURL = try await uploadImage(newImage)
                    updated.imageData = nil
                    appStore.updateCard(updated, imageChange: .replaced)
                    dismiss()
                } catch {
                    imageError = "Couldn't upload the image, so nothing was saved. Check your connection and try again, or tap Keep current."
                    isSaving = false
                }
            }
        } else if removesImage {
            updated.imageURL = nil
            updated.imageData = nil
            appStore.updateCard(updated, imageChange: .removed)
            dismiss()
        } else {
            appStore.updateCard(updated)
            dismiss()
        }
    }

    @ViewBuilder
    private func field<Content: View>(
        label: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(SphirFont.body(13, weight: .semibold))
                .foregroundColor(SphirColor.mutedText)
            content()
                .font(SphirFont.body(15))
                .foregroundColor(SphirColor.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 12).fill(SphirColor.cardBackground))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(SphirColor.border, lineWidth: 1))
        }
    }

    private var saveButton: some View {
        Button(action: save) {
            Text("Save Changes")
                .font(SphirFont.body(16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(RoundedRectangle(cornerRadius: 22).fill(SphirColor.taupe))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("editSaveButton")
        .disabled(!canSave || isSaving)
        .opacity(canSave && !isSaving ? 1 : 0.5)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(SphirColor.background)
    }
}
