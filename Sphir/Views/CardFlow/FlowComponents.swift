//
//  FlowComponents.swift
//  Sphir
//
//  Reusable pieces shared across the "+Card" flow steps.
//

import SwiftUI

/// Header row for a flow modal: centered title with a trailing close button.
struct FlowModalHeader: View {
    let title: LocalizedStringKey
    let onClose: () -> Void

    init(title: LocalizedStringKey, onClose: @escaping () -> Void) {
        self.title = title
        self.onClose = onClose
    }

    var body: some View {
        ZStack {
            Text(title)
                .font(SphirFont.heading(18, weight: .bold))
                .foregroundColor(SphirColor.textPrimary)
                .accessibilityAddTraits(.isHeader)

            HStack {
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(SphirColor.mutedText)
                }
                .accessibilityLabel("Close")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }
}

/// Full-width selectable row: emoji, title + subtitle, trailing chevron.
struct CardOptionRow: View {
    let emoji: String
    let title: String
    let subtitle: String
    var minHeight: CGFloat = 64
    var identifier: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(emoji)
                    .font(.system(size: 24))

                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(title))
                        .font(SphirFont.body(15, weight: .semibold))
                        .foregroundColor(SphirColor.textPrimary)
                    Text(LocalizedStringKey(subtitle))
                        .font(SphirFont.body(12))
                        .foregroundColor(SphirColor.mutedText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(SphirColor.mutedText)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(SphirColor.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(SphirColor.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier ?? title)
    }
}

/// "Private card" lock switch shared by the create and edit forms.
struct PrivateCardToggle: View {
    @Binding var isPrivate: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $isPrivate) {
                Label("Private card", systemImage: "lock.fill")
                    .font(SphirFont.body(15, weight: .semibold))
                    .foregroundColor(SphirColor.textPrimary)
            }
            .tint(SphirColor.taupe)
            .accessibilityIdentifier("privateCardToggle")
            Text("Only you can see it. Unlock it to share it in a public collection.")
                .font(SphirFont.body(12))
                .foregroundColor(SphirColor.mutedText)
        }
    }
}
