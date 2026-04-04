//
//  AppleIntelligenceService.swift
//  WriteVibe
//
//  Sole file that imports FoundationModels. Used only for utility generation tasks
//  (e.g. auto-title). Chat routing goes through OllamaService or OpenRouterService.
//  AppState calls in via the static methods below.
//

import Foundation
import FoundationModels

enum AppleWorkflowTaskKind: String, Sendable {
    case draftAutofill
    case outlineSuggestion
    case contextSuggestion
    case wordPlanSuggestion
    case summarizeSelection
    case improveSelection
    case generateVariants
}

enum AppleWorkflowEntryPoint: String, Sendable {
    case articleDraftCreation
    case articleOutlinePlanning
    case articleContextPlanning
    case articleEditorSelection
    case genericChat
}

enum AppleStructuredWorkflowTaskState: String, Sendable {
    case success
    case featureFlagDisabled
    case unsupportedPlatform
    case modelUnavailable
    case validationFailed
    case executionFailed
    case completedWithFallback
}

enum AppleWorkflowFallbackCode: String, Sendable {
    case localHeuristicDraftAutofill
    case manualOutlineEditing
    case manualContextEditing
    case manualWordPlanning
    case manualSelectionEditing
    case retrySameAction
}

enum AppleWorkflowRolloutPhase: String, Sendable {
    case internalValidation
    case limitedCohort
    case broadEnablement
}

enum AppleWorkflowUnavailableReason: String, Sendable {
    case featureFlagDisabled
    case unsupportedPlatform
    case modelUnavailable
    case validationFailed
    case executionFailed
    case routeBlocked
}

enum AppleStructuredOutlineApplyMode: String, Equatable, Sendable {
    case replaceOutlineText
    case insertBlocks
}

struct AppleWorkflowRouteRequest: Sendable {
    let taskKind: AppleWorkflowTaskKind
    let entryPoint: AppleWorkflowEntryPoint
    let articleID: UUID?
    let hasSelection: Bool
    let rolloutPhase: AppleWorkflowRolloutPhase
    let featureFlagEnabled: Bool
}

enum AppleWorkflowRouteDecision: Equatable, Sendable {
    case allowed
    case blocked(reason: String)
    case unavailable(reason: AppleWorkflowUnavailableReason, fallback: AppleWorkflowFallbackCode?)
}

struct AppleStructuredWorkflowTaskResult<Payload>: Sendable where Payload: Sendable {
    let state: AppleStructuredWorkflowTaskState
    let payload: Payload?
    let unavailableReason: AppleWorkflowUnavailableReason?
    let fallbackCode: AppleWorkflowFallbackCode?
    let userMessage: String
    let runID: UUID
    let schemaVersion: String
}

struct DraftAutofillSeed: Sendable {
    let summary: String
    let existingTitle: String?
    let existingTopic: String?
}

struct AppleStructuredPlanningSnapshot: Sendable {
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
}

struct DraftAutofillProposal: Equatable, Sendable {
    let title: String
    let subtitle: String
    let tone: String
    let targetLength: String
    let confidenceNotes: [String]
}

struct AppleStructuredOutlineSectionProposal: Equatable, Sendable {
    let heading: String
    let summary: String
}

struct AppleStructuredOutlineSuggestionProposal: Equatable, Sendable {
    let title: String
    let sections: [AppleStructuredOutlineSectionProposal]
    let applyMode: AppleStructuredOutlineApplyMode
}

struct AppleStructuredContextSuggestionProposal: Equatable, Sendable {
    let summary: String
    let audience: String
    let purpose: String
    let style: String
    let keyTakeaway: String
    let publishingIntent: String
    let sourceLinks: String?
    let acceptedFields: [String]
}

struct SummarizeProposal: Codable, Equatable, Sendable {
    let summarizedText: String
    let wordCount: Int
    let generatedOn: Date
}

struct ImproveProposal: Codable, Equatable, Sendable {
    let improvedText: String
    let rationale: String?
    let generatedOn: Date
}

struct VariantsProposal: Codable, Equatable, Sendable {
    let variants: [TextVariant]
    let generatedOn: Date
}

struct TextVariant: Codable, Equatable, Sendable {
    let text: String
    let style: String?
}

enum AppleStructuredWorkflowFeatureFlag: Sendable {
    case summarizeSelection
    case improveSelection
    case generateVariants

    var isEnabled: Bool {
        AppConstants.isAppleStructuredWorkflowEnabled
    }
}

struct AppleWorkflowInputSummary: Equatable, Sendable {
    let selectionWordCount: Int
    let selectionToken: String
    let blockID: UUID?
    let selectionRangeLocation: Int
    let selectionRangeLength: Int
}

struct AppleWorkflowRunArtifact: Equatable, Sendable {
    let runID: UUID
    let taskKind: AppleWorkflowTaskKind
    let entryPoint: AppleWorkflowEntryPoint
    let articleID: UUID?
    let rolloutPhase: AppleWorkflowRolloutPhase
    let outcomeState: AppleStructuredWorkflowTaskState
    let fallbackCode: AppleWorkflowFallbackCode?
    let userMessage: String
    let startedAt: Date
    let completedAt: Date
    let schemaVersion: String
    let inputSummary: AppleWorkflowInputSummary?
}

protocol AppleStructuredWorkflowRouting: Sendable {
    func evaluateRoute(for request: AppleWorkflowRouteRequest) -> AppleWorkflowRouteDecision
}

protocol AppleStructuredWorkflowServicing: Sendable {
    func autofillDraft(from summary: String, articleSnapshot: DraftAutofillSeed?) async -> AppleStructuredWorkflowTaskResult<DraftAutofillProposal>
    func suggestOutline(from snapshot: AppleStructuredPlanningSnapshot) async -> AppleStructuredWorkflowTaskResult<AppleStructuredOutlineSuggestionProposal>
    func suggestContext(from snapshot: AppleStructuredPlanningSnapshot) async -> AppleStructuredWorkflowTaskResult<AppleStructuredContextSuggestionProposal>
    func summarizeSelectedText(text: String, selection: EditorSelectionPayload, article: Article) async -> AppleStructuredWorkflowTaskResult<SummarizeProposal>
    func improveSelectedText(text: String, selection: EditorSelectionPayload, article: Article) async -> AppleStructuredWorkflowTaskResult<ImproveProposal>
    func generateVariants(text: String, selection: EditorSelectionPayload, article: Article) async -> AppleStructuredWorkflowTaskResult<VariantsProposal>
}

protocol AppleWorkflowObservabilityServicing: Sendable {
    func recordRun(_ artifact: AppleWorkflowRunArtifact) async
}

struct NoOpAppleWorkflowObservabilityService: AppleWorkflowObservabilityServicing {
    func recordRun(_ artifact: AppleWorkflowRunArtifact) async {
        _ = artifact
    }
}

