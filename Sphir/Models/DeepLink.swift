//
//  DeepLink.swift
//  Sphir
//
//  Parses Sphir deep links and universal links into a routable target.
//
//  Supported forms:
//    sphir://card/<uuid>            sphir://collection/<uuid>
//    https://sphir.io/card/<uuid>   https://sphir.io/collection/<uuid>
//

import Foundation

enum DeepLink: Equatable {
    case card(UUID)
    case collection(UUID)

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

        guard let kind, let idString, let id = UUID(uuidString: idString) else { return nil }

        switch kind.lowercased() {
        case "card":       self = .card(id)
        case "collection": self = .collection(id)
        default:           return nil
        }
    }
}

extension Card {
    var deepLinkURL: URL? { URL(string: "sphir://card/\(id.uuidString)") }
}

extension Collection {
    var deepLinkURL: URL? { URL(string: "sphir://collection/\(id.uuidString)") }
}
