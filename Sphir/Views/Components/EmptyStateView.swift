//
//  EmptyStateView.swift
//  Sphir
//
//  Friendly placeholder shown when a list or search has no content.
//

import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(SphirColor.lightTaupe)
                .accessibilityHidden(true)

            Text(title)
                .font(SphirFont.body(16, weight: .semibold))
                .foregroundColor(SphirColor.textPrimary)

            Text(message)
                .font(SphirFont.body(13))
                .foregroundColor(SphirColor.mutedText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .padding(.vertical, 40)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    EmptyStateView(
        icon: "tray",
        title: "Nothing here yet",
        message: "Content you add will show up here."
    )
    .background(SphirColor.background)
}