enum AppleWorkflowAvailability: Sendable {
    case available
    case unsupportedPlatform
    case modelUnavailable
}

struct DefaultAppleStructuredWorkflowRouter: AppleStructuredWorkflowRouting {
    func evaluateRoute(for request: AppleWorkflowRouteRequest) -> AppleWorkflowRouteDecision {
        guard request.featureFlagEnabled else {
            return .unavailable(reason: .featureFlagDisabled, fallback: fallbackCode(for: request.taskKind))
        }

        guard supportedTaskKinds.contains(request.taskKind) else {
            return .blocked(reason: "This Apple workflow action is not enabled in slice 1.")
        }

        guard supportedEntryPoint(for: request.taskKind) == request.entryPoint else {
            return .blocked(reason: "Apple structured workflows are limited to article draft, outline, and context entry points and cannot route through chat.")
        }

        if requiresArticleID(request.taskKind), request.articleID == nil {
            return .blocked(reason: "This Apple workflow action requires an article context before it can run.")
        }

        if requiresSelection(request.taskKind), request.hasSelection == false {
            return .blocked(reason: "This Apple workflow action requires an explicit text selection.")
        }

        switch AppleStructuredWorkflowService.defaultAvailability() {
        case .available:
            return .allowed
        case .unsupportedPlatform:
            return .unavailable(reason: .unsupportedPlatform, fallback: fallbackCode(for: request.taskKind))
        case .modelUnavailable:
            return .unavailable(reason: .modelUnavailable, fallback: fallbackCode(for: request.taskKind))
        }
    }

    private let supportedTaskKinds: Set<AppleWorkflowTaskKind> = [
        .draftAutofill,
        .outlineSuggestion,
        .contextSuggestion,
        .summarizeSelection,
        .improveSelection,
        .generateVariants
    ]

    private func supportedEntryPoint(for taskKind: AppleWorkflowTaskKind) -> AppleWorkflowEntryPoint {
        switch taskKind {
        case .draftAutofill:
            return .articleDraftCreation
        case .outlineSuggestion:
            return .articleOutlinePlanning
        case .contextSuggestion:
            return .articleContextPlanning
        case .wordPlanSuggestion:
            return .articleOutlinePlanning
        case .summarizeSelection, .improveSelection, .generateVariants:
            return .articleEditorSelection
        }
    }

    private func requiresArticleID(_ taskKind: AppleWorkflowTaskKind) -> Bool {
        switch taskKind {
        case .outlineSuggestion, .contextSuggestion, .wordPlanSuggestion, .summarizeSelection, .improveSelection, .generateVariants:
            return true
        case .draftAutofill:
            return false
        }
    }

    private func requiresSelection(_ taskKind: AppleWorkflowTaskKind) -> Bool {
        switch taskKind {
        case .summarizeSelection, .improveSelection, .generateVariants:
            return true
        default:
            return false
        }
    }

    private func fallbackCode(for taskKind: AppleWorkflowTaskKind) -> AppleWorkflowFallbackCode? {
        switch taskKind {
        case .draftAutofill:
            return .localHeuristicDraftAutofill
        case .outlineSuggestion:
            return .manualOutlineEditing
        case .contextSuggestion:
            return .manualContextEditing
        case .wordPlanSuggestion:
            return .manualWordPlanning
        case .summarizeSelection, .improveSelection, .generateVariants:
            return .manualSelectionEditing
        }
    }
}

@MainActor
final class AppleStructuredWorkflowService: AppleStructuredWorkflowServicing {
    typealias AvailabilityEvaluator = @MainActor () -> AppleWorkflowAvailability
    typealias DraftAutofillExecutor = @MainActor (DraftAutofillSeed) async throws -> DraftAutofillProposal
    typealias OutlineExecutor = @MainActor (AppleStructuredPlanningSnapshot) async throws -> AppleStructuredOutlineSuggestionProposal
    typealias ContextExecutor = @MainActor (AppleStructuredPlanningSnapshot) async throws -> AppleStructuredContextSuggestionProposal
    typealias SummarizeSelectionExecutor = @MainActor (String) async throws -> String
    typealias ImproveSelectionExecutor = @MainActor (String, String?) async throws -> String
    typealias VariantsSelectionExecutor = @MainActor (String, String) async throws -> DraftVariants

    static let schemaVersion = "apple-structured-workflow/v1"

    private let heuristicDraftAutofillService: any ArticleDraftAutofillServicing
    private let contextMutationAdapter: ArticleContextMutationAdapter
    private let observabilityService: any AppleWorkflowObservabilityServicing
    private let rolloutPhase: AppleWorkflowRolloutPhase
    private let availabilityEvaluator: AvailabilityEvaluator
    private let draftAutofillExecutor: DraftAutofillExecutor
    private let outlineExecutor: OutlineExecutor
    private let contextExecutor: ContextExecutor
    private let summarizeSelectionExecutor: SummarizeSelectionExecutor
    private let improveSelectionExecutor: ImproveSelectionExecutor
    private let variantsSelectionExecutor: VariantsSelectionExecutor

