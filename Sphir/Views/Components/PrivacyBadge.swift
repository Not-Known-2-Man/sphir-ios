//
//  PrivacyBadge.swift
//  Sphir
//
//  Small pill showing a collection/group privacy level.
//

import SwiftUI

struct PrivacyBadge: View {
    let privacy: CollectionPrivacy

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: privacy.iconName)
                .font(.system(size: 9))
            Text(privacy.label)
                .font(SphirFont.body(11, weight: .medium))
        }
        .foregroundColor(SphirColor.mutedText)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(SphirColor.cardBackgroundAlt))
        .overlay(Capsule().stroke(SphirColor.border, lineWidth: 1))
    }
}

/// Lock shown on a card the owner keeps private (hidden from others even inside
/// a public collection). Icon only on tiles and rows; `showsLabel` adds the word.
struct CardLockBadge: View {
    var showsLabel = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.fill")
                .font(.system(size: showsLabel ? 10 : 11))
            if showsLabel {
                Text("Private")
                    .font(SphirFont.body(12, weight: .semibold))
            }
        }
        .foregroundColor(SphirColor.mutedText)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Private"))
        .accessibilityIdentifier("cardLockBadge")
    }
}

#Preview {
    VStack(spacing: 12) {
        PrivacyBadge(privacy: .private)
        PrivacyBadge(privacy: .connections)
        PrivacyBadge(privacy: .public)
    }
    .padding()
    .background(SphirColor.background)
}
