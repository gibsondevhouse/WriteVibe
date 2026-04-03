//
//  MessagePersistenceAdapter.swift
//  WriteVibe
//

import Foundation
import SwiftData

@MainActor
protocol MessagePersistence {
    func createAssistantPlaceholder(conversationId: UUID, modelName: String, context: ModelContext) throws -> MessageHandle
    func finalizeAssistantPlaceholder(handle: MessageHandle, outcome: FinalizationOutcome) throws
}

@MainActor
protocol MessageTokenBuffering {
    func appendBufferedTokens(_ text: String, handle: MessageHandle) throws
}

@MainActor
protocol MessagePersistenceAdapter: MessagePersistence, MessageTokenBuffering {
    func beginAssistantMessage(run: GenerationRunContext) throws -> MessageHandle
    func appendToken(_ token: String, handle: MessageHandle) throws
    func finalize(handle: MessageHandle, outcome: FinalizationOutcome) throws
}

extension MessagePersistenceAdapter {
    func createAssistantPlaceholder(conversationId: UUID, modelName: String, context: ModelContext) throws -> MessageHandle {
        try beginAssistantMessage(
            run: GenerationRunContext(
                conversationId: conversationId,
                modelName: modelName,
                context: context
            )
        )
    }

    func appendBufferedTokens(_ text: String, handle: MessageHandle) throws {
        try appendToken(text, handle: handle)
    }

    func finalizeAssistantPlaceholder(handle: MessageHandle, outcome: FinalizationOutcome) throws {
        try finalize(handle: handle, outcome: outcome)
    }
}

struct GenerationRunContext {
    let conversationId: UUID
    let modelName: String
    let context: ModelContext
}

struct MessageHandle: Hashable {
    let id: UUID
}

enum FinalizationOutcome {
    case succeeded
    case cancelled
    case failed(Error)
}

enum MessagePersistenceError: LocalizedError {
    case missingConversation
    case placeholderCreationFailed
    case invalidHandle
    case contextSaveFailed

    var errorDescription: String? {
        switch self {
        case .missingConversation:
            return "Conversation not found for stream persistence."
        case .placeholderCreationFailed:
            return "Could not create assistant placeholder message."
        case .invalidHandle:
            return "Streaming persistence handle is no longer valid."
        case .contextSaveFailed:
            return "Could not persist streaming message updates."
        }
    }
}

@MainActor
final class SwiftDataMessagePersistenceAdapter: MessagePersistenceAdapter {
    private let conversationService: ConversationService
    private var activeMessages: [MessageHandle: Message] = [:]
    private var runByHandle: [MessageHandle: GenerationRunContext] = [:]
    private var finalizedHandles: Set<MessageHandle> = []

    init(conversationService: ConversationService) {
        self.conversationService = conversationService
    }

    func beginAssistantMessage(run: GenerationRunContext) throws -> MessageHandle {
        guard conversationService.fetch(run.conversationId, context: run.context) != nil else {
            throw MessagePersistenceError.missingConversation
        }

        let placeholder = Message(role: .assistant, content: "", modelUsed: run.modelName)
        guard conversationService.appendMessage(placeholder, to: run.conversationId, context: run.context) else {
            throw MessagePersistenceError.placeholderCreationFailed
        }

        let handle = MessageHandle(id: UUID())
        activeMessages[handle] = placeholder
        runByHandle[handle] = run
        return handle
    }

    func appendToken(_ token: String, handle: MessageHandle) throws {
        guard let message = activeMessages[handle], !finalizedHandles.contains(handle) else {
            throw MessagePersistenceError.invalidHandle
        }
        message.content += token
    }

    func finalize(handle: MessageHandle, outcome: FinalizationOutcome) throws {
        guard !finalizedHandles.contains(handle) else { return }
        guard let message = activeMessages[handle], let run = runByHandle[handle] else {
            throw MessagePersistenceError.invalidHandle
        }

        switch outcome {
        case .succeeded, .cancelled, .failed:
            message.tokenCount = message.content.count / 4
        }

        if let conversation = conversationService.fetch(run.conversationId, context: run.context) {
            conversation.updatedAt = Date()
        }

        do {
            try run.context.save()
        } catch {
            throw MessagePersistenceError.contextSaveFailed
        }

        finalizedHandles.insert(handle)
        activeMessages.removeValue(forKey: handle)
        runByHandle.removeValue(forKey: handle)
    }
}
