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
    @StateObject private var router = NavigationRouter()
    @StateObject private var session = AuthSession()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appStore)
                .environmentObject(router)
                .environmentObject(session)
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                // Custom scheme: sphir://card/<id>, sphir://collection/<id>
                .onOpenURL { url in
                    router.handle(url, store: appStore)
                }
                // Universal links: https://sphir.io/card/<id>, /collection/<id>
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    if let url = activity.webpageURL {
                        router.handle(url, store: appStore)
                    }
                }
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
