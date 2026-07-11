//
//  EditCardView.swift
//  Sphir
//
//  Edit an existing card's title, description, content, and tags.
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

    init(card: Card) {
        self.card = card
        _title = State(initialValue: card.title)
        _descriptionText = State(initialValue: card.description)
        _content = State(initialValue: card.content)
        _tags = State(initialValue: card.tags.joined(separator: ", "))
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            FlowModalHeader(title: "Edit Card") { dismiss() }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
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
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }

            saveButton
        }
        .background(SphirColor.background.ignoresSafeArea())
    }

    private func save() {
        var updated = card
        updated.title = title
        updated.description = descriptionText
        updated.content = content
        updated.tags = tags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        appStore.updateCard(updated)
        dismiss()
    }

    @ViewBuilder
    private func field<Content: View>(
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
        .disabled(!canSave)
        .opacity(canSave ? 1 : 0.5)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(SphirColor.background)
    }
}
