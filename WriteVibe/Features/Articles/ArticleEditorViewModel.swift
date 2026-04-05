//
//  ArticleEditorViewModel.swift
//  WriteVibe
//

import Foundation
import SwiftUI

enum AppleWorkflowTaskState: Equatable {
    case success
    case unavailable
    case validationFailure
    case executionFailure
    case fallbackComplete
}

struct AppleWorkflowTaskResult<Payload> {
    let state: AppleWorkflowTaskState
    let payload: Payload?
    let userMessage: String
    let nextStep: String
    let fallbackCode: String?
    let runID: UUID
    let schemaVersion: String

    static func success(
        _ payload: Payload,
        userMessage: String,
        nextStep: String = "Review the result and apply it only if it improves the current draft."
    ) -> AppleWorkflowTaskResult<Payload> {
        AppleWorkflowTaskResult(
            state: .success,
            payload: payload,
            userMessage: userMessage,
            nextStep: nextStep,
            fallbackCode: nil,
            runID: UUID(),
            schemaVersion: "wf-ui-1"
        )
    }

    static func unavailable(userMessage: String, nextStep: String, fallbackCode: String) -> AppleWorkflowTaskResult<Payload> {
        AppleWorkflowTaskResult(
            state: .unavailable,
            payload: nil,
            userMessage: userMessage,
            nextStep: nextStep,
            fallbackCode: fallbackCode,
            runID: UUID(),
            schemaVersion: "wf-ui-1"
        )
    }

    static func validationFailure(userMessage: String, nextStep: String) -> AppleWorkflowTaskResult<Payload> {
        AppleWorkflowTaskResult(
            state: .validationFailure,
            payload: nil,
            userMessage: userMessage,
            nextStep: nextStep,
            fallbackCode: nil,
            runID: UUID(),
            schemaVersion: "wf-ui-1"
        )
    }

    static func executionFailure(userMessage: String, nextStep: String) -> AppleWorkflowTaskResult<Payload> {
        AppleWorkflowTaskResult(
            state: .executionFailure,
            payload: nil,
            userMessage: userMessage,
            nextStep: nextStep,
            fallbackCode: "retrySameAction",
            runID: UUID(),
            schemaVersion: "wf-ui-1"
        )
    }
}

enum OutlineApplyMode: String, Equatable {
    case replaceOutlineText
    case insertBlocks
}

struct ArticlePlanningSnapshot: Sendable {
    let articleID: UUID
    let title: String
    let topic: String
    let audience: String
    let summary: String
    let outline: String
    let purpose: String
    let style: String
    let keyTakeaway: String
    let publishingIntent: String
    let sourceLinks: String
    let targetLength: String
    let tone: String
    let updatedAt: Date

    init(article: Article) {
        articleID = article.id
        title = article.title
        topic = article.topic
        audience = article.audience
        summary = article.summary
        outline = article.outline
        purpose = article.purpose
        style = article.style
        keyTakeaway = article.keyTakeaway
        publishingIntent = article.publishingIntent
        sourceLinks = article.sourceLinks
        targetLength = article.targetLength.rawValue
        tone = article.tone.rawValue
        updatedAt = article.updatedAt
    }
}

struct OutlineSectionProposal: Equatable, Sendable {
    let heading: String
    let summary: String
}

struct OutlineSuggestionProposal: Equatable, Sendable {
    let title: String
    let sections: [OutlineSectionProposal]
    let applyMode: OutlineApplyMode

    var previewText: String {
        sections
            .map { "- \($0.heading)\n  \($0.summary)" }
            .joined(separator: "\n\n")
    }

    var outlineText: String {
        sections
            .map { "\($0.heading)\n\($0.summary)" }
            .joined(separator: "\n\n")
    }
}

struct SelectionWorkflowRequest: Sendable {
    let articleID: UUID
    let blockID: UUID?
    let selectionRangeToken: String
    let selectedText: String
    let toneContext: String?
    let surroundingContext: String?
    let requestedAt: Date
}

struct SelectionSummaryProposal: Equatable, Sendable {
    let summaryText: String
    let sourceSelectionHash: String
}

struct SelectionRewriteProposal: Equatable, Sendable {
    let rewrittenText: String
    let changeIntent: String
    let sourceSelectionHash: String
}

struct SelectionVariantItem: Equatable, Sendable {
    let text: String
    let styleLabel: String
}

struct SelectionVariantsProposal: Equatable, Sendable {
    let variants: [SelectionVariantItem]
    let sourceSelectionHash: String
}

