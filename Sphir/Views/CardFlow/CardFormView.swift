//
//  CardFormView.swift
//  Sphir
//
//  Step 3 of the "+Card" flow: fill in card details and save.
//

import SwiftUI

struct CardFormView: View {
    @EnvironmentObject private var flow: CardFlowCoordinator
    @EnvironmentObject private var appStore: AppStore

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var urlText: String = ""
    @State private var tags: String = ""
    @State private var selectedCollectionID: UUID?
    @State private var showSuccess = false

    private var canSave: Bool {
        !title.isEmpty && selectedCollectionID != nil
    }

    private var showsURLField: Bool {
        flow.selectedSource == .url
    }

    private var selectedCollection: Collection? {
        appStore.collections.first { $0.id == selectedCollectionID }
    }

    /// Build the card from the form + flow selections and file it away.
    private func save() {
        appStore.addCard(
            title: title,
            description: description,
            urlText: urlText,
            tagsText: tags,
            type: flow.selectedType ?? .text,
            source: flow.selectedSource ?? .photos,
            collectionID: selectedCollectionID ?? appStore.collections.first?.id
        )
        showSuccess = true
    }

    var body: some View {
        ZStack {
            SphirColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                navBar

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        syncStrip

                        formField(label: "Title") {
                            TextField("Card title", text: $title)
                                .textFieldStyle(.plain)
                                .accessibilityIdentifier("cardTitleField")
                        }

                        formField(label: "Description") {
                            TextField("Add description...", text: $description, axis: .vertical)
                                .textFieldStyle(.plain)
                                .lineLimit(3...6)
                        }

                        if showsURLField {
                            formField(label: "URL") {
                                TextField("https://...", text: $urlText)
                                    .textFieldStyle(.plain)
                                    .keyboardType(.URL)
                                    .autocapitalization(.none)
                            }
                        }

                        formField(label: "Tags") {
                            TextField("Add tags (comma separated)", text: $tags)
                                .textFieldStyle(.plain)
                        }

                        collectionPicker

                        coverImageField
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
        }
        .onChange(of: appStore.collections) { _, newCollections in
            if selectedCollectionID == nil {
                selectedCollectionID = newCollections.first?.id
            }
        }
    }

    // MARK: - Collection Picker

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
                .background(
                    RoundedRectangle(cornerRadius: 12).fill(SphirColor.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12).stroke(SphirColor.border, lineWidth: 1)
                )
            }
            .accessibilityIdentifier("collectionPicker")
        }
    }

    // MARK: - Navigation Bar

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

    // MARK: - Sync Strip

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
        .background(
            Capsule().fill(SphirColor.success.opacity(0.12))
        )
    }

    // MARK: - Field Helpers

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
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(SphirColor.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(SphirColor.border, lineWidth: 1)
                )
        }
    }

    private var coverImageField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cover Image")
                .font(SphirFont.body(13, weight: .semibold))
                .foregroundColor(SphirColor.mutedText)

            Button {
                print("Add Image tapped")
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "photo")
                    Text("Add Image")
                        .font(SphirFont.body(15, weight: .medium))
                }
                .foregroundColor(SphirColor.mutedText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(SphirColor.cardBackgroundAlt)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            SphirColor.border,
                            style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Bottom Done Button

    private var doneButton: some View {
        Button {
            save()
        } label: {
            Text("Done")
                .font(SphirFont.body(16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(SphirColor.taupe)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("formDoneButton")
        .disabled(!canSave)
        .opacity(canSave ? 1 : 0.5)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(SphirColor.background)
    }
}

#Preview {
    let flow = CardFlowCoordinator()
    flow.selectedType = .text
    flow.selectedSource = .url
    return CardFormView()
        .environmentObject(flow)
        .environmentObject(AppStore())
}
