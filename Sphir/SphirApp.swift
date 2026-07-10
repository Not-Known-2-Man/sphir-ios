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

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environmentObject(appStore)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