enum SelectionWorkflowKind: String, Equatable, Sendable {
    case summarize
    case improve
    case variants

    var title: String {
        switch self {
        case .summarize:
            return "Selection Summary"
        case .improve:
            return "Improved Selection"
        case .variants:
            return "Selection Variants"
        }
    }

    var primaryActionTitle: String? {
        switch self {
        case .summarize, .variants:
            return nil
        case .improve:
            return "Apply Revision"
        }
    }

    var requiresVariantActions: Bool {
        self == .variants
    }

    var unavailableMessage: String {
        switch self {
        case .summarize:
            return "Summarize is unavailable right now. Your selected text is unchanged."
        case .improve:
            return "Improve is unavailable right now. Your selected text is unchanged."
        case .variants:
            return "Variants are unavailable right now. Your selected text is unchanged."
        }
    }

    var failureMessage: String {
        switch self {
        case .summarize:
            return "Summarize could not be completed. Your selected text is unchanged. Please retry."
        case .improve:
            return "Improve could not be completed. Your selected text is unchanged. Please retry."
        case .variants:
            return "Variants could not be generated. Your selected text is unchanged. Please retry."
        }
    }

    var validationMessage: String {
        switch self {
        case .summarize:
            return "Select more text to summarize."
        case .improve:
            return "Select more text to improve."
        case .variants:
            return "Select more text to generate variants."
        }
    }

    var fallbackMessage: String {
        switch self {
        case .summarize:
            return "Summarize completed with fallback. Your selected text is unchanged."
        case .improve:
            return "Improve completed with fallback. Your selected text is unchanged."
        case .variants:
            return "Variants completed with fallback. Your selected text is unchanged."
        }
    }
}

enum SelectionWorkflowPayload: Equatable {
    case summary(SelectionSummaryProposal)
    case rewrite(SelectionRewriteProposal)
    case variants(SelectionVariantsProposal)
}

enum OutlineWorkflowState {
    case idle
    case running
    case result(AppleWorkflowTaskResult<OutlineSuggestionProposal>)
}

enum SelectionWorkflowState {
    case idle
    case running(kind: SelectionWorkflowKind, selectionToken: String)
    case result(kind: SelectionWorkflowKind, selectionToken: String, result: AppleWorkflowTaskResult<SelectionWorkflowPayload>)
}

// MARK: - ArticleEditorViewModel

@MainActor
@Observable
final class ArticleEditorViewModel {

    typealias SuggestOutlineWorkflow = @MainActor (ArticlePlanningSnapshot) async -> AppleWorkflowTaskResult<OutlineSuggestionProposal>
    typealias SummarizeSelectionWorkflow = @MainActor (SelectionWorkflowRequest, EditorSelectionPayload, Article) async -> AppleWorkflowTaskResult<SelectionSummaryProposal>
    typealias ImproveSelectionWorkflow = @MainActor (SelectionWorkflowRequest, EditorSelectionPayload, Article) async -> AppleWorkflowTaskResult<SelectionRewriteProposal>
    typealias GenerateVariantsWorkflow = @MainActor (SelectionWorkflowRequest, EditorSelectionPayload, Article) async -> AppleWorkflowTaskResult<SelectionVariantsProposal>
    typealias LegacySummarizeSelectionWorkflow = @MainActor (SelectionWorkflowRequest) async -> AppleWorkflowTaskResult<SelectionSummaryProposal>
    typealias LegacyImproveSelectionWorkflow = @MainActor (SelectionWorkflowRequest) async -> AppleWorkflowTaskResult<SelectionRewriteProposal>
    typealias LegacyGenerateVariantsWorkflow = @MainActor (SelectionWorkflowRequest) async -> AppleWorkflowTaskResult<SelectionVariantsProposal>

    var showEdits = true
    var isRequestingEdits = false
    var editSummary: String? = nil
    var aiError: RuntimeIssue? = nil
    var outlineWorkflowState: OutlineWorkflowState = .idle
    var selectionWorkflowState: SelectionWorkflowState = .idle

    private let editOrchestrator: ArticleEditOrchestrating
    private let suggestOutlineWorkflow: SuggestOutlineWorkflow
    private let summarizeSelectionWorkflow: SummarizeSelectionWorkflow
    private let improveSelectionWorkflow: ImproveSelectionWorkflow
    private let generateVariantsWorkflow: GenerateVariantsWorkflow

