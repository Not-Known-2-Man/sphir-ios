//
//  ShareRoot.swift
//  SphirShare
//
//  Extension root: the three-tap clip flow for links, with the older crop /
//  extract-text flow (ShareView) one tap away and for non-link shares.
//

import SwiftUI

struct ShareRoot: View {
    let content: SharedContent
    let collections: [SharedCollectionDTO]
    let storedCollections: [SharedCollectionDTO]
    let onSave: (SharePayload) -> UUID
    let onUpdateCollection: (UUID, UUID?) -> Void
    let onScreenChange: (ExtensionScreen) -> Void
    let onView: (String) -> Void
    let onOpenApp: () -> Void
    let onDismiss: () -> Void
    let onCancel: () -> Void

    @State private var showCropFlow = false
    @StateObject private var model: ClipFlowModel

    init(content: SharedContent, collections: [SharedCollectionDTO], storedCollections: [SharedCollectionDTO],
         onSave: @escaping (SharePayload) -> UUID,
         onUpdateCollection: @escaping (UUID, UUID?) -> Void,
         onScreenChange: @escaping (ExtensionScreen) -> Void,
         onView: @escaping (String) -> Void, onOpenApp: @escaping () -> Void,
         onDismiss: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.content = content; self.collections = collections; self.storedCollections = storedCollections
        self.onSave = onSave; self.onUpdateCollection = onUpdateCollection
        self.onScreenChange = onScreenChange; self.onView = onView; self.onOpenApp = onOpenApp
        self.onDismiss = onDismiss; self.onCancel = onCancel
        _model = StateObject(wrappedValue: ClipFlowModel(content: content, sharedCollections: storedCollections, queue: onSave))
    }

    var body: some View {
        if content.isLink && !showCropFlow {
            ClipFlowView(model: model, onCrop: { showCropFlow = true },
                         onView: { id in id.map(onView) ?? onOpenApp() },
                         onDismiss: onDismiss, onCancel: onCancel)
        } else {
            ShareView(content: content, collections: collections, onSave: onSave,
                      onUpdateCollection: onUpdateCollection, onScreenChange: onScreenChange,
                      onView: { onView($0.uuidString) }, onDismiss: onDismiss, onCancel: onCancel)
        }
    }
}
