//
//  MetadataService.swift
//  SphirShare
//
//  Fetches rich link metadata (title + thumbnail) for a shared URL using
//  Apple's LinkPresentation framework. No backend required.
//
//  Note: LPLinkMetadata does not publicly expose og:description, so only
//  title and image are extracted here; `description` is left to callers.
//

import Foundation
import LinkPresentation
import UIKit

struct LinkMetadata {
    var title: String?
    var imageData: Data?
}

enum MetadataService {

    /// Fetch metadata for a URL string. Returns nil if the string isn't a
    /// valid URL or the fetch fails; never throws.
    static func fetch(urlString: String) async -> LinkMetadata? {
        guard let url = URL(string: urlString) else { return nil }

        let provider = LPMetadataProvider()
        provider.shouldFetchSubresources = true

        do {
            let metadata = try await provider.startFetchingMetadata(for: url)

            // Prefer the hero image; fall back to the site icon.
            var imageData = await loadImageData(from: metadata.imageProvider)
            if imageData == nil {
                imageData = await loadImageData(from: metadata.iconProvider)
            }

            return LinkMetadata(title: metadata.title, imageData: imageData)
        } catch {
            return nil
        }
    }

    // MARK: - Image loading

    private static func loadImageData(from provider: NSItemProvider?) async -> Data? {
        guard let provider, provider.canLoadObject(ofClass: UIImage.self) else { return nil }
        return await withCheckedContinuation { continuation in
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                guard let image = object as? UIImage else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: downscaledJPEG(image))
            }
        }
    }

    /// Downscale to keep the stored thumbnail small (App Group storage).
    private static func downscaledJPEG(_ image: UIImage, maxDimension: CGFloat = 512) -> Data? {
        let longest = max(image.size.width, image.size.height)
        let target: UIImage
        if longest > maxDimension, longest > 0 {
            let scale = maxDimension / longest
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            target = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        } else {
            target = image
        }
        return target.jpegData(compressionQuality: 0.7)
    }
}