    init(
        heuristicDraftAutofillService: any ArticleDraftAutofillServicing,
        contextMutationAdapter: ArticleContextMutationAdapter,
        observabilityService: any AppleWorkflowObservabilityServicing,
        rolloutPhase: AppleWorkflowRolloutPhase = .internalValidation,
        availabilityEvaluator: @escaping AvailabilityEvaluator = { AppleStructuredWorkflowService.defaultAvailability() },
        draftAutofillExecutor: @escaping DraftAutofillExecutor = { seed in
            guard #available(macOS 26, *) else {
                throw WriteVibeError.modelUnavailable(name: "Apple Intelligence")
            }
            return try await AppleIntelligenceService.generateDraftAutofill(from: seed)
        },
        outlineExecutor: @escaping OutlineExecutor = { snapshot in
            guard #available(macOS 26, *) else {
                throw WriteVibeError.modelUnavailable(name: "Apple Intelligence")
            }
            return try await AppleIntelligenceService.generateOutlineSuggestion(from: snapshot)
        },
        contextExecutor: @escaping ContextExecutor = { snapshot in
            guard #available(macOS 26, *) else {
                throw WriteVibeError.modelUnavailable(name: "Apple Intelligence")
            }
            return try await AppleIntelligenceService.generateContextSuggestion(from: snapshot)
        },
        summarizeSelectionExecutor: @escaping SummarizeSelectionExecutor = { text in
            guard #available(macOS 26, *) else {
                throw WriteVibeError.modelUnavailable(name: "Apple Intelligence")
            }
            return try await AppleIntelligenceService.summarize(text)
        },
        improveSelectionExecutor: @escaping ImproveSelectionExecutor = { text, tone in
            guard #available(macOS 26, *) else {
                throw WriteVibeError.modelUnavailable(name: "Apple Intelligence")
            }
            return try await AppleIntelligenceService.rewriteSelection(text, tone: tone)
        },
        variantsSelectionExecutor: @escaping VariantsSelectionExecutor = { text, tone in
            guard #available(macOS 26, *) else {
                throw WriteVibeError.modelUnavailable(name: "Apple Intelligence")
            }
            return try await AppleIntelligenceService.generateVariants(for: text, tone: tone)
        }
    ) {
        self.heuristicDraftAutofillService = heuristicDraftAutofillService
        self.contextMutationAdapter = contextMutationAdapter
        self.observabilityService = observabilityService
        self.rolloutPhase = rolloutPhase
        self.availabilityEvaluator = availabilityEvaluator
        self.draftAutofillExecutor = draftAutofillExecutor
        self.outlineExecutor = outlineExecutor
        self.contextExecutor = contextExecutor
        self.summarizeSelectionExecutor = summarizeSelectionExecutor
        self.improveSelectionExecutor = improveSelectionExecutor
        self.variantsSelectionExecutor = variantsSelectionExecutor
    }

    func autofillDraft(from summary: String, articleSnapshot: DraftAutofillSeed?) async -> AppleStructuredWorkflowTaskResult<DraftAutofillProposal> {
        let runID = UUID()
        let startedAt = Date()
        let normalizedSummary = summary.trimmed
        let seed = DraftAutofillSeed(
            summary: normalizedSummary,
            existingTitle: articleSnapshot?.existingTitle,
            existingTopic: articleSnapshot?.existingTopic
        )

        guard !normalizedSummary.isEmpty else {
            let result = AppleStructuredWorkflowTaskResult<DraftAutofillProposal>(
                state: .validationFailed,
                payload: nil,
                unavailableReason: .validationFailed,
                fallbackCode: .retrySameAction,
                userMessage: "Add a short article summary to generate draft details.",
                runID: runID,
                schemaVersion: Self.schemaVersion
            )
            await record(result, taskKind: .draftAutofill, entryPoint: .articleDraftCreation, articleID: nil, startedAt: startedAt)
            return result
        }

        switch availabilityEvaluator() {
        case .available:
            break
        case .unsupportedPlatform:
            return await fallbackDraftAutofill(
                seed: seed,
                runID: runID,
                startedAt: startedAt,
                reason: .unsupportedPlatform,
                userMessage: "Apple draft autofill is unavailable on this Mac. WriteVibe used the local draft autofill fallback instead."
            )
        case .modelUnavailable:
            return await fallbackDraftAutofill(
                seed: seed,
                runID: runID,
                startedAt: startedAt,
                reason: .modelUnavailable,
                userMessage: "Apple draft autofill is unavailable right now. WriteVibe used the local draft autofill fallback instead."
            )
        }

        do {
            let proposal = try await draftAutofillExecutor(seed)
            let result = AppleStructuredWorkflowTaskResult(
                state: .success,
                payload: proposal,
                unavailableReason: nil,
                fallbackCode: nil,
                userMessage: "Draft details are ready to review.",
                runID: runID,
                schemaVersion: Self.schemaVersion
            )
            await record(result, taskKind: .draftAutofill, entryPoint: .articleDraftCreation, articleID: nil, startedAt: startedAt)
            return result
        } catch {
            return await fallbackDraftAutofill(
                seed: seed,
                runID: runID,
                startedAt: startedAt,
                reason: .executionFailed,
                userMessage: "Apple draft autofill could not complete. WriteVibe used the local draft autofill fallback instead."
            )
        }
    }

    func suggestOutline(from snapshot: AppleStructuredPlanningSnapshot) async -> AppleStructuredWorkflowTaskResult<AppleStructuredOutlineSuggestionProposal> {
        let runID = UUID()
        let startedAt = Date()

        guard isValidOutlineSnapshot(snapshot) else {
            let result = AppleStructuredWorkflowTaskResult<AppleStructuredOutlineSuggestionProposal>(
                state: .validationFailed,
                payload: nil,
                unavailableReason: .validationFailed,
                fallbackCode: .retrySameAction,
                userMessage: "Add a title or topic before requesting an outline suggestion.",
                runID: runID,
                schemaVersion: Self.schemaVersion
            )
            await record(result, taskKind: .outlineSuggestion, entryPoint: .articleOutlinePlanning, articleID: snapshot.articleID, startedAt: startedAt)
            return result
        }

        switch availabilityEvaluator() {
        case .available:
            break
        case .unsupportedPlatform:
            let result = AppleStructuredWorkflowTaskResult<AppleStructuredOutlineSuggestionProposal>(
                state: .unsupportedPlatform,
                payload: nil,
                unavailableReason: .unsupportedPlatform,
                fallbackCode: .manualOutlineEditing,
                userMessage: "Apple outline suggestion is unavailable on this Mac. Continue editing the outline manually or use /article outline commands.",
                runID: runID,
                schemaVersion: Self.schemaVersion
            )
            await record(result, taskKind: .outlineSuggestion, entryPoint: .articleOutlinePlanning, articleID: snapshot.articleID, startedAt: startedAt)
            return result
        case .modelUnavailable:
            let result = AppleStructuredWorkflowTaskResult<AppleStructuredOutlineSuggestionProposal>(
                state: .modelUnavailable,
                payload: nil,
                unavailableReason: .modelUnavailable,
                fallbackCode: .manualOutlineEditing,
                userMessage: "Apple outline suggestion is unavailable right now. Continue editing the outline manually or use /article outline commands.",
                runID: runID,
                schemaVersion: Self.schemaVersion
            )
            await record(result, taskKind: .outlineSuggestion, entryPoint: .articleOutlinePlanning, articleID: snapshot.articleID, startedAt: startedAt)
            return result
        }

        do {
            let proposal = try await outlineExecutor(snapshot)
            let result = AppleStructuredWorkflowTaskResult(
                state: .success,
                payload: proposal,
                unavailableReason: nil,
                fallbackCode: nil,
                userMessage: "Outline suggestion is ready to review.",
                runID: runID,
                schemaVersion: Self.schemaVersion
            )
            await record(result, taskKind: .outlineSuggestion, entryPoint: .articleOutlinePlanning, articleID: snapshot.articleID, startedAt: startedAt)
            return result
        } catch {
            let result = AppleStructuredWorkflowTaskResult<AppleStructuredOutlineSuggestionProposal>(
                state: .executionFailed,
                payload: nil,
                unavailableReason: .executionFailed,
                fallbackCode: .manualOutlineEditing,
                userMessage: "Apple outline suggestion could not complete. Continue editing the outline manually or use /article outline commands.",
                runID: runID,
                schemaVersion: Self.schemaVersion
            )
            await record(result, taskKind: .outlineSuggestion, entryPoint: .articleOutlinePlanning, articleID: snapshot.articleID, startedAt: startedAt)
            return result
        }
    }

    func suggestContext(from snapshot: AppleStructuredPlanningSnapshot) async -> AppleStructuredWorkflowTaskResult<AppleStructuredContextSuggestionProposal> {
        let runID = UUID()
        let startedAt = Date()

        guard isValidContextSnapshot(snapshot) else {
            let result = AppleStructuredWorkflowTaskResult<AppleStructuredContextSuggestionProposal>(
                state: .validationFailed,
                payload: nil,
                unavailableReason: .validationFailed,
                fallbackCode: .retrySameAction,
                userMessage: "Add a title, topic, or summary before requesting context suggestions.",
                runID: runID,
                schemaVersion: Self.schemaVersion
            )
            await record(result, taskKind: .contextSuggestion, entryPoint: .articleContextPlanning, articleID: snapshot.articleID, startedAt: startedAt)
            return result
        }

        switch availabilityEvaluator() {
        case .available:
            break
        case .unsupportedPlatform:
            let result = AppleStructuredWorkflowTaskResult<AppleStructuredContextSuggestionProposal>(
                state: .unsupportedPlatform,
                payload: nil,
                unavailableReason: .unsupportedPlatform,
                fallbackCode: .manualContextEditing,
                userMessage: "Apple context suggestion is unavailable on this Mac. Continue editing the article context fields manually.",
                runID: runID,
                schemaVersion: Self.schemaVersion
            )
            await record(result, taskKind: .contextSuggestion, entryPoint: .articleContextPlanning, articleID: snapshot.articleID, startedAt: startedAt)
            return result
        case .modelUnavailable:
            let result = AppleStructuredWorkflowTaskResult<AppleStructuredContextSuggestionProposal>(
                state: .modelUnavailable,
                payload: nil,
                unavailableReason: .modelUnavailable,
                fallbackCode: .manualContextEditing,
                userMessage: "Apple context suggestion is unavailable right now. Continue editing the article context fields manually.",
                runID: runID,
                schemaVersion: Self.schemaVersion
            )
            await record(result, taskKind: .contextSuggestion, entryPoint: .articleContextPlanning, articleID: snapshot.articleID, startedAt: startedAt)
            return result
        }

        do {
            let generatedProposal = try await contextExecutor(snapshot)
            switch contextMutationAdapter.structuredWorkflowRequests(from: generatedProposal) {
            case .success(let requests):
                let proposal = AppleStructuredContextSuggestionProposal(
                    summary: generatedProposal.summary,
                    audience: generatedProposal.audience,
                    purpose: generatedProposal.purpose,
                    style: generatedProposal.style,
                    keyTakeaway: generatedProposal.keyTakeaway,
                    publishingIntent: generatedProposal.publishingIntent,
                    sourceLinks: generatedProposal.sourceLinks,
                    acceptedFields: requests.map(\.field)
                )
                let result = AppleStructuredWorkflowTaskResult(
                    state: .success,
                    payload: proposal,
                    unavailableReason: nil,
                    fallbackCode: nil,
                    userMessage: "Context suggestions are ready to review.",
                    runID: runID,
                    schemaVersion: Self.schemaVersion
                )
                await record(result, taskKind: .contextSuggestion, entryPoint: .articleContextPlanning, articleID: snapshot.articleID, startedAt: startedAt)
                return result
            case .failure:
                let result = AppleStructuredWorkflowTaskResult<AppleStructuredContextSuggestionProposal>(
                    state: .executionFailed,
                    payload: nil,
                    unavailableReason: .executionFailed,
                    fallbackCode: .manualContextEditing,
                    userMessage: "Apple context suggestion returned fields that could not be mapped. Continue editing the article context fields manually.",
                    runID: runID,
                    schemaVersion: Self.schemaVersion
                )
                await record(result, taskKind: .contextSuggestion, entryPoint: .articleContextPlanning, articleID: snapshot.articleID, startedAt: startedAt)
                return result
            }
        } catch {
            let result = AppleStructuredWorkflowTaskResult<AppleStructuredContextSuggestionProposal>(
                state: .executionFailed,
                payload: nil,
                unavailableReason: .executionFailed,
                fallbackCode: .manualContextEditing,
                userMessage: "Apple context suggestion could not complete. Continue editing the article context fields manually.",
                runID: runID,
                schemaVersion: Self.schemaVersion
            )
            await record(result, taskKind: .contextSuggestion, entryPoint: .articleContextPlanning, articleID: snapshot.articleID, startedAt: startedAt)
            return result
        }
    }

    func summarizeSelectedText(
        text: String,
        selection: EditorSelectionPayload,
        article: Article
    ) async -> AppleStructuredWorkflowTaskResult<SummarizeProposal> {
        let runID = UUID()
        let startedAt = Date()
        let inputSummary = makeInputSummary(selection: selection)
        let normalizedText = text.trimmed

        guard AppleStructuredWorkflowFeatureFlag.summarizeSelection.isEnabled else {
            return await summarizeSelectionFallback(
                text: normalizedText,
                selection: selection,
                articleID: article.id,
                runID: runID,
                startedAt: startedAt,
                reason: .featureFlagDisabled,
                fallbackCode: .manualSelectionEditing,
                userMessage: "We couldn't enhance this right now. Try again later.",
                inputSummary: inputSummary
            )
        }

        guard validateSelectedTextInput(text: normalizedText, selection: selection) else {
            let result = AppleStructuredWorkflowTaskResult<SummarizeProposal>(
                state: .validationFailed,
                payload: nil,
                unavailableReason: .validationFailed,
                fallbackCode: .retrySameAction,
                userMessage: "Select at least 50 characters before summarizing.",
                runID: runID,
                schemaVersion: Self.schemaVersion
            )
            await record(result, taskKind: .summarizeSelection, entryPoint: .articleEditorSelection, articleID: article.id, startedAt: startedAt, inputSummary: inputSummary)
            return result
        }

        switch availabilityEvaluator() {
        case .available:
            break
        case .unsupportedPlatform:
            return await summarizeSelectionFallback(
                text: normalizedText,
                selection: selection,
                articleID: article.id,
                runID: runID,
                startedAt: startedAt,
                reason: .unsupportedPlatform,
                fallbackCode: .manualSelectionEditing,
                userMessage: "We couldn't enhance this right now. Try again later.",
                inputSummary: inputSummary
            )
        case .modelUnavailable:
            return await summarizeSelectionFallback(
                text: normalizedText,
                selection: selection,
                articleID: article.id,
                runID: runID,
                startedAt: startedAt,
                reason: .modelUnavailable,
                fallbackCode: .manualSelectionEditing,
                userMessage: "We couldn't enhance this right now. Try again later.",
                inputSummary: inputSummary
            )
        }

        do {
            let summaryText = try await summarizeSelectionExecutor(normalizedText).trimmed
            guard !summaryText.isEmpty else {
                return await summarizeSelectionFallback(
                    text: normalizedText,
                    selection: selection,
                    articleID: article.id,
                    runID: runID,
                    startedAt: startedAt,
                    reason: .executionFailed,
                    fallbackCode: .retrySameAction,
                    userMessage: "We couldn't enhance this right now. Try again later.",
                    inputSummary: inputSummary
                )
            }

            let payload = SummarizeProposal(
                summarizedText: summaryText,
                wordCount: wordCount(in: summaryText),
                generatedOn: Date()
            )
            let result = AppleStructuredWorkflowTaskResult(
                state: .success,
                payload: payload,
                unavailableReason: nil,
                fallbackCode: nil,
                userMessage: "Summary is ready to review.",
                runID: runID,
                schemaVersion: Self.schemaVersion
            )
            await record(result, taskKind: .summarizeSelection, entryPoint: .articleEditorSelection, articleID: article.id, startedAt: startedAt, inputSummary: inputSummary)
            return result
        } catch {
            return await summarizeSelectionFallback(
                text: normalizedText,
                selection: selection,
                articleID: article.id,
                runID: runID,
                startedAt: startedAt,
                reason: .executionFailed,
                fallbackCode: .retrySameAction,
                userMessage: "We couldn't enhance this right now. Try again later.",
                inputSummary: inputSummary
            )
        }
    }

    func improveSelectedText(
        text: String,
        selection: EditorSelectionPayload,
        article: Article
    ) async -> AppleStructuredWorkflowTaskResult<ImproveProposal> {
        let runID = UUID()
        let startedAt = Date()
        let inputSummary = makeInputSummary(selection: selection)
        let normalizedText = text.trimmed

        guard AppleStructuredWorkflowFeatureFlag.improveSelection.isEnabled else {
            return await improveSelectionFallback(
                originalText: normalizedText,
                articleID: article.id,
                runID: runID,
                startedAt: startedAt,
                reason: .featureFlagDisabled,
                fallbackCode: .manualSelectionEditing,
                userMessage: "This utility isn't available now.",
                inputSummary: inputSummary
            )
        }

        guard validateSelectedTextInput(text: normalizedText, selection: selection) else {
            let result = AppleStructuredWorkflowTaskResult<ImproveProposal>(
                state: .validationFailed,
                payload: nil,
                unavailableReason: .validationFailed,
                fallbackCode: .retrySameAction,
                userMessage: "Select at least 50 characters before improving text.",
                runID: runID,
                schemaVersion: Self.schemaVersion
            )
            await record(result, taskKind: .improveSelection, entryPoint: .articleEditorSelection, articleID: article.id, startedAt: startedAt, inputSummary: inputSummary)
            return result
        }

        switch availabilityEvaluator() {
        case .available:
            break
        case .unsupportedPlatform:
            return await improveSelectionFallback(
                originalText: normalizedText,
                articleID: article.id,
                runID: runID,
                startedAt: startedAt,
                reason: .unsupportedPlatform,
                fallbackCode: .manualSelectionEditing,
                userMessage: "This utility isn't available now.",
                inputSummary: inputSummary
            )
        case .modelUnavailable:
            return await improveSelectionFallback(
                originalText: normalizedText,
                articleID: article.id,
                runID: runID,
                startedAt: startedAt,
                reason: .modelUnavailable,
                fallbackCode: .manualSelectionEditing,
                userMessage: "This utility isn't available now.",
                inputSummary: inputSummary
            )
        }

        do {
            let improvedText = try await improveSelectionExecutor(normalizedText, article.tone.rawValue).trimmed
            guard !improvedText.isEmpty else {
                return await improveSelectionFallback(
                    originalText: normalizedText,
                    articleID: article.id,
                    runID: runID,
                    startedAt: startedAt,
                    reason: .executionFailed,
                    fallbackCode: .retrySameAction,
                    userMessage: "This utility isn't available now.",
                    inputSummary: inputSummary
                )
            }

            let payload = ImproveProposal(
                improvedText: improvedText,
                rationale: "Clarified while preserving original intent.",
                generatedOn: Date()
            )
            let result = AppleStructuredWorkflowTaskResult(
                state: .success,
                payload: payload,
                unavailableReason: nil,
                fallbackCode: nil,
                userMessage: "Improved text is ready to review.",
                runID: runID,
                schemaVersion: Self.schemaVersion
            )
            await record(result, taskKind: .improveSelection, entryPoint: .articleEditorSelection, articleID: article.id, startedAt: startedAt, inputSummary: inputSummary)
            return result
        } catch {
            return await improveSelectionFallback(
                originalText: normalizedText,
                articleID: article.id,
                runID: runID,
                startedAt: startedAt,
                reason: .executionFailed,
                fallbackCode: .retrySameAction,
                userMessage: "This utility isn't available now.",
                inputSummary: inputSummary
            )
        }
    }

    func generateVariants(
        text: String,
        selection: EditorSelectionPayload,
        article: Article
    ) async -> AppleStructuredWorkflowTaskResult<VariantsProposal> {
        let runID = UUID()
        let startedAt = Date()
        let inputSummary = makeInputSummary(selection: selection)
        let normalizedText = text.trimmed

        guard AppleStructuredWorkflowFeatureFlag.generateVariants.isEnabled else {
            return await variantsFallback(
                originalText: normalizedText,
                articleID: article.id,
                runID: runID,
                startedAt: startedAt,
                reason: .featureFlagDisabled,
                fallbackCode: .manualSelectionEditing,
                userMessage: "Variants aren't available now.",
                inputSummary: inputSummary
            )
        }

        guard validateSelectedTextInput(text: normalizedText, selection: selection) else {
            let result = AppleStructuredWorkflowTaskResult<VariantsProposal>(
                state: .validationFailed,
                payload: nil,
                unavailableReason: .validationFailed,
                fallbackCode: .retrySameAction,
                userMessage: "Select at least 50 characters before generating variants.",
                runID: runID,
                schemaVersion: Self.schemaVersion
            )
            await record(result, taskKind: .generateVariants, entryPoint: .articleEditorSelection, articleID: article.id, startedAt: startedAt, inputSummary: inputSummary)
            return result
        }

        switch availabilityEvaluator() {
        case .available:
            break
        case .unsupportedPlatform:
            return await variantsFallback(
                originalText: normalizedText,
                articleID: article.id,
                runID: runID,
                startedAt: startedAt,
                reason: .unsupportedPlatform,
                fallbackCode: .manualSelectionEditing,
                userMessage: "Variants aren't available now.",
                inputSummary: inputSummary
            )
        case .modelUnavailable:
            return await variantsFallback(
                originalText: normalizedText,
                articleID: article.id,
                runID: runID,
                startedAt: startedAt,
                reason: .modelUnavailable,
                fallbackCode: .manualSelectionEditing,
                userMessage: "Variants aren't available now.",
                inputSummary: inputSummary
            )
        }

        do {
            let generated = try await variantsSelectionExecutor(normalizedText, article.tone.rawValue)
            let variants = generated.variants
                .map { $0.trimmed }
                .filter { !$0.isEmpty }
                .prefix(3)
                .map { TextVariant(text: $0, style: nil) }

            guard !variants.isEmpty else {
                return await variantsFallback(
                    originalText: normalizedText,
                    articleID: article.id,
                    runID: runID,
                    startedAt: startedAt,
                    reason: .executionFailed,
                    fallbackCode: .retrySameAction,
                    userMessage: "Variants aren't available now.",
                    inputSummary: inputSummary
                )
            }

            let payload = VariantsProposal(
                variants: Array(variants),
                generatedOn: Date()
            )
            let result = AppleStructuredWorkflowTaskResult(
                state: .success,
                payload: payload,
                unavailableReason: nil,
                fallbackCode: nil,
                userMessage: "Variants are ready to review.",
                runID: runID,
                schemaVersion: Self.schemaVersion
            )
            await record(result, taskKind: .generateVariants, entryPoint: .articleEditorSelection, articleID: article.id, startedAt: startedAt, inputSummary: inputSummary)
            return result
        } catch {
            return await variantsFallback(
                originalText: normalizedText,
                articleID: article.id,
                runID: runID,
                startedAt: startedAt,
                reason: .executionFailed,
                fallbackCode: .retrySameAction,
                userMessage: "Variants aren't available now.",
                inputSummary: inputSummary
            )
        }
    }

    nonisolated static func defaultAvailability() -> AppleWorkflowAvailability {
        guard #available(macOS 26, *) else {
            return .unsupportedPlatform
        }
        if case .available = SystemLanguageModel.default.availability {
            return .available
        }
        return .modelUnavailable
    }

    private func fallbackDraftAutofill(
        seed: DraftAutofillSeed,
        runID: UUID,
        startedAt: Date,
        reason: AppleWorkflowUnavailableReason,
        userMessage: String
    ) async -> AppleStructuredWorkflowTaskResult<DraftAutofillProposal> {
        guard let payload = heuristicDraftAutofillService.fallbackProposal(from: seed) else {
            let result = AppleStructuredWorkflowTaskResult<DraftAutofillProposal>(
                state: reason == .executionFailed ? .executionFailed : .validationFailed,
                payload: nil,
                unavailableReason: reason,
                fallbackCode: .retrySameAction,
                userMessage: "WriteVibe could not derive draft details from this summary yet.",
                runID: runID,
                schemaVersion: Self.schemaVersion
            )
            await record(result, taskKind: .draftAutofill, entryPoint: .articleDraftCreation, articleID: nil, startedAt: startedAt)
            return result
        }

        let result = AppleStructuredWorkflowTaskResult(
            state: .completedWithFallback,
            payload: payload,
            unavailableReason: reason,
            fallbackCode: .localHeuristicDraftAutofill,
            userMessage: userMessage,
            runID: runID,
            schemaVersion: Self.schemaVersion
        )
        await record(result, taskKind: .draftAutofill, entryPoint: .articleDraftCreation, articleID: nil, startedAt: startedAt)
        return result
    }

    private func record<Payload: Sendable>(
        _ result: AppleStructuredWorkflowTaskResult<Payload>,
        taskKind: AppleWorkflowTaskKind,
        entryPoint: AppleWorkflowEntryPoint,
        articleID: UUID?,
        startedAt: Date,
        inputSummary: AppleWorkflowInputSummary? = nil
    ) async {
        await observabilityService.recordRun(
            AppleWorkflowRunArtifact(
                runID: result.runID,
                taskKind: taskKind,
                entryPoint: entryPoint,
                articleID: articleID,
                rolloutPhase: rolloutPhase,
                outcomeState: result.state,
                fallbackCode: result.fallbackCode,
                userMessage: result.userMessage,
                startedAt: startedAt,
                completedAt: Date(),
                schemaVersion: result.schemaVersion,
                inputSummary: inputSummary
            )
        )
    }

    private func isValidOutlineSnapshot(_ snapshot: AppleStructuredPlanningSnapshot) -> Bool {
        !snapshot.title.trimmed.isEmpty || !snapshot.topic.trimmed.isEmpty
    }

    private func isValidContextSnapshot(_ snapshot: AppleStructuredPlanningSnapshot) -> Bool {
        !snapshot.title.trimmed.isEmpty || !snapshot.topic.trimmed.isEmpty || !snapshot.summary.trimmed.isEmpty
    }

    private func validateSelectedTextInput(text: String, selection: EditorSelectionPayload) -> Bool {
        let trimmedSelectedText = selection.selectedText.trimmed
        let token = selection.token.trimmed
        let hasBlockID = selection.blockID != nil
        let range = selection.range
        let selectedLength = (selection.selectedText as NSString).length

        guard !text.isEmpty,
              !trimmedSelectedText.isEmpty,
              !token.isEmpty,
              hasBlockID,
              text.count >= 50,
              text.count <= 50_000,
              range.location >= 0,
              range.length > 0,
              NSMaxRange(range) <= selectedLength else {
            return false
        }
        return true
    }

    private func makeInputSummary(selection: EditorSelectionPayload) -> AppleWorkflowInputSummary {
        AppleWorkflowInputSummary(
            selectionWordCount: wordCount(in: selection.selectedText),
            selectionToken: selection.token,
            blockID: selection.blockID,
            selectionRangeLocation: selection.range.location,
            selectionRangeLength: selection.range.length
        )
    }

    private func summarizeSelectionFallback(
        text: String,
        selection: EditorSelectionPayload,
        articleID: UUID,
        runID: UUID,
        startedAt: Date,
        reason: AppleWorkflowUnavailableReason,
        fallbackCode: AppleWorkflowFallbackCode,
        userMessage: String,
        inputSummary: AppleWorkflowInputSummary
    ) async -> AppleStructuredWorkflowTaskResult<SummarizeProposal> {
        let fallbackSummary = summarizeFallbackText(from: text.isEmpty ? selection.selectedText : text)
        let payload = SummarizeProposal(
            summarizedText: fallbackSummary,
            wordCount: wordCount(in: fallbackSummary),
            generatedOn: Date()
        )
        let result = AppleStructuredWorkflowTaskResult(
            state: .completedWithFallback,
            payload: payload,
            unavailableReason: reason,
            fallbackCode: fallbackCode,
            userMessage: userMessage,
            runID: runID,
            schemaVersion: Self.schemaVersion
        )
        await record(result, taskKind: .summarizeSelection, entryPoint: .articleEditorSelection, articleID: articleID, startedAt: startedAt, inputSummary: inputSummary)
        return result
    }

    private func improveSelectionFallback(
        originalText: String,
        articleID: UUID,
        runID: UUID,
        startedAt: Date,
        reason: AppleWorkflowUnavailableReason,
        fallbackCode: AppleWorkflowFallbackCode,
        userMessage: String,
        inputSummary: AppleWorkflowInputSummary
    ) async -> AppleStructuredWorkflowTaskResult<ImproveProposal> {
        let payload = ImproveProposal(
            improvedText: originalText,
            rationale: nil,
            generatedOn: Date()
        )
        let result = AppleStructuredWorkflowTaskResult(
            state: .completedWithFallback,
            payload: payload,
            unavailableReason: reason,
            fallbackCode: fallbackCode,
            userMessage: userMessage,
            runID: runID,
            schemaVersion: Self.schemaVersion
        )
        await record(result, taskKind: .improveSelection, entryPoint: .articleEditorSelection, articleID: articleID, startedAt: startedAt, inputSummary: inputSummary)
        return result
    }

    private func variantsFallback(
        originalText: String,
        articleID: UUID,
        runID: UUID,
        startedAt: Date,
        reason: AppleWorkflowUnavailableReason,
        fallbackCode: AppleWorkflowFallbackCode,
        userMessage: String,
        inputSummary: AppleWorkflowInputSummary
    ) async -> AppleStructuredWorkflowTaskResult<VariantsProposal> {
        let payload = VariantsProposal(
            variants: [TextVariant(text: originalText, style: nil)],
            generatedOn: Date()
        )
        let result = AppleStructuredWorkflowTaskResult(
            state: .completedWithFallback,
            payload: payload,
            unavailableReason: reason,
            fallbackCode: fallbackCode,
            userMessage: userMessage,
            runID: runID,
            schemaVersion: Self.schemaVersion
        )
        await record(result, taskKind: .generateVariants, entryPoint: .articleEditorSelection, articleID: articleID, startedAt: startedAt, inputSummary: inputSummary)
        return result
    }

    private func summarizeFallbackText(from text: String) -> String {
        let normalized = text.replacingOccurrences(of: "\n", with: " ").trimmed
        guard normalized.count > 220 else {
            return normalized
        }
        let index = normalized.index(normalized.startIndex, offsetBy: 220)
        return "\(normalized[..<index])."
    }

    private func wordCount(in text: String) -> Int {
        text.split { $0.isWhitespace || $0.isNewline }.count
    }
}

