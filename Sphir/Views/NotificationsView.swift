//
//  NotificationsView.swift
//  Sphir
//
//  Notifications placeholder — currently an empty state.
//

import SwiftUI

struct NotificationsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            FlowModalHeader(title: "Notifications") { dismiss() }

            Spacer()

            EmptyStateView(
                icon: "bell",
                title: "No new notifications",
                message: "You're all caught up. Updates about your cards and collections will show up here."
            )

            Spacer()
        }
        .background(SphirColor.background.ignoresSafeArea())
    }
}

#Preview {
    NotificationsView()
}
