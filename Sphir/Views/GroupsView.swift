//
//  GroupsView.swift
//  Sphir
//
//  Grid of "Sphirs" (groups) shown under the Groups tab.
//

import SwiftUI

struct GroupsView: View {
    let groups: [SphirGroup]

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(groups) { group in
                GroupCardView(group: group)
            }
        }
    }
}

struct GroupCardView: View {
    let group: SphirGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PrivacyBadge(privacy: group.privacy)

            Circle()
                .fill(Color(hex: group.colorHex))
                .frame(width: 60, height: 60)
                .overlay(
                    Text(initials)
                        .font(SphirFont.body(20, weight: .bold))
                        .foregroundColor(.white)
                )

            Text(group.name)
                .font(SphirFont.body(15, weight: .bold))
                .foregroundColor(SphirColor.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12).fill(SphirColor.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12).stroke(SphirColor.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    /// First letters of the group name for the icon monogram.
    private var initials: String {
        let words = group.name.split(separator: " ").prefix(2)
        return words.compactMap { $0.first.map(String.init) }.joined().uppercased()
    }
}

#Preview {
    GroupsView(groups: SphirGroup.mockGroups)
        .padding()
        .background(SphirColor.background)
}