    init(
        editOrchestrator: ArticleEditOrchestrating? = nil,
        structuredWorkflowCoordinator: (any AppleStructuredWorkflowCoordinating)? = nil,
        suggestOutlineWorkflow: SuggestOutlineWorkflow? = nil,
        summarizeSelectionWorkflow: SummarizeSelectionWorkflow? = nil,
        improveSelectionWorkflow: ImproveSelectionWorkflow? = nil,
        generateVariantsWorkflow: GenerateVariantsWorkflow? = nil
    ) {
        let workflowCoordinator = structuredWorkflowCoordinator ?? Self.makeDefaultStructuredWorkflowCoordinator()

        self.editOrchestrator = editOrchestrator ?? DefaultArticleEditOrchestrator()
        self.suggestOutlineWorkflow = suggestOutlineWorkflow ?? { snapshot in
            await Self.defaultSuggestOutlineWorkflow(snapshot, coordinator: workflowCoordinator)
        }
        self.summarizeSelectionWorkflow = summarizeSelectionWorkflow ?? { request, selection, article in
            await Self.defaultSummarizeSelectionWorkflow(request, selection: selection, article: article, coordinator: workflowCoordinator)
        }
        self.improveSelectionWorkflow = improveSelectionWorkflow ?? { request, selection, article in
            await Self.defaultImproveSelectionWorkflow(request, selection: selection, article: article, coordinator: workflowCoordinator)
        }
        self.generateVariantsWorkflow = generateVariantsWorkflow ?? { request, selection, article in
            await Self.defaultGenerateVariantsWorkflow(request, selection: selection, article: article, coordinator: workflowCoordinator)
        }
    }

    convenience init(
        editOrchestrator: ArticleEditOrchestrating? = nil,
        structuredWorkflowService: (any AppleStructuredWorkflowServicing),
        suggestOutlineWorkflow: SuggestOutlineWorkflow? = nil,
        summarizeSelectionWorkflow: SummarizeSelectionWorkflow? = nil,
        improveSelectionWorkflow: ImproveSelectionWorkflow? = nil,
        generateVariantsWorkflow: GenerateVariantsWorkflow? = nil
    ) {
        self.init(
            editOrchestrator: editOrchestrator,
            structuredWorkflowCoordinator: AppleStructuredWorkflowCoordinator(
                router: DefaultAppleStructuredWorkflowRouter(),
                service: structuredWorkflowService
            ),
            suggestOutlineWorkflow: suggestOutlineWorkflow,
            summarizeSelectionWorkflow: summarizeSelectionWorkflow,
            improveSelectionWorkflow: improveSelectionWorkflow,
            generateVariantsWorkflow: generateVariantsWorkflow
        )
    }

    convenience init(
        editOrchestrator: ArticleEditOrchestrating? = nil,
        suggestOutlineWorkflow: SuggestOutlineWorkflow? = nil,
        summarizeSelectionWorkflow: LegacySummarizeSelectionWorkflow? = nil,
        improveSelectionWorkflow: LegacyImproveSelectionWorkflow? = nil,
        generateVariantsWorkflow: LegacyGenerateVariantsWorkflow? = nil
    ) {
        self.init(
            editOrchestrator: editOrchestrator,
            structuredWorkflowCoordinator: nil,
            suggestOutlineWorkflow: suggestOutlineWorkflow,
            summarizeSelectionWorkflow: summarizeSelectionWorkflow.map { legacy in
                { request, _, _ in await legacy(request) }
            },
            improveSelectionWorkflow: improveSelectionWorkflow.map { legacy in
                { request, _, _ in await legacy(request) }
            },
            generateVariantsWorkflow: generateVariantsWorkflow.map { legacy in
                { request, _, _ in await legacy(request) }
            }
        )
    }

    var blockChanges: BlockChanges {
        editOrchestrator.blockChanges
    }

    var hasPendingChanges: Bool {
        editOrchestrator.hasPendingChanges
    }

    var isOutlineWorkflowRunning: Bool {
        if case .running = outlineWorkflowState { return true }
        return false
    }

    var latestOutlineWorkflowResult: AppleWorkflowTaskResult<OutlineSuggestionProposal>? {
        if case .result(let result) = outlineWorkflowState { return result }
        return nil
    }

    var isSelectionWorkflowRunning: Bool {
        if case .running = selectionWorkflowState { return true }
        return false
    }

    var latestSelectionWorkflow: (kind: SelectionWorkflowKind, token: String, result: AppleWorkflowTaskResult<SelectionWorkflowPayload>)? {
        if case .result(let kind, let token, let result) = selectionWorkflowState {
            return (kind, token, result)
        }
        return nil
    }

