//
//  WriteVibeApp.swift
//  WriteVibe
//

import SwiftUI
import SwiftData

@main
struct WriteVibeApp: App {
    let modelContainer: ModelContainer
    @State private var services: ServiceContainer
    @State private var appState: AppState

    @MainActor
    init() {
        let container = ServiceContainer()
        _services = State(initialValue: container)
        _appState = State(initialValue: AppState(services: container))

        let schema = Schema(versionedSchema: WriteVibeSchemaV2.self)
        let config = ModelConfiguration(
            "WriteVibe",
            schema: schema,
            url: URL.applicationSupportDirectory.appending(path: "WriteVibe.store"),
            allowsSave: true
        )
        do {
            modelContainer = try ModelContainer(
                for: schema,
                migrationPlan: WriteVibeMigrationPlan.self,
                configurations: config
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(services)
                .environment(appState)
        }
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1120, height: 740)
        .windowResizability(.contentMinSize)
        .modelContainer(modelContainer)
    }
}
