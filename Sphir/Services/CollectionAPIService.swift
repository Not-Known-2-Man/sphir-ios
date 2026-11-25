//
//  CollectionAPIService.swift
//  Sphir
//
//  Folders API → Collection model.
//

import Foundation

/// Decodes an id that the API may send as either a number or a string.
struct FlexibleID: Decodable, Hashable {
    let value: String
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) {
            value = String(int)
        } else if let string = try? container.decode(String.self) {
            value = string
        } else {
            value = ""
        }
    }
}

struct FolderDTO: Decodable {
    let id: FlexibleID?
    let name: String?
    let description: String?
    let privacy: String?
    let isDefault: Bool?

    private enum CodingKeys: String, CodingKey {
        case id, name, description, privacy
        case isDefault = "is_default"
    }

    func toCollection() -> Collection {
        Collection(
            name: name ?? "Untitled",
            description: description ?? "",
            cardCount: 0,
            privacy: CollectionPrivacy(rawValue: privacy ?? "") ?? .private,
            serverID: id?.value,
            isDefault: isDefault ?? false
        )
    }
}

private struct FolderRequest: Encodable {
    let name: String
    let description: String
    let privacy: String
}

enum CollectionAPIService {
    /// GET /api/v1/folders
    static func fetchCollections() async throws -> [Collection] {
        let dtos: [FolderDTO] = try await NetworkService.shared.request("/api/v1/folders")
        return dtos.map { $0.toCollection() }
    }

    /// POST /api/v1/folders — returns the created folder (with its server id).
    static func createCollection(name: String, description: String, privacy: String) async throws -> Collection {
        let dto: FolderDTO = try await NetworkService.shared.request(
            "/api/v1/folders",
            method: .post,
            body: FolderRequest(name: name, description: description, privacy: privacy)
        )
        return dto.toCollection()
    }

    /// DELETE /api/v1/folders/{id}
    static func deleteCollection(serverID: String) async throws {
        _ = try await NetworkService.shared.request(
            "/api/v1/folders/\(serverID)",
            method: .delete
        ) as EmptyResponse
    }
}
