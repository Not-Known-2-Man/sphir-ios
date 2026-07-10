//
//  ExifService.swift
//  Sphir
//
//  Extracts EXIF/TIFF/GPS metadata (date, location, camera) from image data
//  or a UIImagePickerController metadata dictionary, using ImageIO.
//

import Foundation
import ImageIO
import UIKit

struct PhotoMetadata {
    var dateTaken: Date?
    var latitude: Double?
    var longitude: Double?
    var cameraMake: String?
    var cameraModel: String?

    var isEmpty: Bool {
        dateTaken == nil && latitude == nil && longitude == nil
            && cameraMake == nil && cameraModel == nil
    }

    /// Human-readable lines suitable for a card body.
    var summaryLines: [String] {
        var lines: [String] = []
        if let dateTaken {
            lines.append("Taken: \(Self.displayFormatter.string(from: dateTaken))")
        }
        if let latitude, let longitude {
            lines.append(String(format: "Location: %.5f, %.5f", latitude, longitude))
        }
        let camera = [cameraMake, cameraModel].compactMap { $0 }.joined(separator: " ")
        if !camera.isEmpty {
            lines.append("Camera: \(camera)")
        }
        return lines
    }

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
}

enum ExifService {

    /// Parse metadata from raw image file data (e.g. a PHPicker item).
    static func metadata(from data: Data) -> PhotoMetadata {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return PhotoMetadata()
        }
        return parse(props)
    }

    /// Parse metadata from a UIImagePickerController `.mediaMetadata` dictionary.
    static func metadata(fromPickerInfo info: [UIImagePickerController.InfoKey: Any]) -> PhotoMetadata {
        guard let props = info[.mediaMetadata] as? [CFString: Any] else {
            return PhotoMetadata()
        }
        return parse(props)
    }

    // MARK: - Parsing

    private static func parse(_ props: [CFString: Any]) -> PhotoMetadata {
        var metadata = PhotoMetadata()

        let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any]
        let tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        let gps = props[kCGImagePropertyGPSDictionary] as? [CFString: Any]

        if let dateString = exif?[kCGImagePropertyExifDateTimeOriginal] as? String {
            metadata.dateTaken = exifDateFormatter.date(from: dateString)
        }

        metadata.cameraMake = tiff?[kCGImagePropertyTIFFMake] as? String
        metadata.cameraModel = tiff?[kCGImagePropertyTIFFModel] as? String

        if let lat = gps?[kCGImagePropertyGPSLatitude] as? Double,
           let latRef = gps?[kCGImagePropertyGPSLatitudeRef] as? String {
            metadata.latitude = (latRef == "S") ? -lat : lat
        }
        if let lon = gps?[kCGImagePropertyGPSLongitude] as? Double,
           let lonRef = gps?[kCGImagePropertyGPSLongitudeRef] as? String {
            metadata.longitude = (lonRef == "W") ? -lon : lon
        }

        return metadata
    }

    private static let exifDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return f
    }()
}
