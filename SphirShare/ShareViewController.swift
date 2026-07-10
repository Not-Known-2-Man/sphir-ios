//
//  ShareViewController.swift
//  SphirShare
//
//  Principal class for the Safari share extension. Extracts the shared URL,
//  hosts the SwiftUI ShareView, and enqueues a card to the App Group.
//

import UIKit
import SwiftUI
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {

    private var urlString: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        loadSharedURL { [weak self] extracted in
            guard let self else { return }
            self.urlString = extracted
            self.presentShareUI()
        }
    }

    private func presentShareUI() {
        let stored = SharedInbox.loadCollections()
        let collections = stored.isEmpty ? SharedInbox.fallbackCollections : stored

        let root = ShareView(
            urlString: urlString,
            collections: collections,
            onSave: { [weak self] collectionID in
                self?.save(collectionID: collectionID)
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

    // MARK: - URL Extraction

    private func loadSharedURL(completion: @escaping (String?) -> Void) {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let provider = item.attachments?.first else {
            completion(nil)
            return
        }

        let urlType = UTType.url.identifier
        guard provider.hasItemConformingToTypeIdentifier(urlType) else {
            completion(nil)
            return
        }

        provider.loadItem(forTypeIdentifier: urlType, options: nil) { data, _ in
            let extracted = (data as? URL)?.absoluteString
            DispatchQueue.main.async { completion(extracted) }
        }
    }

    // MARK: - Actions

    private func save(collectionID: UUID?) {
        let title = deriveTitle(from: urlString)
        let card = SharedCardDTO(
            id: UUID(),
            title: title,
            urlString: urlString ?? "",
            collectionID: collectionID,
            createdAt: Date()
        )
        SharedInbox.enqueueCard(card)
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }

    private func cancel() {
        let error = NSError(domain: "com.Sphir.SphirShare", code: 0, userInfo: nil)
        extensionContext?.cancelRequest(withError: error)
    }

    /// Use the host of the URL as a friendly title, falling back sensibly.
    private func deriveTitle(from urlString: String?) -> String {
        guard let urlString, let host = URL(string: urlString)?.host else {
            return "Shared Link"
        }
        return host.replacingOccurrences(of: "www.", with: "")
    }
}
