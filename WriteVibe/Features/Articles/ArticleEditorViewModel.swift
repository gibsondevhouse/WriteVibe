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

enum SelectionWorkflowKind: String, Equatable, Sendable {
    case summarize
    case improve

    var title: String {
        switch self {
        case .summarize:
            return "Selection Summary"
        case .improve:
            return "Improved Selection"
        }
    }
}

enum SelectionWorkflowPayload: Equatable {
    case summary(SelectionSummaryProposal)
    case rewrite(SelectionRewriteProposal)
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
    typealias SummarizeSelectionWorkflow = @MainActor (SelectionWorkflowRequest) async -> AppleWorkflowTaskResult<SelectionSummaryProposal>
    typealias ImproveSelectionWorkflow = @MainActor (SelectionWorkflowRequest) async -> AppleWorkflowTaskResult<SelectionRewriteProposal>

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

    init(
        editOrchestrator: ArticleEditOrchestrating? = nil,
        suggestOutlineWorkflow: SuggestOutlineWorkflow? = nil,
        summarizeSelectionWorkflow: SummarizeSelectionWorkflow? = nil,
        improveSelectionWorkflow: ImproveSelectionWorkflow? = nil
    ) {
        self.editOrchestrator = editOrchestrator ?? DefaultArticleEditOrchestrator()
        self.suggestOutlineWorkflow = suggestOutlineWorkflow ?? Self.defaultSuggestOutlineWorkflow
        self.summarizeSelectionWorkflow = summarizeSelectionWorkflow ?? Self.defaultSummarizeSelectionWorkflow
        self.improveSelectionWorkflow = improveSelectionWorkflow ?? Self.defaultImproveSelectionWorkflow
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
        selectionWorkflowState = .running(kind: kind, selectionToken: selection.token)

        Task {
            switch kind {
            case .summarize:
                let result = await summarizeSelectionWorkflow(request)
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
                let result = await improveSelectionWorkflow(request)
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
                    userMessage: "The selected text changed before the revision could be applied.",
                    nextStep: "Re-select the passage, then run Improve Selection again."
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

    private static func defaultSuggestOutlineWorkflow(_ snapshot: ArticlePlanningSnapshot) async -> AppleWorkflowTaskResult<OutlineSuggestionProposal> {
        guard AppConstants.isAppleStructuredWorkflowEnabled else {
            return .unavailable(
                userMessage: "Structured outline suggestions are disabled for this build.",
                nextStep: "Continue outlining manually in this panel.",
                fallbackCode: "manualOutlineEditing"
            )
        }

        let hasPlanningSeed = !snapshot.title.trimmed.isEmpty || !snapshot.topic.trimmed.isEmpty || !snapshot.summary.trimmed.isEmpty
        guard hasPlanningSeed else {
            return .validationFailure(
                userMessage: "Add a working title, topic, or summary before requesting an outline.",
                nextStep: "Enter one planning detail, then run Suggest Outline again."
            )
        }

        guard #available(macOS 26, *) else {
            return .unavailable(
                userMessage: "This Mac does not support structured outline suggestions.",
                nextStep: "Continue outlining manually in this panel.",
                fallbackCode: "manualOutlineEditing"
            )
        }

        guard AppleIntelligenceService.isAvailable else {
            return .unavailable(
                userMessage: "Structured outline suggestions are unavailable right now.",
                nextStep: "Continue outlining manually, then retry when Apple Intelligence is available.",
                fallbackCode: "manualOutlineEditing"
            )
        }

        do {
            let outline = try await AppleIntelligenceService.generateOutline(
                title: snapshot.title.trimmed.isEmpty ? snapshot.topic : snapshot.title,
                topic: snapshot.topic.trimmed.isEmpty ? snapshot.summary : snapshot.topic,
                audience: snapshot.audience,
                targetLength: snapshot.targetLength
            )

            let proposal = OutlineSuggestionProposal(
                title: outline.title,
                sections: outline.sections.map { OutlineSectionProposal(heading: $0.heading, summary: $0.summary) },
                applyMode: .replaceOutlineText
            )

            return .success(
                proposal,
                userMessage: "Outline suggestion ready for review.",
                nextStep: "Apply it only if it improves the current plan."
            )
        } catch {
            return .executionFailure(
                userMessage: "WriteVibe could not prepare an outline suggestion.",
                nextStep: "Retry Suggest Outline, or continue editing the outline manually."
            )
        }
    }

    private static func defaultSummarizeSelectionWorkflow(_ request: SelectionWorkflowRequest) async -> AppleWorkflowTaskResult<SelectionSummaryProposal> {
        guard AppConstants.isAppleStructuredWorkflowEnabled else {
            return .unavailable(
                userMessage: "Structured selection summaries are disabled for this build.",
                nextStep: "Review the selected text manually.",
                fallbackCode: "manualSelectionEditing"
            )
        }

        guard !request.selectedText.trimmed.isEmpty else {
            return .validationFailure(
                userMessage: "Select the passage you want to summarize before running this action.",
                nextStep: "Highlight text in the draft, then run Summarize Selection again."
            )
        }

        guard #available(macOS 26, *) else {
            return .unavailable(
                userMessage: "This Mac does not support structured selection summaries.",
                nextStep: "Review the selected text manually.",
                fallbackCode: "manualSelectionEditing"
            )
        }

        guard AppleIntelligenceService.isAvailable else {
            return .unavailable(
                userMessage: "Structured selection summaries are unavailable right now.",
                nextStep: "Keep editing manually, then retry when Apple Intelligence is available.",
                fallbackCode: "manualSelectionEditing"
            )
        }

        do {
            let summary = try await AppleIntelligenceService.summarize(request.selectedText)
            return .success(
                SelectionSummaryProposal(summaryText: summary.trimmed, sourceSelectionHash: request.selectionRangeToken),
                userMessage: "Selection summary ready.",
                nextStep: "Review the summary. The draft text remains unchanged."
            )
        } catch {
            return .executionFailure(
                userMessage: "WriteVibe could not summarize the selected text.",
                nextStep: "Retry Summarize Selection, or continue editing manually."
            )
        }
    }

    private static func defaultImproveSelectionWorkflow(_ request: SelectionWorkflowRequest) async -> AppleWorkflowTaskResult<SelectionRewriteProposal> {
        guard AppConstants.isAppleStructuredWorkflowEnabled else {
            return .unavailable(
                userMessage: "Structured selection improvements are disabled for this build.",
                nextStep: "Revise the selected text manually.",
                fallbackCode: "manualSelectionEditing"
            )
        }

        guard !request.selectedText.trimmed.isEmpty else {
            return .validationFailure(
                userMessage: "Select the passage you want to improve before running this action.",
                nextStep: "Highlight text in the draft, then run Improve Selection again."
            )
        }

        guard #available(macOS 26, *) else {
            return .unavailable(
                userMessage: "This Mac does not support structured selection improvements.",
                nextStep: "Revise the selected text manually.",
                fallbackCode: "manualSelectionEditing"
            )
        }

        guard AppleIntelligenceService.isAvailable else {
            return .unavailable(
                userMessage: "Structured selection improvements are unavailable right now.",
                nextStep: "Revise the selected text manually, then retry when Apple Intelligence is available.",
                fallbackCode: "manualSelectionEditing"
            )
        }

        do {
            let rewrite = try await AppleIntelligenceService.rewriteSelection(request.selectedText, tone: request.toneContext)
            return .success(
                SelectionRewriteProposal(
                    rewrittenText: rewrite,
                    changeIntent: "Clarify the selected passage while preserving its meaning.",
                    sourceSelectionHash: request.selectionRangeToken
                ),
                userMessage: "Selection revision ready for review.",
                nextStep: "Apply it only if it improves the draft."
            )
        } catch {
            return .executionFailure(
                userMessage: "WriteVibe could not prepare a revision for the selected text.",
                nextStep: "Retry Improve Selection, or keep revising manually."
            )
        }
    }
}