    // MARK: Block management

    func addBlock(type: BlockType, to article: Article, after preceding: ArticleBlock? = nil) {
        let nextPosition: Int
        if let prec = preceding {
            nextPosition = prec.position + 10
        } else {
            nextPosition = (article.sortedBlocks.last?.position ?? 0) + 1000
        }
        let block = ArticleBlock(type: type, content: "", position: nextPosition)
        article.blocks.append(block)
        article.updatedAt = Date()
    }

    func deleteBlockIfEmpty(_ block: ArticleBlock, from article: Article) {
        guard block.content.isEmpty else { return }
        guard article.blocks.count > 1 else { return }
        if let idx = article.blocks.firstIndex(where: { $0.id == block.id }) {
            article.blocks.remove(at: idx)
            article.updatedAt = Date()
        }
    }

    // MARK: Outline insertion

    /// Inserts an `ArticleOutline` produced by Apple Intelligence as heading + paragraph block pairs.
    func insertOutlineBlocks(_ outline: ArticleOutline, into article: Article) {
        var position = (article.sortedBlocks.last?.position ?? 0) + 1000
        for section in outline.sections {
            let headingBlock = ArticleBlock(type: .heading(level: 2), content: section.heading, position: position)
            article.blocks.append(headingBlock)
            position += 1000
            let bodyBlock = ArticleBlock(type: .paragraph, content: section.summary, position: position)
            article.blocks.append(bodyBlock)
            position += 1000
        }
        article.updatedAt = Date()
    }

    func requestOutlineSuggestion(for article: Article) {
        let snapshot = ArticlePlanningSnapshot(article: article)
        outlineWorkflowState = .running

        Task {
            let result = await suggestOutlineWorkflow(snapshot)
            outlineWorkflowState = .result(result)
        }
    }

    func dismissOutlineWorkflow() {
        outlineWorkflowState = .idle
    }

    func applyOutlineSuggestion(to article: Article) {
        guard case .result(let result) = outlineWorkflowState,
              result.state == .success,
              let proposal = result.payload else {
            return
        }

        article.outline = proposal.outlineText
        article.updatedAt = Date()
        outlineWorkflowState = .idle
    }

    func requestSelectionWorkflow(_ kind: SelectionWorkflowKind, article: Article, selection: EditorSelectionPayload) {
        let request = SelectionWorkflowRequest(
            articleID: article.id,
            blockID: selection.blockID,
            selectionRangeToken: selection.token,
            selectedText: selection.selectedText,
            toneContext: article.tone.rawValue,
            surroundingContext: selection.surroundingContext,
            requestedAt: Date()
        )

        if let validationResult = Self.validateSelectionRequest(request, kind: kind) {
            selectionWorkflowState = .result(
                kind: kind,
                selectionToken: selection.token,
                result: validationResult.toSelectionResult()
            )
            return
        }

        selectionWorkflowState = .running(kind: kind, selectionToken: selection.token)

        Task {
            switch kind {
            case .summarize:
                let result = sanitizeSummarizeResult(await summarizeSelectionWorkflow(request, selection, article))
                guard isAwaitingSelectionWorkflow(kind: kind, token: selection.token) else { return }
                selectionWorkflowState = .result(
                    kind: kind,
                    selectionToken: selection.token,
                    result: AppleWorkflowTaskResult<SelectionWorkflowPayload>(
                        state: result.state,
                        payload: result.payload.map { .summary($0) },
                        userMessage: result.userMessage,
                        nextStep: result.nextStep,
                        fallbackCode: result.fallbackCode,
                        runID: result.runID,
                        schemaVersion: result.schemaVersion
                    )
                )
            case .improve:
                let result = sanitizeImproveResult(await improveSelectionWorkflow(request, selection, article))
                guard isAwaitingSelectionWorkflow(kind: kind, token: selection.token) else { return }
                selectionWorkflowState = .result(
                    kind: kind,
                    selectionToken: selection.token,
                    result: AppleWorkflowTaskResult<SelectionWorkflowPayload>(
                        state: result.state,
                        payload: result.payload.map { .rewrite($0) },
                        userMessage: result.userMessage,
                        nextStep: result.nextStep,
                        fallbackCode: result.fallbackCode,
                        runID: result.runID,
                        schemaVersion: result.schemaVersion
                    )
                )
            case .variants:
                let result = sanitizeVariantsResult(await generateVariantsWorkflow(request, selection, article))
                guard isAwaitingSelectionWorkflow(kind: kind, token: selection.token) else { return }
                selectionWorkflowState = .result(
                    kind: kind,
                    selectionToken: selection.token,
                    result: AppleWorkflowTaskResult<SelectionWorkflowPayload>(
                        state: result.state,
                        payload: result.payload.map { .variants($0) },
                        userMessage: result.userMessage,
                        nextStep: result.nextStep,
                        fallbackCode: result.fallbackCode,
                        runID: result.runID,
                        schemaVersion: result.schemaVersion
                    )
                )
            }
        }
    }

