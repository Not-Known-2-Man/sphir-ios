//
//  ClipLogic.swift
//  Sphir
//
//  Pure logic behind the three-tap clip flow, shared by SphirShare and the
//  app's +Card screen (Foundation only; compiled into the app, for tests, and
//  into the extension).
//

import Foundation

// MARK: - What the host handed us / what we queue

struct SharedContent {
    var urlString: String?
    var text: String?
    var sharedImageData: Data?
    /// Cleaned <head> + JSON-LD of the page Safari already loaded (ClipPreprocess.js).
    var pageHTML: String?

    var isLink: Bool { !(urlString ?? "").isEmpty }
    var isImage: Bool { sharedImageData != nil }
}

struct SharePayload {
    let collectionID: UUID?
    let title: String
    let description: String
    let urlString: String?
    let bodyText: String?
    let imageData: Data?
    let tags: [String]
    /// Set by the clip flow so a queued clip keeps what the preview showed.
    var cardTypeRaw: String? = nil
    var price: String? = nil
    var imageURL: String? = nil
}

// MARK: - Safari preprocessing result

/// The page Safari already loaded: its URL plus a small HTML document made of
/// the cleaned <head> and every JSON-LD block (see SphirShare/ClipPreprocess.js).
/// POSTed to /api/v1/preview so sites that block server fetches still work.
struct PageSnapshot: Equatable {
    let url: String
    let html: String

    /// Stay well under the API's 2mb JSON body limit.
    static let maxHTMLBytes = 1_500_000
    private static let maxHeadBytes = 600_000
    private static let resultsKey = "NSExtensionJavaScriptPreprocessingResultsKey"

