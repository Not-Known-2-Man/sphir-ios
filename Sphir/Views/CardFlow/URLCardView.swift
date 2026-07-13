//
//  URLCardView.swift
//  Sphir
//
//  "Paste URL" flow: enter a link, auto-fetch its metadata (title,
//  og:description, thumbnail), edit, and save as a card.
//

import SwiftUI

struct URLCardView: View {
    @EnvironmentObject private var flow: CardFlowCoordinator
    @EnvironmentObject private var appStore: AppStore

    @State private var urlText: String = ""
    @State private var title: String = ""
    @State private var descriptionText: String = ""
    @State private var imageData: Data?
    @State private var isFetching = false
    @State private var fetchFailed = false
    @State private var showSuccess = false
    @State private var selectedCollectionID: UUID?
    @State private var fetchTask: Task<Void, Never>?

    private var selectedCollection: Collection? {
        appStore.collections.first { $0.id == selectedCollectionID }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            SphirColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                navBar

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        syncStrip
                        urlField

                        if imageData != nil {
                            imagePreview
                        }

                        formField(label: "Title") {
                            TextField("Card title", text: $title)
                                .textFieldStyle(.plain)
                                .accessibilityIdentifier("cardTitleField")
                        }

                        formField(label: "Description") {
                            TextField("Add description…", text: $descriptionText, axis: .vertical)
                                .textFieldStyle(.plain)
                                .lineLimit(2...6)
                        }

                        collectionPicker
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
        .onAppear {
            if selectedCollectionID == nil {
                selectedCollectionID = appStore.collections.first?.id
            }
            // If the URL is pre-filled (e.g. pasted before appearing), fetch.
            if !urlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                scheduleFetch(urlText)
            }
        }
    }

    // MARK: - Actions

    /// Debounced fetch as the user types or pastes.
    private func scheduleFetch(_ value: String) {
        fetchTask?.cancel()
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 4, trimmed.contains(".") else { return }
        fetchTask = Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            if Task.isCancelled { return }
            await fetchMetadata()
        }
    }

    /// Fetch immediately (e.g. on keyboard "Go").
    private func fetchNow() {
        fetchTask?.cancel()
        fetchTask = Task { await fetchMetadata() }
    }

    private func fetchMetadata() async {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let normalized = trimmed.contains("://") ? trimmed : "https://\(trimmed)"

        isFetching = true
        fetchFailed = false
        let metadata = await MetadataService.fetch(urlString: normalized)
        if let fetchedTitle = metadata?.title, !fetchedTitle.isEmpty {
            title = fetchedTitle
        }
        if let fetchedDescription = metadata?.description, !fetchedDescription.isEmpty {
            descriptionText = fetchedDescription
        }
        if let fetchedImage = metadata?.imageData {
            imageData = fetchedImage
        }
        // No usable metadata came back — likely offline or a blocked page.
        fetchFailed = (metadata?.title == nil && metadata?.imageData == nil && metadata?.description == nil)
        isFetching = false
    }

    private func save() {
        // Store a fully-qualified URL so the card's content is a valid link
        // (a bare "apple.com" would otherwise be saved without a scheme).
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.isEmpty ? ""
            : (trimmed.contains("://") ? trimmed : "https://\(trimmed)")

        appStore.addCard(
            title: title,
            description: descriptionText,
            urlText: normalized,
            tagsText: "",
            type: .text,
            source: .url,
            collectionID: selectedCollectionID,
            imageData: imageData
        )
        showSuccess = true
    }

    // MARK: - Subviews

    private var navBar: some View {
        ZStack {
            Text("New Card")
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

                Button {
                    save()
                } label: {
                    Text("Done")
                        .font(SphirFont.body(16, weight: .semibold))
                        .foregroundColor(canSave ? SphirColor.taupe : SphirColor.mutedText)
                }
                .disabled(!canSave)
                .accessibilityIdentifier("navDoneButton")
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

    private var urlField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("URL")
                .font(SphirFont.body(13, weight: .semibold))
                .foregroundColor(SphirColor.mutedText)

            HStack(spacing: 8) {
                TextField("https://…", text: $urlText)
                    .textFieldStyle(.plain)
                    .font(SphirFont.body(15))
                    .foregroundColor(SphirColor.textPrimary)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .accessibilityIdentifier("cardURLField")
                    .onSubmit { fetchNow() }
                    .onChange(of: urlText) { _, newValue in
                        scheduleFetch(newValue)
                    }

                if isFetching {
                    ProgressView()
                        .tint(SphirColor.taupe)
                        .accessibilityLabel("Fetching link details")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12).fill(SphirColor.cardBackground))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(SphirColor.border, lineWidth: 1))

            if fetchFailed {
                Text("Could not fetch page info. Check your connection.")
                    .font(SphirFont.body(11))
                    .foregroundColor(SphirColor.taupe)
            } else {
                Text("We'll fetch the page title, description, and image automatically.")
                    .font(SphirFont.body(11))
                    .foregroundColor(SphirColor.mutedText)
            }
        }
    }

    private var imagePreview: some View {
        Group {
            if let imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(SphirColor.border, lineWidth: 1))
            }
        }
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
