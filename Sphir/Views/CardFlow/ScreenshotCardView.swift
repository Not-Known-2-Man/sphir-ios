//
//  ScreenshotCardView.swift
//  Sphir
//
//  Screenshot + OCR flow: pick a screenshot, extract its text with Vision,
//  auto-fill an editable card, and save it (image + text) to a collection.
//

import SwiftUI

struct ScreenshotCardView: View {
    @EnvironmentObject private var flow: CardFlowCoordinator
    @EnvironmentObject private var appStore: AppStore

    @State private var image: UIImage?
    @State private var imageData: Data?
    @State private var title: String = ""
    @State private var content: String = ""
    @State private var isProcessing = false
    @State private var showPicker = false
    @State private var showSuccess = false
    @State private var selectedCollectionID: UUID?
    @State private var didStart = false

    private var selectedCollection: Collection? {
        appStore.collections.first { $0.id == selectedCollectionID }
    }

    private var canSave: Bool {
        image != nil && !isProcessing && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            SphirColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                navBar

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        syncStrip
                        imagePreview

                        if isProcessing {
                            extracting
                        } else if image != nil {
                            formField(label: "Title") {
                                TextField("Card title", text: $title)
                                    .textFieldStyle(.plain)
                            }
                            formField(label: "Extracted Text") {
                                TextField("Extracted text will appear here…", text: $content, axis: .vertical)
                                    .textFieldStyle(.plain)
                                    .lineLimit(4...12)
                            }
                            collectionPicker
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }

                doneButton
            }
        }
        .overlay {
            if showSuccess {
                SuccessView(
                    onAddAnother: {
                        showSuccess = false
                        flow.addAnother()
                    },
                    onDismissAll: {
                        showSuccess = false
                        flow.dismissAll()
                    }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showSuccess)
        .sheet(isPresented: $showPicker) {
            ScreenshotPicker(
                onPick: handlePick,
                onCancel: {
                    showPicker = false
                    // Backed out without choosing anything → leave the flow.
                    if image == nil { flow.dismissAll() }
                }
            )
            .ignoresSafeArea()
        }
        .onAppear {
            guard !didStart else { return }
            didStart = true
            selectedCollectionID = appStore.collections.first?.id
            showPicker = true
        }
    }

    // MARK: - Actions

    private func handlePick(_ picked: UIImage) {
        showPicker = false
        image = picked
        imageData = downscaledJPEG(picked)
        isProcessing = true
        Task {
            let text = await OCRService.recognizeText(in: picked)
            content = text
            title = firstLine(of: text)
            isProcessing = false
        }
    }

    private func save() {
        appStore.addScreenshotCard(
            title: title,
            content: content,
            imageData: imageData,
            collectionID: selectedCollectionID
        )
        showSuccess = true
    }

    private func firstLine(of text: String) -> String {
        let line = text
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init) ?? ""
        return line.isEmpty ? "Screenshot" : String(line.prefix(80))
    }

    private func downscaledJPEG(_ image: UIImage, maxDimension: CGFloat = 1200) -> Data? {
        let longest = max(image.size.width, image.size.height)
        let target: UIImage
        if longest > maxDimension, longest > 0 {
            let scale = maxDimension / longest
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            target = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        } else {
            target = image
        }
        return target.jpegData(compressionQuality: 0.7)
    }

    // MARK: - Subviews

    private var navBar: some View {
        ZStack {
            Text("Screenshot")
                .font(SphirFont.body(17, weight: .semibold))
                .foregroundColor(SphirColor.textPrimary)

            HStack {
                Button {
                    flow.dismissAll()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(SphirColor.textPrimary)
                }
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

    private var syncStrip: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
            Text("Saved locally")
                .font(SphirFont.body(12, weight: .semibold))
        }
        .foregroundColor(SphirColor.success)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(SphirColor.success.opacity(0.12)))
    }

    @ViewBuilder
    private var imagePreview: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(maxHeight: 260)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(SphirColor.border, lineWidth: 1))
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(SphirColor.cardBackgroundAlt)
                .frame(height: 200)
                .overlay(
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 32))
                        .foregroundColor(SphirColor.lightTaupe)
                )
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(SphirColor.border, lineWidth: 1))
        }
    }

    private var extracting: some View {
        HStack(spacing: 10) {
            ProgressView().tint(SphirColor.taupe)
            Text("Extracting text…")
                .font(SphirFont.body(15, weight: .medium))
                .foregroundColor(SphirColor.mutedText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    @ViewBuilder
    private func formField<Content: View>(
        label: String,
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

    private var collectionPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Collection")
                .font(SphirFont.body(13, weight: .semibold))
                .foregroundColor(SphirColor.mutedText)

            Menu {
                ForEach(appStore.collections) { collection in
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
                        .font(SphirFont.body(15))
                        .foregroundColor(selectedCollection == nil ? SphirColor.mutedText : SphirColor.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(SphirColor.mutedText)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 12).fill(SphirColor.cardBackground))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(SphirColor.border, lineWidth: 1))
            }
        }
    }

    private var doneButton: some View {
        Button {
            save()
        } label: {
            Text("Save")
                .font(SphirFont.body(16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(RoundedRectangle(cornerRadius: 22).fill(SphirColor.taupe))
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
        .opacity(canSave ? 1 : 0.5)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(SphirColor.background)
    }
}