// MARK: - AppleIntelligenceService

/// Namespace wrapping FoundationModels for on-device utility generation.
/// Used for conversation auto-title, summarization, and writing suggestions.
@available(macOS 26, *)
@MainActor
enum AppleIntelligenceService {

    @Generable
    struct GeneratedDraftAutofillProposal {
        var title: String
        var subtitle: String
        var tone: String
        var targetLength: String
        var confidenceNotes: [String]
    }

    @Generable
    struct GeneratedContextSuggestionProposal {
        var summary: String
        var audience: String
        var purpose: String
        var style: String
        var keyTakeaway: String
        var publishingIntent: String
        var sourceLinks: String
        var acceptedFields: [String]
    }

    /// True when Apple Intelligence is enabled and this hardware is eligible.
    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    // MARK: - Temperature Constants

    /// Analytical tasks need low variance; creative tasks need high variance.
    enum GenerationTemperature {
        static let analytical: Double = 0.2   // titles, outlines, analysis
        static let balanced: Double   = 0.5   // summarize, suggestions
        static let creative: Double   = 0.9   // variants, improvements
    }

    // MARK: - Structured Generation

    @Generable
    struct ConversationTitle {
        var title: String
    }

    /// Generates a concise title for a conversation based on the first user message.
    static func generateTitle(userMessage: String) async throws -> String {
        let options = GenerationOptions(temperature: GenerationTemperature.analytical)
        let session = LanguageModelSession(
            tools: [DateTimeTool()],
            instructions: "You are a helpful assistant. Generate a short, concise title (3-6 words) for the user's message. Do not use quotes."
        )
        let response = try await session.respond(
            to: "Generate a title for this text: \(userMessage)",
            generating: ConversationTitle.self,
            options: options
        )
        return response.content.title
    }

