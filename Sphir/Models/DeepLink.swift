//
//  DeepLink.swift
//  Sphir
//
//  Parses Sphir deep links and universal links into a routable target.
//
//  Supported forms:
//    sphir://card/<uuid>            sphir://collection/<uuid>
//    sphir://card/<server id>       (a card the app has not imported yet)
//    sphir://collection/<server id>
//    https://sphir.io/card/<uuid>   https://sphir.io/collection/<uuid>
//

import Foundation

enum DeepLink: Equatable {
    case card(UUID)
    /// A card by its API id (e.g. just saved from the share extension).
    case cardServerID(String)
    case collection(UUID)
    /// A collection by its API id (e.g. opened from the share extension).
    case collectionServerID(String)

    init?(url: URL) {
        let kind: String?
        let idString: String?

        switch url.scheme?.lowercased() {
        case "sphir":
            // Custom scheme: host is the kind, first path component is the id.
            kind = url.host
            idString = url.pathComponents.first { $0 != "/" }
        case "http", "https":
            // Universal link on the sphir.io domain.
            guard let host = url.host, host == "sphir.io" || host.hasSuffix(".sphir.io") else {
                return nil
            }
            let components = url.pathComponents.filter { $0 != "/" }
            kind = components.first
            idString = components.dropFirst().first
        default:
            return nil
        }

        guard let kind, let idString else { return nil }

        guard let id = UUID(uuidString: idString) else {
            // Cards and collections can be addressed by server id.
            guard Self.isServerID(idString) else { return nil }
            switch kind.lowercased() {
            case "card":       self = .cardServerID(idString)
            case "collection": self = .collectionServerID(idString)
            default:           return nil
            }
            return
        }

        switch kind.lowercased() {
        case "card":       self = .card(id)
        case "collection": self = .collection(id)
        default:           return nil
        }
    }
}

extension DeepLink {
    /// API ids are integers; nothing else is routable by server id.
    fileprivate static func isServerID(_ s: String) -> Bool {
        !s.isEmpty && s.count <= 20 && s.unicodeScalars.allSatisfy { $0.value >= 48 && $0.value <= 57 }
    }
}

extension Card {
    var deepLinkURL: URL? { URL(string: "sphir://card/\(id.uuidString)") }

    /// Link to a card by its API id, for cards saved online by the extension.
    static func deepLinkURL(serverID: String) -> URL? { URL(string: "sphir://card/\(serverID)") }
}

extension Collection {
    var deepLinkURL: URL? { URL(string: "sphir://collection/\(id.uuidString)") }
}

extension Collection {
    /// Link to a collection by its API id.
    static func deepLinkURL(serverID: String) -> URL? { URL(string: "sphir://collection/\(serverID)") }
}
