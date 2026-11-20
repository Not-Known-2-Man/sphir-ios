//
//  AddToCollectionsView.swift
//  Sphir
//
//  Multi-select of the user's collections for a saved card (S4, web parity):
//  PUT /api/v1/businesses/:id/folders with the primary collection first.
//

import SwiftUI

struct AddToCollectionsView: View {
    let card: Card

    @EnvironmentObject private var appStore: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var selected: Set<String> = []
    @State private var saving = false
    @State private var errorText: String?

    /// Collections that exist on the API (only those can hold the card).
    private var choices: [Collection] { appStore.collections.filter { ($0.serverID ?? "").isEmpty == false } }

    /// The card's primary collection (API id), if it has one.
    private var primary: String? {
        card.folderServerIDs.first
            ?? appStore.collections.first { $0.id == card.collectionID }?.serverID
    }

    private var current: Set<String> {
        Set(card.folderServerIDs.isEmpty ? [primary].compactMap { $0 } : card.folderServerIDs)
    }

    var body: some View {
        VStack(spacing: 0) {
            FlowModalHeader(title: "Add to collections") { dismiss() }

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(choices) { collection in
                        let sid = collection.serverID ?? ""
                        Button {
                            // The primary collection stays; only extras toggle.
                            guard sid != primary else { return }
                            if selected.contains(sid) { selected.remove(sid) } else { selected.insert(sid) }
                        } label: {
                            HStack {
                                Text(collection.name)
                                    .font(SphirFont.body(15))
                                    .foregroundColor(SphirColor.textPrimary)
                                Spacer()
                                Image(systemName: selected.contains(sid) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(SphirColor.taupe)
                            }
                            .padding(.vertical, 14).padding(.horizontal, 16)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("collectionChoice_\(collection.name)")
                        Divider()
                    }
                }
                .background(RoundedRectangle(cornerRadius: 12).fill(SphirColor.cardBackground))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(SphirColor.border, lineWidth: 1))
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }

            if let errorText {
                Text(errorText).font(SphirFont.body(13)).foregroundColor(.red).padding(.top, 8)
            }

            Button {
                Task { await save() }
            } label: {
                Group {
                    if saving { ProgressView().tint(.white) } else { Text("SAVE") }
                }
                .font(SphirFont.body(16, weight: .bold)).tracking(0.8)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(Capsule().fill(SphirColor.taupe))
            }
            .buttonStyle(.plain)
            .disabled(saving || selected.isEmpty || selected == current)
            .opacity(saving || selected.isEmpty || selected == current ? 0.5 : 1)
            .accessibilityIdentifier("saveCollectionsButton")
            .padding(20)
        }
        .background(SphirColor.background.ignoresSafeArea())
        .onAppear { selected = current }
    }

    private func save() async {
        saving = true
        errorText = nil
        let lead = primary ?? selected.sorted().first ?? ""
        let ids = FolderSelection.compose(
            primary: lead,
            extras: selected,
            order: choices.compactMap(\.serverID))
        if await appStore.setCardCollections(cardID: card.id, folderServerIDs: ids) {
            dismiss()
        } else {
            errorText = "Couldn't update collections. Try again."
        }
        saving = false
    }
}
