//
//  AppState.swift
//  WriteVibe
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - DraftSession

/// Temporary in-memory state for article draft metadata before persistence.
/// Tracks a single active draft session started by /article new command.
struct DraftSession {
    var title: String = ""
    var subtitle: String = ""
    var topic: String = ""
    var audience: String = ""
    var quickNotes: String = ""
    var sourceLinks: String = ""
    var outline: String = ""
    var summary: String = ""
    var purpose: String = ""
    var style: String = ""
    var keyTakeaway: String = ""
    var publishingIntent: String = ""
    var tone: String = "Conversational"
    var targetLength: String = "Medium"

    mutating func setField(_ field: String, to value: String) -> Bool {
        switch field.lowercased() {
        case "title": self.title = value
        case "subtitle": self.subtitle = value
        case "topic": self.topic = value
        case "audience": self.audience = value
        case "quicknotes": self.quickNotes = value
        case "sourcelinks": self.sourceLinks = value
        case "outline": self.outline = value
        case "summary": self.summary = value
        case "purpose": self.purpose = value
        case "style": self.style = value
        case "keytakeaway": self.keyTakeaway = value
        case "publishingintent": self.publishingIntent = value
        case "tone": self.tone = value
        case "length", "targetlength": self.targetLength = value
        default: return false
        }
        return true
    }
}

enum DraftSuggestionField: String, CaseIterable {
    case title
    case subtitle
    case tone
    case targetLength
}

struct DraftFieldSuggestion: Equatable {
    let field: DraftSuggestionField
    let previousValue: String
    let suggestedValue: String
}

// MARK: - AppState

@MainActor
@Observable
final class AppState {
    var thinkingId: UUID?                      = nil
    var availableOllamaModels: [OllamaModel]   = []
    var runtimeIssue: RuntimeIssue?            = nil

    // Capability chips / search state
    var isSearchEnabled: Bool = false
    var isSearchFetching: Bool = false

    // Capability selections
    var selectedTone: String = "Balanced"
    var selectedLength: String = "Normal"
    var selectedFormat: String = "Markdown"
    var isMemoryEnabled: Bool = true

    // Sidebar navigation
    var selectedDestination: SidebarDestination = .articles
    var isArticlesSectionExpanded: Bool = true

    // Copilot panel
    var isCopilotOpen: Bool          = false
    var copilotConversationId: UUID? = nil

    // Draft session state
    var activeDraft: DraftSession? = nil
    var isAwaitingDraftSummaryInput: Bool = false
    var draftFieldSuggestions: [DraftSuggestionField: DraftFieldSuggestion] = [:]
    var shouldPresentNewArticleFormFromCommand: Bool = false
    var currentArticleID: UUID? = nil

    let services: ServiceContainer
    private let generationManager: ConversationGenerationManager

    /// Default model applied to every new conversation. Persisted across launches.
    var defaultModel: AIModel = {
        let raw = UserDefaults.standard.string(forKey: "wv.defaultModel") ?? ""
        return AIModel(rawValue: raw) ?? .ollama
    }() {
        didSet { UserDefaults.standard.set(defaultModel.rawValue, forKey: "wv.defaultModel") }
    }

    /// Default model identifier when defaultModel is .ollama. Persisted across launches.
    var defaultModelIdentifier: String? =
        UserDefaults.standard.string(forKey: "wv.defaultModelIdentifier")
        ?? UserDefaults.standard.string(forKey: "wv.defaultOllamaModelName") {
        didSet {
            UserDefaults.standard.set(defaultModelIdentifier, forKey: "wv.defaultModelIdentifier")
            UserDefaults.standard.set(defaultModelIdentifier, forKey: "wv.defaultOllamaModelName")
        }
    }

    var modelContext: ModelContext? = nil

    // MARK: Computed helpers

    var copilotConversation: Conversation? {
        guard let copilotConversationId, let ctx = modelContext else { return nil }
        return services.conversationService.fetch(copilotConversationId, context: ctx)
    }

    var isThinkingInCopilot: Bool { thinkingId != nil && thinkingId == copilotConversationId }

    // MARK: Init

    init(services: ServiceContainer) {
        self.services = services
        self.generationManager = ConversationGenerationManager(services: services)
    }

    // MARK: Context binding

    func bindModelContextIfNeeded(_ context: ModelContext) {
        if modelContext !== context {
            modelContext = context
            do {
                try DataMigrationService.runStartupMigrations(context: context)
            } catch {
                reportIssue(.dataMigrationFailed(error.localizedDescription))
            }
        }
        reconcileConversationIDs()
    }

    func reconcileConversationIDs() {
        guard let ctx = modelContext else { return }
        if let id = copilotConversationId, services.conversationService.fetch(id, context: ctx) == nil { copilotConversationId = nil }
    }

