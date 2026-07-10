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

    private func presentShareUI() {
        let stored = SharedInbox.loadCollections()
        let collections = stored.isEmpty ? SharedInbox.fallbackCollections : stored

        let root = ShareView(
            content: content,
            collections: collections,
            onSave: { [weak self] payload in
                self?.save(payload)
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
                if urlString == nil,
                   provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    urlString = await loadWebURL(provider)
                } else if text == nil,
                          provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    text = await loadText(provider)
                }
            }
        }

        return SharedContent(urlString: urlString, text: text)
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

    // MARK: - Actions

    private func save(_ payload: SharePayload) {
        let isLink = !(payload.urlString ?? "").isEmpty
        let card = SharedCardDTO(
            id: UUID(),
            title: payload.title,
            description: payload.description,
            urlString: payload.urlString ?? "",
            bodyText: isLink ? "" : (payload.bodyText ?? ""),
            imageData: payload.imageData,
            sourceAppRaw: isLink ? "safari" : "messages",
            collectionID: payload.collectionID,
            createdAt: Date()
        )
        SharedInbox.enqueueCard(card)
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    private func cancel() {
        let error = NSError(domain: "com.Sphir.SphirShare", code: 0, userInfo: nil)
        extensionContext?.cancelRequest(withError: error)
    }
}