    func dismissSelectionWorkflow() {
        selectionWorkflowState = .idle
    }

    func handleSelectionChange(currentToken: String?) {
        switch selectionWorkflowState {
        case .idle:
            return
        case .running(_, let selectionToken), .result(_, let selectionToken, _):
            if currentToken != selectionToken {
                selectionWorkflowState = .idle
            }
        }
    }

    @discardableResult
    func applySelectionRewrite(using editorState: EditorState) -> Bool {
        guard case .result(kind: .improve, selectionToken: let selectionToken, result: let result) = selectionWorkflowState,
              result.state == .success,
              let payload = result.payload,
              case .rewrite(let proposal) = payload else {
            return false
        }

        guard editorState.replaceSelection(with: proposal.rewrittenText, matching: selectionToken) else {
            selectionWorkflowState = .result(
                kind: .improve,
                selectionToken: selectionToken,
                result: .executionFailure(
                    userMessage: SelectionWorkflowKind.improve.failureMessage,
                    nextStep: "Re-select the passage, then run Improve Selection again."
                )
            )
            return false
        }

        selectionWorkflowState = .idle
        return true
    }

    @discardableResult
    func applySelectionVariant(using editorState: EditorState, variantIndex: Int) -> Bool {
        guard case .result(kind: .variants, selectionToken: let selectionToken, result: let result) = selectionWorkflowState,
              result.state == .success,
              let payload = result.payload,
              case .variants(let proposal) = payload,
              proposal.variants.indices.contains(variantIndex) else {
            return false
        }

        let selectedVariant = proposal.variants[variantIndex]
        guard editorState.replaceSelection(with: selectedVariant.text, matching: selectionToken) else {
            selectionWorkflowState = .result(
                kind: .variants,
                selectionToken: selectionToken,
                result: .executionFailure(
                    userMessage: SelectionWorkflowKind.variants.failureMessage,
                    nextStep: "Re-select the passage, then run Generate Variants again."
                )
            )
            return false
        }

        selectionWorkflowState = .idle
        return true
    }

    // MARK: AI edit request

    func requestAIEdits(for article: Article, defaultModel: AIModel) {
        guard !isRequestingEdits else { return }
        aiError = nil
        isRequestingEdits = true
        let modelID = defaultModel.openRouterModelID ?? "anthropic/claude-3-7-sonnet"

        Task {
            do {
                let applyResult = try await editOrchestrator.requestAndApplyEdits(
                    article: article,
                    modelID: modelID,
                    existingChanges: blockChanges
                )
                editSummary = applyResult.summary
            } catch let error as WriteVibeError {
                aiError = error.runtimeIssue
            } catch {
                aiError = .articleEditFailure(error.localizedDescription)
            }
            isRequestingEdits = false
        }
    }

    // MARK: Accept / Reject (delegated to orchestrator)

    func acceptSpan(_ span: ChangeSpan, in block: ArticleBlock, article: Article) {
        editOrchestrator.acceptSpan(span, in: block.id, article: article)
    }

    func rejectSpan(_ span: ChangeSpan, in block: ArticleBlock, article: Article) {
        editOrchestrator.rejectSpan(span, in: block.id, article: article)
    }

    func acceptAllChanges() {
        editOrchestrator.acceptAllChanges()
    }

    func rejectAllChanges(for article: Article) {
        editOrchestrator.rejectAllChanges(for: article)
    }

    private func isAwaitingSelectionWorkflow(kind: SelectionWorkflowKind, token: String) -> Bool {
        guard case .running(let activeKind, let activeToken) = selectionWorkflowState else {
            return false
        }
        return activeKind == kind && activeToken == token
    }

    private func sanitizeSummarizeResult(
        _ result: AppleWorkflowTaskResult<SelectionSummaryProposal>
    ) -> AppleWorkflowTaskResult<SelectionSummaryProposal> {
        guard result.state == .success,
              let payload = result.payload,
              !payload.summaryText.trimmed.isEmpty else {
            if result.state == .success {
                return .executionFailure(
                    userMessage: SelectionWorkflowKind.summarize.failureMessage,
                    nextStep: "Retry Summarize Selection or continue editing manually."
                )
            }
            return result
        }
        return result
    }