    /// Accepts the dictionary delivered by the extension item provider (wrapped
    /// under NSExtensionJavaScriptPreprocessingResultsKey) or the bare result.
    static func parse(_ raw: Any?) -> PageSnapshot? {
        guard let outer = raw as? [String: Any] else { return nil }
        let result = (outer[resultsKey] as? [String: Any]) ?? outer
        guard let urlString = (result["url"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              url.host?.isEmpty == false else { return nil }

        let head = truncate((result["head"] as? String) ?? "", toBytes: maxHeadBytes)
        var scripts: [String] = []
        var used = head.utf8.count + 64
        for block in (result["jsonld"] as? [String]) ?? [] {
            let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let script = #"<script type="application/ld+json">"# + trimmed + "</script>"
            guard used + script.utf8.count <= maxHTMLBytes else { continue }
            scripts.append(script)
            used += script.utf8.count
        }
        guard !head.isEmpty || !scripts.isEmpty else { return PageSnapshot(url: urlString, html: "") }
        let html = "<!doctype html><html>" + (head.isEmpty ? "<head></head>" : head)
            + "<body>" + scripts.joined() + "</body></html>"
        return PageSnapshot(url: urlString, html: html)
    }

    private static func truncate(_ s: String, toBytes limit: Int) -> String {
        guard s.utf8.count > limit else { return s }
        var out = ""
        var bytes = 0
        for ch in s {
            bytes += String(ch).utf8.count
            if bytes > limit { break }
            out.append(ch)
        }
        return out
    }
}

// MARK: - Preview -> card

/// What the preview card shows and what Save Card sends.
struct ClipDraft: Equatable {
    var url: String
    var title: String
    var description: String
    var imageURL: String?
    var type: CardType
    var tags: [String]
    var price: String
    var site: String
    var published: String

    init(preview: LinkPreview, fallbackURL: String) {
        // The stored card (already on Sphir) only fills what the page lacks.
        let stored = preview.alreadyOnSphir
        url = preview.url.isEmpty ? fallbackURL : preview.url
        title = preview.title.isEmpty ? (stored?.title ?? "") : preview.title
        description = preview.description
        imageURL = Self.httpURL(preview.image) ?? Self.httpURL(stored?.image ?? "")
        type = CardType(previewType: preview.type)
        tags = Self.cleanTags(preview.tags)
        price = preview.price.isEmpty ? (stored?.price ?? "") : preview.price
        site = preview.site.isEmpty ? (Self.host(of: url) ?? "") : preview.site
        published = preview.published
    }

    /// On-device fallback (not signed in, offline, API error): type from domain
    /// rules only; nothing is invented.
    init(fallbackURL: String, title: String = "", description: String = "", imageURL: String? = nil) {
        url = fallbackURL
        self.title = title
        self.description = description
        self.imageURL = Self.httpsURL(imageURL)
        type = Self.typeFromDomain(url: fallbackURL)
        tags = []
        price = ""
        site = Self.host(of: fallbackURL) ?? ""
        published = ""
    }

    var typeLabel: String { CardType.label(for: type, url: url) }

    /// "site · February 11, 2026" (either part may be missing).
    var sourceLine: String {
        [site, Self.displayDate(published)].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    func card(collectionID: UUID? = nil) -> Card {
        Card(title: title.isEmpty ? (site.isEmpty ? "Untitled" : site) : title,
             description: description, content: url, cardType: type, sourceApp: .safari,
             imageURL: imageURL, price: price, tags: tags, collectionID: collectionID)
    }

    /// What goes to the offline queue when the card cannot be created online.
    func payload(collectionID: UUID?, imageData: Data?) -> SharePayload {
        SharePayload(collectionID: collectionID, title: card().title, description: description,
                     urlString: url, bodyText: nil, imageData: imageData, tags: tags,
                     cardTypeRaw: type.rawValue, price: price.isEmpty ? nil : price, imageURL: imageURL)
    }

    func request(folderServerID: String?) -> BusinessRequest {
        BusinessRequest(card: card(), folderServerID: folderServerID,
                        price: price.isEmpty ? nil : price)
    }

    // MARK: Helpers

    /// Same domain rules as the API (S8), without any page data.
    static func typeFromDomain(url: String) -> CardType {
        guard let u = URL(string: url), let host = host(of: url) else { return .text }
        func on(_ domains: String...) -> Bool { domains.contains { host == $0 || host.hasSuffix("." + $0) } }
        if on("youtube.com", "youtu.be", "vimeo.com", "tiktok.com") { return .video }
        if on("instagram.com") {
            let path = u.path.lowercased()
            return path.hasPrefix("/reel/") || path.hasPrefix("/p/") ? .social : .text
        }
        if on("x.com", "twitter.com", "facebook.com", "threads.net") { return .social }
        return .text
    }

    static func host(of url: String) -> String? {
        guard var host = URL(string: url)?.host?.lowercased(), !host.isEmpty else { return nil }
        if host.hasPrefix("www.") { host.removeFirst(4) }
        return host
    }

    /// iOS ATS blocks http images: upgrade to https, drop anything else.
    static func httpsURL(_ s: String?) -> String? {
        guard let s else { return nil }
        if s.hasPrefix("https://") { return s }
        if s.hasPrefix("http://") { return "https://" + s.dropFirst(7) }
        return nil
    }

    private static func httpURL(_ s: String) -> String? {
        s.hasPrefix("http://") || s.hasPrefix("https://") ? s : nil
    }

    private static func cleanTags(_ tags: [String]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for raw in tags {
            let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !t.isEmpty, !t.hasPrefix("_"), seen.insert(t.lowercased()).inserted else { continue }
            out.append(t)
        }
        return Array(out.prefix(8))
    }

    private static func displayDate(_ iso: String) -> String {
        let input = DateFormatter()
        input.locale = Locale(identifier: "en_US_POSIX")
        input.timeZone = TimeZone(identifier: "UTC")
        input.dateFormat = "yyyy-MM-dd"
        guard let date = input.date(from: iso) else { return "" }
        let output = DateFormatter()
        output.locale = Locale(identifier: "en_US_POSIX")
        output.timeZone = TimeZone(identifier: "UTC")
        output.dateFormat = "MMMM d, yyyy"
        return output.string(from: date)
    }
}

// MARK: - Save path

enum ClipSavePath: Equatable {
    case online(folderServerID: String)
    case queue(QueueReason)

    enum QueueReason: Equatable {
        case signedOut, noCollection, failed

        var message: String {
            self == .signedOut ? ClipSavePath.signInMessage : ClipSavePath.queuedMessage
        }
    }

    static let signInMessage = "Sign in to Sphir to clip"
    static let queuedMessage = "Saved — it will sync when you open Sphir"

    static func choose(signedIn: Bool, folderServerID: String?) -> ClipSavePath {
        guard signedIn else { return .queue(.signedOut) }
        guard let id = folderServerID, !id.isEmpty else { return .queue(.noCollection) }
        return .online(folderServerID: id)
    }

    static func queueReason(after error: Error) -> QueueReason {
        if case NetworkError.unauthorized = error { return .signedOut }
        return .failed
    }
}

// MARK: - Collections

/// A collection in the extension's picker. `serverID` is the API folder id;
/// `localID` is the app's collection UUID (used when the card goes to the queue).
struct ClipCollection: Identifiable, Hashable {
    let name: String
    let serverID: String?
    let localID: UUID?
    var id: String { serverID ?? localID?.uuidString ?? name }

    /// Server folders (signed in) matched to the collections the app published
    /// to the App Group: by server id first, then by name (older snapshots).
    /// Folders without a server id are skipped.
    static func pickerList(folders: [Collection], shared: [SharedCollectionDTO]) -> [ClipCollection] {
        folders.compactMap { folder in
            guard let sid = folder.serverID, !sid.isEmpty else { return nil }
            let local = shared.first { $0.serverID == sid }
                ?? shared.first { $0.serverID == nil && $0.name.caseInsensitiveCompare(folder.name) == .orderedSame }
            return ClipCollection(name: folder.name, serverID: sid, localID: local?.id)
        }
    }

    /// The collections the app published, used when the folder list cannot be
    /// fetched: they keep their server id, so an online save still works.
    static func fromShared(_ shared: [SharedCollectionDTO]) -> [ClipCollection] {
        shared.map { ClipCollection(name: $0.name, serverID: $0.serverID, localID: $0.id) }
    }
}

enum FolderSelection {
    /// `folder_ids` for PUT /businesses/:id/folders: the primary first, then
    /// the extras in collection order; deduped, no empty ids.
    static func compose(primary: String, extras: Set<String>, order: [String]) -> [String] {
        var out = primary.isEmpty ? [] : [primary]
        let wanted = extras.filter { !$0.isEmpty && $0 != primary }
        for id in order where wanted.contains(id) && !out.contains(id) { out.append(id) }
        for id in wanted.sorted() where !out.contains(id) { out.append(id) }
        return out
    }

    /// Adds or removes an extra collection; the primary is never an extra.
    static func toggle(_ id: String, primary: String, extras: Set<String>) -> Set<String> {
        var next = extras
        if id == primary { return next }
        if next.contains(id) { next.remove(id) } else { next.insert(id) }
        return next
    }

    /// The AI's suggestion wins when it is one of the user's collections, then
    /// the last used one, then the first.
    static func preselect(suggested: String? = nil, lastUsed: String?, available: [String]) -> String? {
        if let suggested, available.contains(suggested) { return suggested }
        if let lastUsed, available.contains(lastUsed) { return lastUsed }
        return available.first
    }
}

/// The collection chips on the preview card: several can be selected, the
/// first selected one is the primary (the card is created in it).
enum CollectionSelection {
    /// Adds `id` at the end, or removes it; the last selected one stays.
    static func toggle(_ id: String, in selected: [String]) -> [String] {
        guard let index = selected.firstIndex(of: id) else { return selected + [id] }
        guard selected.count > 1 else { return selected }
        var next = selected
        next.remove(at: index)
        return next
    }

    static func primary(of selected: [String]) -> String? { selected.first }

    /// After "+ New collection": the new collection is the selection (and so
    /// the card's primary collection).
    static func afterCreate(id: String) -> [String] { [id] }
}

/// The name typed for "New collection".
enum NewCollectionName {
    enum Result: Equatable {
        case invalid
        /// A collection with this name (case-insensitive) is at this index of `existing`.
        case existing(Int)
        case create(String)
    }

    static func resolve(_ typed: String, existing: [String]) -> Result {
        let name = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return .invalid }
        if let index = existing.firstIndex(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
            return .existing(index)
        }
        return .create(name)
    }
}

// MARK: - +Card input

enum AddCardInput {
    /// A routable http(s) link from pasted or typed text, or nil. A bare domain
    /// ("apple.com", "www.apple.com/mac") gets "https://".
    static func link(from text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty,
              trimmed.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else { return nil }
        let full = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard let url = URL(string: full), let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host, host.contains("."),
              let tld = host.split(separator: ".").last, tld.count >= 2,
              tld.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" }) else { return nil }
        return full
    }
}
