//
//  SuccessView.swift
//  Sphir
//
//  Step 4 of the "+Card" flow: confirmation overlay after saving.
//

import SwiftUI

struct SuccessView: View {
    /// Rewind to Step 1 to create another card.
    let onAddAnother: () -> Void
    /// Collapse the flow back to the dashboard.
    let onDismissAll: () -> Void

    var body: some View {
        ZStack {
            SphirColor.background.ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .foregroundColor(SphirColor.success)

                Text("Card Saved!")
                    .font(SphirFont.heading(24, weight: .bold))
                    .foregroundColor(SphirColor.textPrimary)

                Text("Added to your collection")
                    .font(SphirFont.body(14))
                    .foregroundColor(SphirColor.mutedText)

                VStack(spacing: 12) {
                    Button(action: onAddAnother) {
                        Text("Add Another")
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

                    Button(action: onDismissAll) {
                        Text("Back to Dashboard")
                            .font(SphirFont.body(16, weight: .semibold))
                            .foregroundColor(SphirColor.taupe)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 22)
                                    .fill(SphirColor.cardBackground)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 22)
                                            .stroke(SphirColor.taupe, lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("backToDashboardButton")
                }
                .padding(.top, 24)
                .padding(.horizontal, 40)
            }
        }
        .task {
            // Auto-dismiss after 3 seconds. Cancelled automatically if the
            // overlay is removed first (e.g. the user taps a button).
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            onDismissAll()
        }
    }
}

#Preview {
    SuccessView(onAddAnother: {}, onDismissAll: {})
}
