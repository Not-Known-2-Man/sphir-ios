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

#Preview {
    VStack(spacing: 12) {
        PrivacyBadge(privacy: .private)
        PrivacyBadge(privacy: .connections)
        PrivacyBadge(privacy: .public)
    }
    .padding()
    .background(SphirColor.background)
}
