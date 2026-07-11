//
//  MetadataService.swift
//  Sphir
//
//  Fetches rich link metadata for a URL: title + thumbnail via
//  LinkPresentation, and description by parsing the page's
//  <meta property="og:description"> tag. No backend required.
//
//  Mirror of SphirShare/MetadataService.swift, compiled into the app target.
//

import Foundation
import LinkPresentation
import UIKit

struct LinkMetadata {
    var title: String?
    var description: String?
    var imageData: Data?
}

enum MetadataService {

    static func fetch(urlString: String) async -> LinkMetadata? {
        guard let url = URL(string: urlString) else { return nil }

        async let linkPresentation = fetchLinkPresentation(url: url)
        async let description = fetchOGDescription(url: url)

        let (lp, desc) = await (linkPresentation, description)
        return LinkMetadata(title: lp.title, description: desc, imageData: lp.imageData)
    }

    // MARK: - LinkPresentation (title + image)

    private static func fetchLinkPresentation(url: URL) async -> (title: String?, imageData: Data?) {
        let provider = LPMetadataProvider()
        provider.shouldFetchSubresources = true
        guard let metadata = try? await provider.startFetchingMetadata(for: url) else {
            return (nil, nil)
        }
        var imageData = await loadImageData(from: metadata.imageProvider)
        if imageData == nil {
            imageData = await loadImageData(from: metadata.iconProvider)
        }
        return (metadata.title, imageData)
    }

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

    // MARK: - og:description (HTML fetch + parse)

    private static func fetchOGDescription(url: URL) async -> String? {
        guard url.scheme == "http" || url.scheme == "https" else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )

        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }
        guard let html = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1) else { return nil }

        let raw = metaContent(in: html, attribute: "property", value: "og:description")
            ?? metaContent(in: html, attribute: "name", value: "description")
        guard let raw, !raw.isEmpty else { return nil }
        return decodeEntities(raw).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func metaContent(in html: String, attribute: String, value: String) -> String? {
        let escapedValue = NSRegularExpression.escapedPattern(for: value)
        let patterns = [
            "<meta[^>]*\\b\(attribute)=[\"']\(escapedValue)[\"'][^>]*\\bcontent=[\"']([^\"']*)[\"']",
            "<meta[^>]*\\bcontent=[\"']([^\"']*)[\"'][^>]*\\b\(attribute)=[\"']\(escapedValue)[\"']"
        ]
        for pattern in patterns {
            if let match = firstCaptureGroup(in: html, pattern: pattern) {
                return match
            }
        }
        return nil
    }

    private static func firstCaptureGroup(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[captureRange])
    }

    private static func decodeEntities(_ string: String) -> String {
        var result = string
        let replacements = [
            "&amp;": "&", "&lt;": "<", "&gt;": ">",
            "&quot;": "\"", "&#39;": "'", "&#x27;": "'", "&apos;": "'"
        ]
        for (entity, character) in replacements {
            result = result.replacingOccurrences(of: entity, with: character)
        }
        return result
    }
}