    private func sanitizeImproveResult(
        _ result: AppleWorkflowTaskResult<SelectionRewriteProposal>
    ) -> AppleWorkflowTaskResult<SelectionRewriteProposal> {
        guard result.state == .success,
              let payload = result.payload,
              !payload.rewrittenText.trimmed.isEmpty else {
            if result.state == .success {
                return .executionFailure(
                    userMessage: SelectionWorkflowKind.improve.failureMessage,
                    nextStep: "Retry Improve Selection or continue editing manually."
                )
            }
            return result
        }
        return result
    }

    private func sanitizeVariantsResult(
        _ result: AppleWorkflowTaskResult<SelectionVariantsProposal>
    ) -> AppleWorkflowTaskResult<SelectionVariantsProposal> {
        guard result.state == .success,
              let payload = result.payload else {
            return result
        }

        let cleanedVariants = payload.variants.filter { !$0.text.trimmed.isEmpty }
        guard cleanedVariants.count == 3 else {
            return .executionFailure(
                userMessage: SelectionWorkflowKind.variants.failureMessage,
                nextStep: "Retry Generate Variants or continue editing manually."
            )
        }

        if cleanedVariants.count == payload.variants.count {
            return result
        }

        return AppleWorkflowTaskResult<SelectionVariantsProposal>(
            state: .success,
            payload: SelectionVariantsProposal(
                variants: cleanedVariants,
                sourceSelectionHash: payload.sourceSelectionHash
            ),
            userMessage: result.userMessage,
            nextStep: result.nextStep,
            fallbackCode: result.fallbackCode,
            runID: result.runID,
            schemaVersion: result.schemaVersion
        )
    }

    private static let minSelectionCharacterCount = 50
    private static let maxSelectionCharacterCount = 50_000

    private static func validateSelectionRequest(
        _ request: SelectionWorkflowRequest,
        kind: SelectionWorkflowKind
    ) -> AppleWorkflowTaskResult<Never>? {
        let trimmedSelection = request.selectedText.trimmed
        guard !trimmedSelection.isEmpty else {
            return .validationFailure(
                userMessage: kind.validationMessage,
                nextStep: "Select a longer passage, then retry."
            )
        }

        let selectionLength = (trimmedSelection as NSString).length
        guard selectionLength >= minSelectionCharacterCount,
              selectionLength <= maxSelectionCharacterCount else {
            return .validationFailure(
                userMessage: kind.validationMessage,
                nextStep: "Select between 50 and 50,000 characters, then retry."
            )
        }

        return nil
    }

    private static func makeDefaultStructuredWorkflowCoordinator() -> any AppleStructuredWorkflowCoordinating {
        let service = AppleStructuredWorkflowService(
            heuristicDraftAutofillService: ArticleDraftAutofillService(),
            contextMutationAdapter: ArticleContextMutationAdapter(),
            observabilityService: NoOpAppleWorkflowObservabilityService()
        )
        return AppleStructuredWorkflowCoordinator(
            router: DefaultAppleStructuredWorkflowRouter(),
            service: service
        )
    }

    private static func planningSnapshot(from snapshot: ArticlePlanningSnapshot) -> AppleStructuredPlanningSnapshot {
        AppleStructuredPlanningSnapshot(
            articleID: snapshot.articleID,
            title: snapshot.title,
            topic: snapshot.topic,
            audience: snapshot.audience,
            summary: snapshot.summary,
            outline: snapshot.outline,
            purpose: snapshot.purpose,
            style: snapshot.style,
            keyTakeaway: snapshot.keyTakeaway,
            publishingIntent: snapshot.publishingIntent,
            sourceLinks: snapshot.sourceLinks,
            targetLength: snapshot.targetLength,
            tone: snapshot.tone,
            updatedAt: snapshot.updatedAt
        )
    }

    private static func mappedState(from state: AppleStructuredWorkflowTaskState) -> AppleWorkflowTaskState {
        switch state {
        case .success:
            return .success
        case .featureFlagDisabled, .unsupportedPlatform, .modelUnavailable:
            return .unavailable
        case .validationFailed:
            return .validationFailure
        case .executionFailed:
            return .executionFailure
        case .completedWithFallback:
            return .fallbackComplete
        }
    }