    // MARK: - Utility Tasks

    /// Summarizes the given text concisely.
    static func summarize(_ text: String) async throws -> String {
        let options = GenerationOptions(temperature: GenerationTemperature.balanced)
        let session = LanguageModelSession(
            tools: [DateTimeTool()],
            instructions: "You are a helpful assistant. Summarize the following text concisely, capturing the main points."
        )
        let response = try await session.respond(to: text, options: options)
        return response.content
    }

    /// Provides writing suggestions for the given text.
    static func suggestImprovements(for text: String) async throws -> String {
        let options = GenerationOptions(temperature: GenerationTemperature.balanced)
        let session = LanguageModelSession(
            instructions: "You are a helpful writing assistant. Provide 3-5 concise, actionable suggestions to improve the following text for clarity, tone, and impact. Format as a bulleted list."
        )
        let response = try await session.respond(to: text, options: options)
        return response.content
    }

    /// Rewrites the given selection for clarity while preserving meaning and scope.
    static func rewriteSelection(_ text: String, tone: String?) async throws -> String {
        let options = GenerationOptions(temperature: GenerationTemperature.balanced)
        let normalizedTone = tone?.trimmed ?? ""
        let toneLine = normalizedTone.isEmpty ? "" : "Tone context: \(normalizedTone)\n"
        let session = LanguageModelSession(
            instructions: "You rewrite selected article text for clarity and flow. Return only the revised text. Preserve the original meaning, scope, and point of view. Do not add commentary, bullets, or quotes."
        )
        let prompt = "\(toneLine)Selected text:\n\(text)"
        let response = try await session.respond(to: prompt, options: options)
        return response.content.trimmed
    }

