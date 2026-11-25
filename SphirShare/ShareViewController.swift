//
//  ShareViewController.swift
//  SphirShare
//
//  Principal class for the share extension. Extracts a shared web URL and/or
//  text, hosts the SwiftUI ShareView, and enqueues a card to the App Group.
//
//  Note: iOS does not tell an extension which app invoked it, nor does it
//  expose structured Mail subject/sender fields. We extract whatever the host
//  provides: a web URL (→ link card) and/or text (→ text card, e.g. a Mail
//  body or Messages text, links included inline).
//

import UIKit
import SwiftUI
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {

    private var content = SharedContent()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        Task {
            self.content = await loadSharedContent()
            self.presentShareUI()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Set initial dark background to hide Safari Share Sheet
        updateBackground(for: .options)
    }

    private func updateBackground(for screen: ExtensionScreen) {
        let targetColor = UIColor.black.withAlphaComponent(0.85)
        
        view.backgroundColor = targetColor
        var current: UIView? = view
        while let parent = current?.superview {
            parent.backgroundColor = targetColor
            current = parent
        }
    }

    private func presentShareUI() {
        let stored = SharedInbox.loadCollections()
        let collections = stored.isEmpty ? SharedInbox.fallbackCollections : stored

        let root = ShareRoot(
            content: content,
            collections: collections,
            storedCollections: stored,
            onSave: { [weak self] payload in
                self?.save(payload) ?? UUID()
            },
            onUpdateCollection: { cardID, newCollectionID in
                SharedInbox.updateCollection(forCardID: cardID, newCollectionID: newCollectionID)
            },
            onScreenChange: { [weak self] screen in
                self?.updateBackground(for: screen)
            },
            onView: { [weak self] cardID in
                self?.openCard(cardID)
            },
            onViewCollection: { [weak self] collectionID in
                self?.openCollection(collectionID)
            },
            onOpenApp: { [weak self] in
                self?.openApp()
            },
            onDismiss: { [weak self] in
                self?.finish()
            },
            onCancel: { [weak self] in
                self?.cancel()
            }
        )

        let host = UIHostingController(rootView: root)
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        host.view.backgroundColor = .clear
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }

    // MARK: - Content Extraction

    private func loadSharedContent() async -> SharedContent {
        var urlString: String?
        var text: String?
        var sharedImageData: Data?
        var snapshot: PageSnapshot?

        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            return SharedContent()
        }

        for item in items {
            // The host-provided text (e.g. a Mail body or Messages selection).
            if text == nil, let attributed = item.attributedContentText?.string,
               !attributed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                text = attributed
            }

            for provider in item.attachments ?? [] {
                if snapshot == nil,
                   provider.hasItemConformingToTypeIdentifier(UTType.propertyList.identifier) {
                    snapshot = await loadPageSnapshot(provider)
                }
                if urlString == nil,
                   provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    urlString = await loadWebURL(provider)
                } else if text == nil,
                           provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    text = await loadText(provider)
                } else if sharedImageData == nil,
                           provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    sharedImageData = await loadImage(provider)
                }
            }
        }

        if urlString == nil { urlString = snapshot?.url }
        let html = snapshot?.html
        return SharedContent(urlString: urlString, text: text, sharedImageData: sharedImageData,
                             pageHTML: (html?.isEmpty ?? true) ? nil : html)
    }

    /// The result of ClipPreprocess.js (Safari only).
    private func loadPageSnapshot(_ provider: NSItemProvider) async -> PageSnapshot? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.propertyList.identifier, options: nil) { data, _ in
                continuation.resume(returning: PageSnapshot.parse(data))
            }
        }
    }

    private func loadWebURL(_ provider: NSItemProvider) async -> String? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { data, _ in
                // Only accept web URLs, not file:// URLs.
                if let url = data as? URL, url.scheme == "http" || url.scheme == "https" {
                    continuation.resume(returning: url.absoluteString)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func loadText(_ provider: NSItemProvider) async -> String? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { data, _ in
                if let string = data as? String {
                    continuation.resume(returning: string)
                } else if let data = data as? Data, let string = String(data: data, encoding: .utf8) {
                    continuation.resume(returning: string)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func loadImage(_ provider: NSItemProvider) async -> Data? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { data, _ in
                if let url = data as? URL, let d = try? Data(contentsOf: url) {
                    continuation.resume(returning: d)
                } else if let image = data as? UIImage, let d = image.pngData() {
                    continuation.resume(returning: d)
                } else if let data = data as? Data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    // MARK: - Actions

    /// Enqueue the card to the App Group and return its id (does not finish).
    private func save(_ payload: SharePayload) -> UUID {
        let isLink = !(payload.urlString ?? "").isEmpty
        let isImage = !isLink && payload.bodyText == nil && payload.imageData != nil
        let id = UUID()
        let card = SharedCardDTO(
            id: id,
            title: payload.title,
            description: payload.description,
            urlString: payload.urlString ?? "",
            bodyText: isLink ? "" : (payload.bodyText ?? ""),
            imageData: payload.imageData,
            sourceAppRaw: isLink ? "safari" : (isImage ? "photos" : "messages"),
            collectionID: payload.collectionID,
            createdAt: Date(),
            tags: payload.tags,
            cardTypeRaw: payload.cardTypeRaw,
            price: payload.price,
            imageURL: payload.imageURL
        )
        SharedInbox.enqueueCard(card)
        return id
    }

    /// Open the saved card in the app via its deep link (the API id after an
    /// online save, else the queued card's local id), then finish.
    private func openCard(_ id: String) {
        guard let url = URL(string: "sphir://card/\(id)") else { return finish() }
        openInApp(url)
    }

    /// Open the primary collection in the app (API id, else the local id).
    private func openCollection(_ id: String) {
        guard let url = URL(string: "sphir://collection/\(id)") else { return finish() }
        openInApp(url)
    }

    /// Open the app (no deep link target) when the saved card has no local id yet.
    private func openApp() {
        guard let url = URL(string: "sphir://home") else { return finish() }
        openInApp(url)
    }

    /// extensionContext.open only works for widgets, and share extensions cannot call
    /// UIApplication.open, so walk the responder chain to the host UIApplication and call
    /// open(_:options:completionHandler:) through the Objective-C runtime.
    private func openInApp(_ url: URL) {
        if openThroughResponderChain(url) { return finish() }
        extensionContext?.open(url) { [weak self] _ in self?.finish() }
    }

    private func openThroughResponderChain(_ url: URL) -> Bool {
        let selector = NSSelectorFromString("openURL:options:completionHandler:")
        guard let applicationClass = NSClassFromString("UIApplication") else { return false }
        var responder: UIResponder? = self
        while let current = responder {
            if current.isKind(of: applicationClass), current.responds(to: selector) {
                typealias OpenURL = @convention(c) (
                    AnyObject, Selector, NSURL, NSDictionary, (@convention(block) (Bool) -> Void)?
                ) -> Void
                let open = unsafeBitCast(current.method(for: selector), to: OpenURL.self)
                open(current, selector, url as NSURL, NSDictionary(), nil)
                return true
            }
            responder = current.next
        }
        return false
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    private func cancel() {
        let error = NSError(domain: "com.Sphir.SphirShare", code: 0, userInfo: nil)
        extensionContext?.cancelRequest(withError: error)
    }
}