    private static func defaultOutlineNextStep(for state: AppleWorkflowTaskState) -> String {
        switch state {
        case .success:
            return "Apply it only if it improves the current plan."
        case .unavailable:
            return "Continue outlining manually, then retry when Apple workflow services are available."
        case .validationFailure:
            return "Enter a title, topic, or summary, then run Suggest Outline again."
        case .executionFailure:
            return "Retry Suggest Outline, or continue editing the outline manually."
        case .fallbackComplete:
            return "Review the fallback suggestion, then keep editing manually or retry later."
        }
    }

    private static func defaultSelectionNextStep(for kind: SelectionWorkflowKind, state: AppleWorkflowTaskState) -> String {
        switch state {
        case .success:
            switch kind {
            case .summarize:
                return "Review the summary. The draft text remains unchanged."
            case .improve:
                return "Apply it only if it improves the draft."
            case .variants:
                return "Apply one variant only if it improves the selected passage."
            }
        case .unavailable:
            return "Try again later or continue editing manually."
        case .validationFailure:
            return "Select between 50 and 50,000 characters, then retry."
        case .executionFailure:
            switch kind {
            case .summarize:
                return "Retry Summarize Selection or continue editing manually."
            case .improve:
                return "Retry Improve Selection or continue editing manually."
            case .variants:
                return "Retry Generate Variants or continue editing manually."
            }
        case .fallbackComplete:
            switch kind {
            case .summarize:
                return "Use this summary as guidance, then continue editing manually or retry."
            case .improve, .variants:
                return "Review the fallback result. Your selected text stays unchanged until you apply an edit."
            }
        }
    }

    private static func mapOutlineResult(
        _ result: AppleStructuredWorkflowTaskResult<AppleStructuredOutlineSuggestionProposal>
    ) -> AppleWorkflowTaskResult<OutlineSuggestionProposal> {
        let mappedState = mappedState(from: result.state)
        let payload = result.payload.map {
            let applyMode: OutlineApplyMode = $0.applyMode == .insertBlocks ? .insertBlocks : .replaceOutlineText
            return OutlineSuggestionProposal(
                title: $0.title,
                sections: $0.sections.map { OutlineSectionProposal(heading: $0.heading, summary: $0.summary) },
                applyMode: applyMode
            )
        }

        return AppleWorkflowTaskResult(
            state: mappedState,
            payload: payload,
            userMessage: result.userMessage,
            nextStep: defaultOutlineNextStep(for: mappedState),
            fallbackCode: result.fallbackCode?.rawValue,
            runID: result.runID,
            schemaVersion: result.schemaVersion
        )
    }

    private static func mapSummarizeResult(
        _ result: AppleStructuredWorkflowTaskResult<SummarizeProposal>,
        request: SelectionWorkflowRequest
    ) -> AppleWorkflowTaskResult<SelectionSummaryProposal> {
        let mappedState = mappedState(from: result.state)
        let userMessage: String
        switch mappedState {
        case .unavailable:
            userMessage = SelectionWorkflowKind.summarize.unavailableMessage
        case .validationFailure:
            userMessage = SelectionWorkflowKind.summarize.validationMessage
        case .executionFailure:
            userMessage = SelectionWorkflowKind.summarize.failureMessage
        case .fallbackComplete:
            userMessage = SelectionWorkflowKind.summarize.fallbackMessage
        case .success:
            userMessage = result.userMessage
        }

        return AppleWorkflowTaskResult(
            state: mappedState,
            payload: result.payload.map {
                SelectionSummaryProposal(
                    summaryText: $0.summarizedText,
                    sourceSelectionHash: request.selectionRangeToken
                )
            },
            userMessage: userMessage,
            nextStep: defaultSelectionNextStep(for: .summarize, state: mappedState),
            fallbackCode: result.fallbackCode?.rawValue,
            runID: result.runID,
            schemaVersion: result.schemaVersion
        )
    }

