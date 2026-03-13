//
//  WriteVibeApp.swift
//  WriteVibe
//

import SwiftUI
import SwiftData

@main
struct WriteVibeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1120, height: 740)
        .windowResizability(.contentMinSize)
        .modelContainer(for: [Conversation.self, Message.self, Article.self, ArticleBlock.self])
    }
}
