//
//  CardFlowCoordinator.swift
//  Sphir
//
//  Shared state driving the multi-step "+Card" creation flow.
//  Hoisting the presentation flags into one object lets any step
//  collapse the whole stack ("dismiss all") or rewind to Step 1
//  ("add another") without threading bindings through every view.
//

import SwiftUI
import Combine

@MainActor
final class CardFlowCoordinator: ObservableObject {
    // Presentation flags — each bound to a sheet/cover in the flow.
    @Published var showType = false     // Step 1 sheet
    @Published var showSource = false   // Step 2 sheet
    @Published var showForm = false     // Step 3 full-screen cover

    // Selections carried across steps.
    @Published var selectedType: CardType?
    @Published var selectedSource: CardSource?

    /// Begin the flow from the dashboard.
    func start() {
        selectedType = nil
        selectedSource = nil
        showSource = false
        showForm = false
        showType = true
    }

    /// Advance from Step 1 to Step 2 with the chosen type.
    func selectType(_ type: CardType) {
        selectedType = type
        showSource = true
    }

    /// Advance from Step 2 to Step 3 with the chosen source.
    func selectSource(_ source: CardSource) {
        selectedSource = source
        showForm = true
    }

    /// Collapse the entire flow back to the dashboard.
    func dismissAll() {
        showForm = false
        showSource = false
        showType = false
    }

    /// Rewind to Step 1, keeping the type sheet presented.
    func addAnother() {
        showForm = false
        showSource = false
        selectedType = nil
        selectedSource = nil
    }
}
