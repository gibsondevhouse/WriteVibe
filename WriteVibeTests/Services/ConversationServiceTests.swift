//
//  ConversationServiceTests.swift
//  WriteVibeTests
//

import Testing
import Foundation
import SwiftData
@testable import WriteVibe

@MainActor
struct ConversationServiceTests {

    @Test func testConversationCRUD() async throws {
        // Setup in-memory SwiftData
        let schema = Schema([Conversation.self, Message.self, Article.self, ArticleBlock.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let service = ConversationService()
        
        // Create
        let conv = service.create(model: .ollama, modelIdentifier: "llama3", context: context)
        #expect(conv.title == "New Chat")
        #expect(conv.model == .ollama)
        
        // Fetch
        let fetched = service.fetch(conv.id, context: context)
        #expect(fetched?.id == conv.id)
        
        // Rename
        service.rename(conv.id, to: "Renamed Chat", context: context)
        #expect(conv.title == "Renamed Chat")
        
        // Append Message
        let msg = Message(role: .user, content: "Hello World")
        service.appendMessage(msg, to: conv.id, context: context)
        #expect(conv.messages.count == 1)
        
        // Delete
        service.delete(conv.id, context: context)
        #expect(service.fetch(conv.id, context: context) == nil)
    }
}