    // MARK: Conversation management

    func fetchConversation(_ id: UUID) -> Conversation? {
        guard let ctx = modelContext else { reportIssue(.modelContextUnavailable()); return nil }
        return services.conversationService.fetch(id, context: ctx)
    }

    func openCopilot() {
        if copilotConversationId == nil || copilotConversation == nil {
            guard newCopilotConversation() != nil else { return }
        }
        isCopilotOpen = true
    }

    @discardableResult
    func newCopilotConversation() -> UUID? {
        guard let ctx = modelContext else { reportIssue(.modelContextUnavailable()); return nil }
        let conv = services.conversationService.create(model: defaultModel, modelIdentifier: defaultModelIdentifier, context: ctx)
        copilotConversationId = conv.id
        return conv.id
    }

    // MARK: Messaging

    @discardableResult
    func send(_ text: String, in conversationId: UUID) -> Bool {
        let trimmed = text.trimmed
        guard !trimmed.isEmpty, thinkingId != conversationId else { return false }
        guard let ctx = modelContext else { reportIssue(.modelContextUnavailable()); return false }

        guard services.conversationService.appendMessage(Message(role: .user, content: trimmed), to: conversationId, context: ctx) else { return false }

        clearRuntimeIssue()

        // Build draft context for command execution
        let draftContext = CommandExecutionService.DraftContext(
            isActive: activeDraft != nil,
            draftFields: activeDraft.map { draft in
                [
                    "title": draft.title,
                    "subtitle": draft.subtitle,
                    "topic": draft.topic,
                    "audience": draft.audience,
                    "quicknotes": draft.quickNotes,
                    "sourcelinks": draft.sourceLinks,
                    "outline": draft.outline,
                    "summary": draft.summary,
                    "purpose": draft.purpose,
                    "style": draft.style,
                    "keytakeaway": draft.keyTakeaway,
                    "publishingintent": draft.publishingIntent,
                    "tone": draft.tone,
                    "targetlength": draft.targetLength
                ]
            } ?? [:]
        )

        let articleContext = resolveArticleContext(in: ctx)

        switch services.commandExecutionService.dispatch(input: trimmed, conversationId: conversationId, context: ctx, draftContext: draftContext, articleContext: articleContext) {
        case .notACommand:
            if captureDraftSummaryIfNeeded(trimmed, in: conversationId, context: ctx) {
                if thinkingId == conversationId { thinkingId = nil }
                break
            }
            thinkingId = conversationId
            generateReply(to: conversationId)
        case .handled(let envelope):
            _ = services.conversationService.appendMessage(
                Message(role: .assistant, content: envelope.renderForAssistantMessage()),
                to: conversationId,
                context: ctx
            )
            if thinkingId == conversationId { thinkingId = nil }
            
            // Handle draft state mutations from command
            handleDraftAction(from: envelope)
            handleArticleMutation(from: envelope, in: ctx)
            handleOutlineMutation(from: envelope, in: ctx)
            handleBodyMutation(from: envelope, in: ctx)
            
            // Route successful article commands to articles destination
            routeIfNeeded(for: envelope)
        }

        return true
    }

    // MARK: Draft Session Management

    private func handleDraftAction(from envelope: CommandExecutionEnvelope) {
        guard envelope.ok, let action = envelope.draftAction else { return }

        if action == "start" {
            activeDraft = DraftSession()
            isAwaitingDraftSummaryInput = true
            draftFieldSuggestions = [:]
            shouldPresentNewArticleFormFromCommand = true
        } else if action == "cancel" {
            activeDraft = nil
            isAwaitingDraftSummaryInput = false
            draftFieldSuggestions = [:]
            shouldPresentNewArticleFormFromCommand = false
        } else if action.hasPrefix("create:title=") {
            if activeDraft != nil {
                let inferredTitle = String(action.dropFirst("create:title=".count))
                if !inferredTitle.isEmpty {
                    _ = activeDraft?.setField("title", to: inferredTitle)
                }
            }
            if let draft = activeDraft {
                createArticleFromDraft(draft)
            }
            activeDraft = nil
            isAwaitingDraftSummaryInput = false
            draftFieldSuggestions = [:]
            shouldPresentNewArticleFormFromCommand = false
        } else if action == "create" {
            // Create article from active draft
            if let draft = activeDraft {
                createArticleFromDraft(draft)
            }
            activeDraft = nil
            isAwaitingDraftSummaryInput = false
            draftFieldSuggestions = [:]
            shouldPresentNewArticleFormFromCommand = false
        } else if action.hasPrefix("set:") {
            isAwaitingDraftSummaryInput = false
            // Parse "set:field=value"
            let components = action.dropFirst("set:".count).split(separator: "=", maxSplits: 1)
            if components.count == 2 {
                let field = String(components[0])
                let value = String(components[1])
                if activeDraft != nil {
                    _ = activeDraft?.setField(field, to: value)
                }
            }
        }
    }

