//
//  SphirApp.swift
//  Sphir
//
//  Created by Saul Alejandro on 09/07/26.
//

import SwiftUI
import CoreData

@main
struct SphirApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var appStore = AppStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environmentObject(appStore)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
        // Import cards captured by the share extension whenever the app
        // returns to the foreground (a warm resume never re-runs init()).
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                appStore.importPendingSharedCards()
            }
        }
    }
}
