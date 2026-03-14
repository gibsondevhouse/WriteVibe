//
//  WriteVibeApp.swift
//  WriteVibe
//

import SwiftUI
import SwiftData

@main
struct WriteVibeApp: App {
    @State private var services: ServiceContainer
    @State private var appState: AppState

    @MainActor
    init() {
        let container = ServiceContainer()
        _services = State(initialValue: container)
        _appState = State(initialValue: AppState(services: container))
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
        .modelContainer(for: [
            Conversation.self,
            Message.self,
            Article.self,
            ArticleBlock.self,
            ArticleDraft.self
        ])
    }
}
