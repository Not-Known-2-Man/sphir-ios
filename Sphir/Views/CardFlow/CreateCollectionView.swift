//
//  CreateCollectionView.swift
//  Sphir
//
//  "+Collection" flow: a single modal to name a collection, choose its
//  privacy, and confirm. On success the dashboard grid reflects it.
//

import SwiftUI

struct CreateCollectionView: View {
    @EnvironmentObject private var appStore: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var privacy: CollectionPrivacy = .private
    @State private var showSuccess = false

    var body: some View {
        ZStack {
            SphirColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                FlowModalHeader(title: "New Collection") {
                    dismiss()
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        field(label: "Title") {
                            TextField("Collection title", text: $name)
                                .textFieldStyle(.plain)
                                .accessibilityIdentifier("collectionTitleField")
                        }

                        field(label: "Description") {
                            TextField("Add description...", text: $description, axis: .vertical)
                                .textFieldStyle(.plain)
                                .lineLimit(3...6)
                        }

                        privacyPicker
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 24)
                }

                continueButton
            }
        }
        .overlay {
            if showSuccess {
                successOverlay
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showSuccess)
    }

    // MARK: - Privacy Picker

    private var privacyPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Privacy")
                .font(SphirFont.body(13, weight: .semibold))
                .foregroundColor(SphirColor.mutedText)

            Picker("Privacy", selection: $privacy) {
                ForEach(CollectionPrivacy.allCases, id: \.self) { level in
                    Text(level.label).tag(level)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Continue Button

    private var continueButton: some View {
        Button {
            appStore.addCollection(name: name, description: description, privacy: privacy)
            showSuccess = true
        } label: {
            Text("Continue")
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
        .accessibilityIdentifier("collectionContinueButton")
        .disabled(name.isEmpty)
        .opacity(name.isEmpty ? 0.5 : 1)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(SphirColor.background)
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        ZStack {
            SphirColor.background.ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .foregroundColor(SphirColor.success)

                Text("Collection Created!")
                    .font(SphirFont.heading(24, weight: .bold))
                    .foregroundColor(SphirColor.textPrimary)

                Text("Added to your collections")
                    .font(SphirFont.body(14))
                    .foregroundColor(SphirColor.mutedText)
            }
        }
        .task {
            // Briefly show confirmation, then return to the dashboard.
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            dismiss()
        }
    }

    // MARK: - Field Helper

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
}

#Preview {
    CreateCollectionView()
        .environmentObject(AppStore())
}
