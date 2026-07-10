//
//  PhotoPicker.swift
//  Sphir
//
//  PHPickerViewController wrapper (all photos). Returns the raw file data so
//  EXIF metadata can be read. PHPicker runs out-of-process — no permission
//  prompt required (location may be stripped by the system for privacy).
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct PhotoPicker: UIViewControllerRepresentable {
    let onPick: (Data) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
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
        let onPick: (Data) -> Void
        let onCancel: () -> Void

        init(onPick: @escaping (Data) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider else {
                onCancel()
                return
            }
            let imageType = UTType.image.identifier
            guard provider.hasItemConformingToTypeIdentifier(imageType) else {
                onCancel()
                return
            }
            provider.loadDataRepresentation(forTypeIdentifier: imageType) { [onPick, onCancel] data, _ in
                DispatchQueue.main.async {
                    if let data { onPick(data) } else { onCancel() }
                }
            }
        }
    }
}
