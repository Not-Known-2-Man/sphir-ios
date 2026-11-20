//
//  AddCardView.swift
//  Sphir
//
//  The one-screen "+Card" (S5): a single field for any link (prefilled from
//  the clipboard when it holds one), plus "Photo or screenshot" and "Write
//  your own". A link goes to the same preview card and saved-card screen as
//  the share extension (ClipFlowView, shared from SphirShare).
//

import SwiftUI
import UIKit

struct AddCardView: View {
    @EnvironmentObject private var flow: CardFlowCoordinator
    @EnvironmentObject private var appStore: AppStore

    @State private var linkText = ""
    @FocusState private var linkFocused: Bool

    private var link: String? { AddCardInput.link(from: linkText) }

    var body: some View {
        VStack(spacing: 0) {
            FlowModalHeader(title: "New Card") { flow.dismissAll() }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Paste a link and Sphir fills in the card for you.")
                        .font(SphirFont.body(14))
                        .foregroundColor(SphirColor.mutedText)

                    linkField

                    Button(action: submit) {
                        Text("CLIP LINK")
                            .font(SphirFont.body(16, weight: .bold)).tracking(0.8)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(Capsule().fill(SphirColor.taupe))
                    }
                    .buttonStyle(.plain)
                    .disabled(link == nil)
                    .opacity(link == nil ? 0.5 : 1)
                    .accessibilityIdentifier("clipLinkButton")

                    Text("or")
                        .font(SphirFont.body(13))
                        .foregroundColor(SphirColor.mutedText)
                        .frame(maxWidth: .infinity)

                    CardOptionRow(
                        emoji: "🖼️",
                        title: "Photo or screenshot",
                        subtitle: "Pick one and extract its text",
                        identifier: "addCardPhotoButton"
                    ) { flow.openPhoto() }

                    CardOptionRow(
                        emoji: "✍️",
                        title: "Write your own",
                        subtitle: "Your own note, no link needed",
                        identifier: "addCardWriteButton"
                    ) { flow.openWrite() }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(SphirColor.background.ignoresSafeArea())
        .onAppear(perform: prefillFromClipboard)
        // Preview card -> saved card (shared with the extension).
        .fullScreenCover(item: $flow.clipLink) { clip in
            ClipScreen(url: clip.url, store: appStore, flow: flow)
        }
        // "Write your own".
        .fullScreenCover(isPresented: $flow.showForm) {
            CardFormView()
                .environmentObject(flow)
                .environmentObject(appStore)
        }
        // Photo or screenshot + OCR.
        .fullScreenCover(isPresented: $flow.showScreenshotForm) {
            ScreenshotCardView()
                .environmentObject(flow)
                .environmentObject(appStore)
        }
    }

    private var linkField: some View {
        HStack(spacing: 10) {
            TextField("Paste a link", text: $linkText)
                .textFieldStyle(.plain)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.go)
                .focused($linkFocused)
                .onSubmit(submit)
                .accessibilityIdentifier("cardURLField")

            Button {
                if let pasted = UIPasteboard.general.string { linkText = pasted.trimmingCharacters(in: .whitespacesAndNewlines) }
            } label: {
                Text("Paste")
                    .font(SphirFont.body(14, weight: .semibold))
                    .foregroundColor(SphirColor.taupe)
            }
            .accessibilityIdentifier("pasteLinkButton")
        }
        .font(SphirFont.body(15))
        .foregroundColor(SphirColor.textPrimary)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 12).fill(SphirColor.cardBackground))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(SphirColor.border, lineWidth: 1))
    }

    private func submit() {
        guard link != nil else { return }
        linkFocused = false
        flow.openLink(linkText)
    }

    /// Only reads the clipboard when iOS says it holds a URL (no paste prompt otherwise).
    private func prefillFromClipboard() {
        guard linkText.isEmpty, UIPasteboard.general.hasURLs,
              let url = UIPasteboard.general.url?.absoluteString,
              let clean = AddCardInput.link(from: url) else { return }
        linkText = clean
    }
}

/// The shared clip flow hosted in the app for a pasted link.
private struct ClipScreen: View {
    @ObservedObject var flow: CardFlowCoordinator
    @StateObject private var model: ClipFlowModel

    init(url: String, store: AppStore, flow: CardFlowCoordinator) {
        self.flow = flow
        _model = StateObject(wrappedValue: ClipFlowModel(
            content: SharedContent(urlString: url),
            sharedCollections: AppStore.sharedCollections(from: store.collections),
            inApp: true,
            queue: { store.addClipCard($0) }))
    }

    var body: some View {
        ClipFlowView(
            model: model,
            onCrop: nil,
            onView: { id in
                if let id { flow.viewCard(id: id) } else { flow.dismissAll() }
            },
            onDismiss: { flow.dismissAll() },
            onCancel: { flow.clipLink = nil }
        )
    }
}

#Preview {
    AddCardView()
        .environmentObject(CardFlowCoordinator())
        .environmentObject(AppStore())
}
