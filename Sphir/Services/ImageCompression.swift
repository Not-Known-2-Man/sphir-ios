//
//  ImageCompression.swift
//  Sphir
//
//  Resizes a picked image to a JPEG that fits the API's 2 MB image limit
//  (POST /api/v1/images). Compiled into the app and the share extension.
//

import UIKit

enum ImageCompression {
    /// Decoded size budget: well under the API's 2 MB limit (base64 adds ~33%).
    static let maxBytes = 1_400_000
    /// Longest side in pixels.
    static let maxDimension: CGFloat = 1600

    private static let qualities: [CGFloat] = [0.8, 0.65, 0.5, 0.35]

    /// JPEG of `data` (any image format), longest side <= `maxDimension`, <= `maxBytes`.
    /// nil when `data` is not an image or no size fits.
    static func jpegForUpload(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return jpegForUpload(image)
    }

    static func jpegForUpload(_ image: UIImage) -> Data? {
        let pixels = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        guard pixels.width > 0, pixels.height > 0 else { return nil }
        var dimension = min(maxDimension, max(pixels.width, pixels.height))
        for _ in 0..<5 {
            let scaled = render(image, pixels: pixels, longestSide: dimension)
            for quality in qualities {
                if let jpeg = scaled.jpegData(compressionQuality: quality), jpeg.count <= maxBytes { return jpeg }
            }
            dimension *= 0.75
        }
        return nil
    }

    private static func render(_ image: UIImage, pixels: CGSize, longestSide: CGFloat) -> UIImage {
        let ratio = min(1, longestSide / max(pixels.width, pixels.height))
        let target = CGSize(width: max(1, (pixels.width * ratio).rounded()), height: max(1, (pixels.height * ratio).rounded()))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: target))
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
