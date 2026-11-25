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

        case .collectionServerID:
            if let collection = Self.collection(for: link, in: store.collections) {
                path = NavigationPath()
                path.append(collection)
            } else {
                // Not imported yet: sync, then retry (like a card server id).
                Task {
                    await store.syncFromAPI()
                    if let collection = Self.collection(for: link, in: store.collections) {
                        path = NavigationPath()
                        path.append(collection)
                    }
                }
            }

        case .card, .cardServerID:
            if let card = Self.card(for: link, in: store.cards) {
                open(card, store: store)
            } else if case .cardServerID = link {
                // Saved online by the extension: the app has not imported it yet.
                Task {
                    await store.syncFromAPI()
                    if let card = Self.card(for: link, in: store.cards) { open(card, store: store) }
                }
            }
        }
    }

    /// The local card a link points to (by local UUID or by API id), if any.
    nonisolated static func card(for link: DeepLink, in cards: [Card]) -> Card? {
        switch link {
        case .card(let id):             return cards.first { $0.id == id }
        case .cardServerID(let sid):    return cards.first { $0.serverID == sid }
        case .collection, .collectionServerID: return nil
        }
    }

    /// The local collection a link points to (by local UUID or by API id), if any.
    nonisolated static func collection(for link: DeepLink, in collections: [Collection]) -> Collection? {
        switch link {
        case .collection(let id):            return collections.first { $0.id == id }
        case .collectionServerID(let sid):   return collections.first { $0.serverID == sid }
        case .card, .cardServerID:           return nil
        }
    }

    private func open(_ card: Card, store: AppStore) {
        path = NavigationPath()
        // Push the owning collection first so "back" is natural.
        if let collectionID = card.collectionID,
           let collection = store.collections.first(where: { $0.id == collectionID }) {
            path.append(collection)
        }
        path.append(card)
    }
}
