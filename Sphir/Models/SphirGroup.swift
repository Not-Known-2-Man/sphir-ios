//
//  SphirGroup.swift
//  Sphir
//
//  A "Sphir" — a shared group. Named SphirGroup to avoid colliding
//  with SwiftUI's `Group` view.
//

import Foundation

struct SphirGroup: Identifiable, Hashable {
    let id: UUID
    var name: String
    var colorHex: String
    var privacy: CollectionPrivacy

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String,
        privacy: CollectionPrivacy = .public
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.privacy = privacy
    }
}

extension SphirGroup {
    /// Mock groups shown under the "Groups" tab.
    static let mockGroups: [SphirGroup] = [
        SphirGroup(name: "Caregiver Burnout & Self-Care", colorHex: "#1E6B7A", privacy: .public),
        SphirGroup(name: "Nutrition & Healthy Living", colorHex: "#2D8636", privacy: .public),
        SphirGroup(name: "Dementia & Memory Care", colorHex: "#3B8B8B", privacy: .connections),
        SphirGroup(name: "Rockets", colorHex: "#1a1612", privacy: .public),
        SphirGroup(name: "All Things Canning", colorHex: "#E85A5A", privacy: .connections),
        SphirGroup(name: "Wellness", colorHex: "#1a1612", privacy: .private)
    ]
}
