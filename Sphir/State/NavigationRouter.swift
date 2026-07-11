//
//  NavigationRouter.swift
//  Sphir
//
//  Drives the dashboard's navigation stack, including deep-link routing.
//

import SwiftUI
import Combine

@MainActor
final class NavigationRouter: ObservableObject {
    @Published var path = NavigationPath()

    /// Route an incoming deep link / universal link to the right detail
    /// screen, using the store to resolve the target object.
    func handle(_ url: URL, store: AppStore) {
        guard let link = DeepLink(url: url) else { return }

        switch link {
        case .collection(let id):
            guard let collection = store.collections.first(where: { $0.id == id }) else { return }
            path = NavigationPath()
            path.append(collection)

        case .card(let id):
            guard let card = store.cards.first(where: { $0.id == id }) else { return }
            path = NavigationPath()
            // Push the owning collection first so "back" is natural.
            if let collectionID = card.collectionID,
               let collection = store.collections.first(where: { $0.id == collectionID }) {
                path.append(collection)
            }
            path.append(card)
        }
    }
}