    private static func mapImproveResult(
        _ result: AppleStructuredWorkflowTaskResult<ImproveProposal>,
        request: SelectionWorkflowRequest
    ) -> AppleWorkflowTaskResult<SelectionRewriteProposal> {
        let mappedState = mappedState(from: result.state)
        let userMessage: String
        switch mappedState {
        case .unavailable:
            userMessage = SelectionWorkflowKind.improve.unavailableMessage
        case .validationFailure:
            userMessage = SelectionWorkflowKind.improve.validationMessage
        case .executionFailure:
            userMessage = SelectionWorkflowKind.improve.failureMessage
        case .fallbackComplete:
            userMessage = SelectionWorkflowKind.improve.fallbackMessage
        case .success:
            userMessage = result.userMessage
        }

        return AppleWorkflowTaskResult(
            state: mappedState,
            payload: result.payload.map {
                SelectionRewriteProposal(
                    rewrittenText: $0.improvedText,
                    changeIntent: $0.rationale ?? "Clarify the selected passage while preserving its meaning.",
                    sourceSelectionHash: request.selectionRangeToken
                )
            },
            userMessage: userMessage,
            nextStep: defaultSelectionNextStep(for: .improve, state: mappedState),
            fallbackCode: result.fallbackCode?.rawValue,
            runID: result.runID,
            schemaVersion: result.schemaVersion
        )
    }

    private static func mapVariantsResult(
        _ result: AppleStructuredWorkflowTaskResult<VariantsProposal>,
        request: SelectionWorkflowRequest
    ) -> AppleWorkflowTaskResult<SelectionVariantsProposal> {
        let mappedState = mappedState(from: result.state)
        let userMessage: String
        switch mappedState {
        case .unavailable:
            userMessage = SelectionWorkflowKind.variants.unavailableMessage
        case .validationFailure:
            userMessage = SelectionWorkflowKind.variants.validationMessage
        case .executionFailure:
            userMessage = SelectionWorkflowKind.variants.failureMessage
        case .fallbackComplete:
            userMessage = SelectionWorkflowKind.variants.fallbackMessage
        case .success:
            userMessage = result.userMessage
        }

        let labels = ["concise", "balanced", "vivid"]
        return AppleWorkflowTaskResult(
            state: mappedState,
            payload: result.payload.map {
                SelectionVariantsProposal(
                    variants: Array($0.variants.prefix(3)).enumerated().map { index, variant in
                        SelectionVariantItem(
                            text: variant.text,
                            styleLabel: labels[safe: index] ?? variant.style ?? "variant"
                        )
                    },
                    sourceSelectionHash: request.selectionRangeToken
                )
            },
            userMessage: userMessage,
            nextStep: defaultSelectionNextStep(for: .variants, state: mappedState),
            fallbackCode: result.fallbackCode?.rawValue,
            runID: result.runID,
            schemaVersion: result.schemaVersion
        )
    }

    private static func defaultSuggestOutlineWorkflow(
        _ snapshot: ArticlePlanningSnapshot,
        coordinator: any AppleStructuredWorkflowCoordinating
    ) async -> AppleWorkflowTaskResult<OutlineSuggestionProposal> {
        let result = await coordinator.suggestOutline(from: planningSnapshot(from: snapshot))
        return mapOutlineResult(result)
    }

    private static func defaultSummarizeSelectionWorkflow(
        _ request: SelectionWorkflowRequest,
        selection: EditorSelectionPayload,
        article: Article,
        coordinator: any AppleStructuredWorkflowCoordinating
    ) async -> AppleWorkflowTaskResult<SelectionSummaryProposal> {
        let result = await coordinator.summarizeSelectedText(
            text: request.selectedText,
            selection: selection,
            article: article
        )
        return mapSummarizeResult(result, request: request)
    }

    private static func defaultImproveSelectionWorkflow(
        _ request: SelectionWorkflowRequest,
        selection: EditorSelectionPayload,
        article: Article,
        coordinator: any AppleStructuredWorkflowCoordinating
    ) async -> AppleWorkflowTaskResult<SelectionRewriteProposal> {
        let result = await coordinator.improveSelectedText(
            text: request.selectedText,
            selection: selection,
            article: article
        )
        return mapImproveResult(result, request: request)
    }

    private static func defaultGenerateVariantsWorkflow(
        _ request: SelectionWorkflowRequest,
        selection: EditorSelectionPayload,
        article: Article,
        coordinator: any AppleStructuredWorkflowCoordinating
    ) async -> AppleWorkflowTaskResult<SelectionVariantsProposal> {
        let result = await coordinator.generateVariants(
            text: request.selectedText,
            selection: selection,
            article: article
        )
        return mapVariantsResult(result, request: request)
    }
}

private extension AppleWorkflowTaskResult where Payload == Never {
    func toSelectionResult<T>() -> AppleWorkflowTaskResult<T> {
        AppleWorkflowTaskResult<T>(
            state: state,
            payload: nil,
            userMessage: userMessage,
            nextStep: nextStep,
            fallbackCode: fallbackCode,
            runID: runID,
            schemaVersion: schemaVersion
        )
    }
}

