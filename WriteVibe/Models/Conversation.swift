//
//  Conversation.swift
//  WriteVibe
//

import Foundation
import SwiftData

@Model
final class Conversation: Identifiable {
    var id: UUID
    var title: String
    @Relationship(deleteRule: .cascade) var messages: [Message] = []
    var model: AIModel
    @Attribute(originalName: "ollamaModelName") var modelIdentifier: String?
    var createdAt: Date
    var updatedAt: Date

    init(title: String = "New Chat", model: AIModel = .ollama) {
        self.id        = UUID()
        self.title     = title
        self.model     = model
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