    private func captureDraftSummaryIfNeeded(_ summary: String, in conversationId: UUID, context: ModelContext) -> Bool {
        guard isAwaitingDraftSummaryInput, activeDraft != nil else { return false }

        let suggestions = services.articleDraftAutofillService.autofill(from: summary)
        applyAutofillSuggestion(field: .title, value: suggestions.title)
        applyAutofillSuggestion(field: .subtitle, value: suggestions.subtitle)
        applyAutofillSuggestion(field: .tone, value: suggestions.tone?.rawValue)
        applyAutofillSuggestion(field: .targetLength, value: suggestions.targetLength?.rawValue)

        isAwaitingDraftSummaryInput = false

        _ = services.conversationService.appendMessage(
            Message(
                role: .assistant,
                content: "Thanks. I filled the New Article form with suggestions from your summary. Use the left-side reject/accept controls on each suggested field."
            ),
            to: conversationId,
            context: context
        )

        return true
    }

    private func applyAutofillSuggestion(field: DraftSuggestionField, value: String?) {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return }
        guard var draft = activeDraft else { return }

        let previousValue: String
        switch field {
        case .title:
            previousValue = draft.title
            draft.title = value
        case .subtitle:
            previousValue = draft.subtitle
            draft.subtitle = value
        case .tone:
            previousValue = draft.tone
            draft.tone = value
        case .targetLength:
            previousValue = draft.targetLength
            draft.targetLength = value
        }