    /// Analyzes the writing for tone, reading level, word count, readability, and suggestions.
    static func analyzeWriting(text: String) async throws -> WritingAnalysis {
        let options = GenerationOptions(temperature: GenerationTemperature.analytical)
        let session = LanguageModelSession(
            instructions: "You are a helpful writing assistant. Analyze the provided text and return a structured analysis including tone, reading level, word count, sentence count, average words per sentence, passive voice percentage (0–100), a Flesch-Kincaid readability score label, and actionable suggestions for improvement."
        )
        let response = try await session.respond(
            to: text,
            generating: WritingAnalysis.self,
            options: options
        )
        return response.content
    }

    // MARK: - Article Outline

    /// Generates a structured `ArticleOutline` from article metadata using Apple Intelligence.
    static func generateOutline(
        title: String,
        topic: String,
        audience: String,
        targetLength: String
    ) async throws -> ArticleOutline {
        let options = GenerationOptions(temperature: GenerationTemperature.analytical)
        let session = LanguageModelSession(
            tools: [DateTimeTool()],
            instructions: "You are a professional content strategist. Generate a clear, logical article outline."
        )
        let prompt = "Article title: \(title)\nTopic: \(topic)\nTarget audience: \(audience)\nTarget length: \(targetLength)"
        let response = try await session.respond(
            to: prompt,
            generating: ArticleOutline.self,
            options: options
        )
        return response.content
    }

