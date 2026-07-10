//
//  ScreenshotPicker.swift
//  Sphir
//
//  PHPickerViewController wrapper filtered to the Screenshots album.
//  PHPicker runs out-of-process, so no photo-library permission is required.
//

import SwiftUI
import PhotosUI

struct ScreenshotPicker: UIViewControllerRepresentable {
    let onPick: (UIImage) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .screenshots
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: (UIImage) -> Void
        let onCancel: () -> Void

        init(onPick: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                onCancel()
                return
            }
            provider.loadObject(ofClass: UIImage.self) { [onPick, onCancel] object, _ in
                DispatchQueue.main.async {
                    if let image = object as? UIImage {
                        onPick(image)
                    } else {
                        onCancel()
                    }
                }
            }
        }
    }
}