        activeDraft = draft
        draftFieldSuggestions[field] = DraftFieldSuggestion(
            field: field,
            previousValue: previousValue,
            suggestedValue: value
        )
    }

    func hasDraftSuggestion(for field: DraftSuggestionField) -> Bool {
        draftFieldSuggestions[field] != nil
    }

    func acceptDraftSuggestion(for field: DraftSuggestionField) {
        draftFieldSuggestions.removeValue(forKey: field)
    }

    func rejectDraftSuggestion(for field: DraftSuggestionField) {
        guard let suggestion = draftFieldSuggestions[field], var draft = activeDraft else { return }

        switch field {
        case .title:
            draft.title = suggestion.previousValue
        case .subtitle:
            draft.subtitle = suggestion.previousValue
        case .tone:
            draft.tone = suggestion.previousValue
        case .targetLength:
            draft.targetLength = suggestion.previousValue
        }

        activeDraft = draft
        draftFieldSuggestions.removeValue(forKey: field)
    }

    func updateDraftField(_ field: DraftSuggestionField, value: String) {
        var draft = activeDraft ?? DraftSession()

        switch field {
        case .title:
            draft.title = value
        case .subtitle:
            draft.subtitle = value
        case .tone:
            draft.tone = value
        case .targetLength:
            draft.targetLength = value
        }

        activeDraft = draft
        draftFieldSuggestions.removeValue(forKey: field)
    }

    private func createArticleFromDraft(_ draft: DraftSession) {
        guard let ctx = modelContext else { return }
        
        let article = Article(
            title: draft.title,
            subtitle: draft.subtitle,
            topic: draft.topic,
            tone: ArticleTone(rawValue: draft.tone) ?? .conversational,
            targetLength: ArticleLength(rawValue: draft.targetLength) ?? .medium
        )
        article.audience = draft.audience
        article.quickNotes = draft.quickNotes
        article.sourceLinks = draft.sourceLinks
        article.outline = draft.outline
        article.summary = draft.summary
        article.purpose = draft.purpose
        article.style = draft.style
        article.keyTakeaway = draft.keyTakeaway
        article.publishingIntent = draft.publishingIntent
        
        ctx.insert(article)
        try? ctx.save()
        currentArticleID = article.id
    }

    func setCurrentArticle(_ articleID: UUID?) {
        currentArticleID = articleID
    }

    func consumeNewArticleFormPresentationTrigger() {
        shouldPresentNewArticleFormFromCommand = false
    }

    func ensureDraftSessionForNewArticleForm() {
        if activeDraft == nil {
            activeDraft = DraftSession()
            draftFieldSuggestions = [:]
            isAwaitingDraftSummaryInput = false
        }
    }

    func clearDraftSession() {
        activeDraft = nil
        isAwaitingDraftSummaryInput = false
        draftFieldSuggestions = [:]
        shouldPresentNewArticleFormFromCommand = false
    }

    private func handleArticleMutation(from envelope: CommandExecutionEnvelope, in context: ModelContext) {
        guard envelope.ok,
              let mutation = envelope.articleMutation,
              let targetID = envelope.target?.articleId,
              let articleID = UUID(uuidString: targetID),
              let article = fetchArticle(id: articleID, context: context) else { return }

        switch services.articleContextMutationAdapter.apply(
            ArticleContextMutationRequest(field: mutation.field, value: mutation.value),
            to: article
        ) {
        case .success:
            currentArticleID = article.id
            try? context.save()
        case .failure:
            break
        }
    }

    private func handleOutlineMutation(from envelope: CommandExecutionEnvelope, in context: ModelContext) {
        guard envelope.ok,
              let op = envelope.outlineOperation,
              let targetID = envelope.target?.articleId,
              let articleID = UUID(uuidString: targetID),
              let article = fetchArticle(id: articleID, context: context) else { return }

        let request = ArticleOutlineMutationRequest(
            operation: op.operation,
            index: op.index,
            value: op.value
        )
        switch services.articleOutlineMutationAdapter.apply(request, to: article) {
        case .success:
            try? context.save()
        case .failure:
            break
        }
    }

    private func handleBodyMutation(from envelope: CommandExecutionEnvelope, in context: ModelContext) {
        guard envelope.ok,
              let op = envelope.bodyOperation,
              let targetID = envelope.target?.articleId,
              let articleID = UUID(uuidString: targetID),
              let article = fetchArticle(id: articleID, context: context) else { return }

        let request = ArticleBodyMutationRequest(
            operation: op.operation,
            blockType: op.blockType,
            index: op.index,
            value: op.value
        )
        switch services.articleBodyMutationAdapter.apply(request, to: article) {
        case .success:
            try? context.save()
        case .failure:
            break
        }
    }

    private func resolveArticleContext(in context: ModelContext) -> CommandExecutionService.ArticleContext {
        guard let currentArticleID else {
            return CommandExecutionService.ArticleContext(hasSelection: false, articleId: nil, articleTitle: nil)
        }

        guard let article = fetchArticle(id: currentArticleID, context: context) else {
            return CommandExecutionService.ArticleContext(hasSelection: true, articleId: nil, articleTitle: nil)
        }

        return CommandExecutionService.ArticleContext(
            hasSelection: true,
            articleId: article.id.uuidString,
            articleTitle: article.title
        )
    }

    private func fetchArticle(id: UUID, context: ModelContext) -> Article? {
        let descriptor = FetchDescriptor<Article>(predicate: #Predicate<Article> { article in
            article.id == id
        })
        return try? context.fetch(descriptor).first
    }

    // MARK: Command Routing

    /// Routes to articles destination if command envelope indicates article context is needed.
    /// Respects WS-301 envelope scope field: "draft" and "article" scopes route to .articles.
    private func routeIfNeeded(for envelope: CommandExecutionEnvelope) {
        guard envelope.ok else { return }
        guard let scope = envelope.target?.scope else { return }
        guard ["draft", "article"].contains(scope) else { return }
        
        selectedDestination = .articles
    }

    func stopGeneration(for conversationId: UUID) {
        generationManager.cancel(for: conversationId)
        if thinkingId == conversationId { thinkingId = nil }
    }

    private func generateReply(to conversationId: UUID) {
        guard let ctx = modelContext else {
            if thinkingId == conversationId { thinkingId = nil }
            return
        }
        generationManager.generateReply(
            to: conversationId,
            context: ctx,
            isSearchEnabled: isSearchEnabled,
            tone: selectedTone,
            length: selectedLength,
            format: selectedFormat,
            isMemoryEnabled: isMemoryEnabled,
            onSearchFetchingChanged: { [weak self] fetching in self?.isSearchFetching = fetching },
            onIssue: { [weak self] issue in self?.runtimeIssue = issue },
            onFinish: { [weak self] in
                if self?.thinkingId == conversationId { self?.thinkingId = nil }
            }
        )
    }

    // MARK: Ollama

    func refreshOllamaModels() async {
        guard await OllamaService.isRunning() else { availableOllamaModels = []; return }
        availableOllamaModels = (try? await OllamaService.installedModels()) ?? []
    }

    // MARK: Token Management

    func estimatedTokenUsage(for conversationId: UUID) -> Double {
        guard let conv = fetchConversation(conversationId) else { return 0.0 }
        let charCount = conv.messages.reduce(0) { $0 + $1.content.count }
        return Double(charCount) / 4.0
    }

    // MARK: Helpers

    func clearRuntimeIssue() { runtimeIssue = nil }

    private func reportIssue(_ issue: RuntimeIssue) { runtimeIssue = issue }
}