    static func generateDraftAutofill(from seed: DraftAutofillSeed) async throws -> DraftAutofillProposal {
        let options = GenerationOptions(temperature: GenerationTemperature.analytical)
        let session = LanguageModelSession(
            tools: [DateTimeTool()],
            instructions: """
            You generate structured article draft metadata for WriteVibe.
            Return only schema-compliant values.
            Title must be concise and publication-ready.
            Subtitle must complement the title and may be empty.
            Tone must be exactly one of: \(ArticleTone.allCases.map(\.rawValue).joined(separator: ", ")).
            Target length must be exactly one of: \(ArticleLength.allCases.map(\.rawValue).joined(separator: ", ")).
            Confidence notes are internal-only short bullet fragments.
            """
        )
        let prompt = """
        Summary: \(seed.summary)
        Existing title: \(seed.existingTitle ?? "")
        Existing topic: \(seed.existingTopic ?? "")
        """
        let response = try await session.respond(
            to: prompt,
            generating: GeneratedDraftAutofillProposal.self,
            options: options
        )
        let content = response.content
        guard let tone = normalizedTone(content.tone),
              let targetLength = normalizedTargetLength(content.targetLength) else {
            throw WriteVibeError.decodingFailed(context: "Apple structured draft autofill returned unsupported metadata.")
        }
        return DraftAutofillProposal(
            title: content.title.trimmed,
            subtitle: content.subtitle.trimmed,
            tone: tone.rawValue,
            targetLength: targetLength.rawValue,
            confidenceNotes: content.confidenceNotes
        )
    }

