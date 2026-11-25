//
//  CardFlowCoordinator.swift
//  Sphir
//
//  Shared state driving the one-screen "+Card" flow (S5): a single field for a
//  link, plus "Photo or screenshot" and "Write your own". Hoisting the
//  presentation flags into one object lets any step collapse the whole stack
//  ("dismiss all") without threading bindings through every view.
//

import SwiftUI
import Combine

/// A link the user pasted, on its way to the preview card.
struct ClipLink: Identifiable, Equatable {
    let id = UUID()
    let url: String
}

/// What the "Photo or screenshot" row offers.
enum PhotoChoice: Equatable {
    case library
    case camera
}

@MainActor
final class CardFlowCoordinator: ObservableObject {
    // Presentation flags — each bound to a sheet/cover in the flow.
    @Published var showAdd = false              // the +Card sheet
    @Published var clipLink: ClipLink?          // preview card + saved screen (full-screen cover)
    @Published var showForm = false             // "Write your own" full-screen cover
    @Published var showScreenshotForm = false   // Photo / screenshot + OCR full-screen cover
    @Published var showPhotoForm = false        // Photos / Camera full-screen cover (PhotoCardView)

    // Selections carried into the forms.
    @Published var selectedType: CardType?
    @Published var selectedSource: CardSource?

    /// "View card" was tapped on the saved screen; the dashboard opens it once
    /// the sheet is gone (id for sphir://card/<id>).
    @Published var pendingCardLink: String?
    /// "View Collection(s)" was tapped; the dashboard opens it once the sheet
    /// is gone (id for sphir://collection/<id>: API id or local UUID).
    @Published var pendingCollectionLink: String?

    /// Begin the flow from the dashboard.
    func start() {
        selectedType = nil
        selectedSource = nil
        clipLink = nil
        showForm = false
        showScreenshotForm = false
        showPhotoForm = false
        pendingCardLink = nil
        pendingCollectionLink = nil
        showAdd = true
    }

    /// A pasted link goes to the same preview card as the share extension.
    /// Input that is not a link changes nothing.
    func openLink(_ text: String) {
        guard let url = AddCardInput.link(from: text) else { return }
        clipLink = ClipLink(url: url)
    }

    /// "Photo or screenshot": the existing photo/screenshot + OCR path.
    func openPhoto() {
        selectedSource = .screenshots
        showScreenshotForm = true
    }

    /// "Take a photo": the existing camera path (CameraPicker -> PhotoCardView).
    func openCamera() {
        selectedSource = .camera
        showPhotoForm = true
    }

    /// Camera is only offered when the device has one (not on the Simulator).
    nonisolated static func photoChoices(cameraAvailable: Bool) -> [PhotoChoice] {
        cameraAvailable ? [.library, .camera] : [.library]
    }

    /// "Write your own": the Original Scribe form.
    func openWrite() {
        selectedType = .originalScribe
        showForm = true
    }

    /// "View card" on the saved screen: close the flow, then open the card.
    func viewCard(id: String) {
        pendingCardLink = id
        dismissAll()
    }

    /// "View Collection(s)" on the saved screen: close the flow, then open it.
    func viewCollection(id: String) {
        pendingCollectionLink = id
        dismissAll()
    }

    /// Collapse the entire flow back to the dashboard.
    func dismissAll() {
        // Close only the root sheet: UIKit tears down everything stacked on
        // it in one dismissal. Flipping every flag at once raced the nested
        // dismissals and could leave "+ Card" unable to present again.
        // start() resets the child flags before the next run.
        showAdd = false
    }

    /// Back to the +Card screen, ready for another card.
    func addAnother() {
        clipLink = nil
        showForm = false
        showScreenshotForm = false
        showPhotoForm = false
        selectedType = nil
        selectedSource = nil
    }
}
