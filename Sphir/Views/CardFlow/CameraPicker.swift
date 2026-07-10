//
//  CameraPicker.swift
//  Sphir
//
//  UIImagePickerController wrapper for capturing a photo with the camera.
//  Returns the captured image plus its metadata dictionary (EXIF/TIFF/GPS).
//
//  Requires the NSCameraUsageDescription Info.plist key. Camera is unavailable
//  on the Simulator — callers should check `CameraPicker.isAvailable`.
//

import SwiftUI
import UIKit

struct CameraPicker: UIViewControllerRepresentable {
    let onCapture: (UIImage, [UIImagePickerController.InfoKey: Any]) -> Void
    let onCancel: () -> Void

    static var isAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onCancel: onCancel)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage, [UIImagePickerController.InfoKey: Any]) -> Void
        let onCancel: () -> Void

        init(
            onCapture: @escaping (UIImage, [UIImagePickerController.InfoKey: Any]) -> Void,
            onCancel: @escaping () -> Void
        ) {
            self.onCapture = onCapture
            self.onCancel = onCancel
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image, info)
            } else {
                onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}