    static func generateOutlineSuggestion(from snapshot: AppleStructuredPlanningSnapshot) async throws -> AppleStructuredOutlineSuggestionProposal {
        let outline = try await generateOutline(
            title: snapshot.title,
            topic: snapshot.topic,
            audience: snapshot.audience,
            targetLength: snapshot.targetLength
        )
        return AppleStructuredOutlineSuggestionProposal(
            title: outline.title.trimmed,
            sections: outline.sections.map {
                AppleStructuredOutlineSectionProposal(heading: $0.heading.trimmed, summary: $0.summary.trimmed)
            },
            applyMode: .replaceOutlineText
        )
    }

    static func generateContextSuggestion(from snapshot: AppleStructuredPlanningSnapshot) async throws -> AppleStructuredContextSuggestionProposal {
        let options = GenerationOptions(temperature: GenerationTemperature.analytical)
        let session = LanguageModelSession(
            tools: [DateTimeTool()],
            instructions: """
            You generate structured article context suggestions for WriteVibe.
            Return only schema-compliant values for summary, audience, purpose, style, keyTakeaway, publishingIntent, and sourceLinks.
            acceptedFields must list only these canonical keys when a field should be applied: summary, audience, purpose, style, keytakeaway, publishingintent, sourcelinks.
            Do not return prose outside the schema.
            """
        )
        let prompt = """
        Title: \(snapshot.title)
        Topic: \(snapshot.topic)
        Audience: \(snapshot.audience)
        Summary: \(snapshot.summary)
        Purpose: \(snapshot.purpose)
        Style: \(snapshot.style)
        Key takeaway: \(snapshot.keyTakeaway)
        Publishing intent: \(snapshot.publishingIntent)
        Source links: \(snapshot.sourceLinks)
        Target length: \(snapshot.targetLength)
        Tone: \(snapshot.tone)
        """
        let response = try await session.respond(
            to: prompt,
            generating: GeneratedContextSuggestionProposal.self,
            options: options
        )
        let content = response.content
        return AppleStructuredContextSuggestionProposal(
            summary: content.summary.trimmed,
            audience: content.audience.trimmed,
            purpose: content.purpose.trimmed,
            style: content.style.trimmed,
            keyTakeaway: content.keyTakeaway.trimmed,
            publishingIntent: content.publishingIntent.trimmed,
            sourceLinks: content.sourceLinks.trimmed.isEmpty ? nil : content.sourceLinks.trimmed,
            acceptedFields: content.acceptedFields.map { $0.lowercased().trimmed }
        )
    }

    // MARK: - Draft Variants

    /// Generates three distinct rewrites of the given passage, suitable for the Variants picker.
    static func generateVariants(for text: String, tone: String) async throws -> DraftVariants {
        let options = GenerationOptions(temperature: GenerationTemperature.creative)
        let session = LanguageModelSession(
            instructions: "You are a creative writing assistant. Generate exactly 3 distinct rewrites of the given text. Vary sentence structure, vocabulary, and phrasing significantly between each variant. Tone: \(tone)."
        )
        let response = try await session.respond(
            to: text,
            generating: DraftVariants.self,
            options: options
        )
        return response.content
    }

    // MARK: - Word Count Plan

    /// Estimates per-section word counts for an article given its outline and target length.
    static func generateWordCountPlan(
        title: String,
        outline: String,
        targetLength: String
    ) async throws -> WordCountPlan {
        let options = GenerationOptions(temperature: GenerationTemperature.analytical)
        let session = LanguageModelSession(
            instructions: "You are a professional editor. Estimate word counts per section for an article."
        )
        let prompt = "Article title: \(title)\nOutline:\n\(outline)\nTarget length: \(targetLength)"
        let response = try await session.respond(
            to: prompt,
            generating: WordCountPlan.self,
            options: options
        )
        return response.content
    }

    // MARK: - Streaming Analysis (progress indicator)

    /// Streams raw text tokens during writing analysis so the UI can show a typing indicator
    /// while the structured `analyzeWriting()` call completes in parallel.
    static func analyzeWritingStreaming(text: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let session = LanguageModelSession(
                        instructions: "You are a helpful writing assistant. Briefly describe the writing style and key observations about the following text."
                    )
                    let stream = session.streamResponse(to: text)
                    for try await chunk in stream {
                        continuation.yield(chunk.content)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Prewarm

    /// Touches the default language model to encourage the OS to load its context into memory,
    /// reducing cold-start latency on the next structured generation call.
    /// Safe to call speculatively — fire-and-forget.
    static func prewarm(prefix: String = "") async {
        // FoundationModels does not yet expose a public prewarm API.
        // Accessing the model object is the closest available approximation.
        _ = SystemLanguageModel.default
    }

    private static func normalizedTone(_ rawValue: String) -> ArticleTone? {
        let normalized = rawValue.trimmed
        return ArticleTone.allCases.first { $0.rawValue.caseInsensitiveCompare(normalized) == .orderedSame }
    }

    private static func normalizedTargetLength(_ rawValue: String) -> ArticleLength? {
        let normalized = rawValue.trimmed
        return ArticleLength.allCases.first { $0.rawValue.caseInsensitiveCompare(normalized) == .orderedSame }
    }
}
