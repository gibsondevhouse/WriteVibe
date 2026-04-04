//
//  AppleStructuredWorkflowSlice1Tests.swift
//  WriteVibeTests
//
//  Unit tests for DefaultAppleStructuredWorkflowRouter and
//  AppleStructuredWorkflowService (Slice 1 coverage).
//  Uses XCTest. Does not modify production source files.
//

import XCTest
@testable import WriteVibe

// MARK: - Mock: ArticleDraftAutofillServicing

@MainActor
private final class MockArticleDraftAutofillServicing: ArticleDraftAutofillServicing {
    var autofillResult = ArticleDraftAutofillResult(
        title: nil, subtitle: nil, tone: nil, targetLength: nil
    )
    var fallbackProposalResult: DraftAutofillProposal?

    func autofill(from summary: String) -> ArticleDraftAutofillResult {
        autofillResult
    }

    func fallbackProposal(from seed: DraftAutofillSeed) -> DraftAutofillProposal? {
        fallbackProposalResult
    }
}

// MARK: - Spy: AppleWorkflowObservabilityServicing

@MainActor
private final class SpyAppleWorkflowObservabilityService: AppleWorkflowObservabilityServicing {
    private(set) var recordedArtifacts: [AppleWorkflowRunArtifact] = []

    func recordRun(_ artifact: AppleWorkflowRunArtifact) async {
        recordedArtifacts.append(artifact)
    }
}

// MARK: - Tests

@MainActor
final class AppleStructuredWorkflowSlice1Tests: XCTestCase {

    // MARK: – Snapshot factory helpers

    private func makeOutlineSnapshot(title: String = "", topic: String = "") -> AppleStructuredPlanningSnapshot {
        AppleStructuredPlanningSnapshot(
            articleID: UUID(),
            title: title,
            topic: topic,
            audience: "Developers",
            summary: "A summary",
            outline: "",
            purpose: "",
            style: "",
            keyTakeaway: "",
            publishingIntent: "",
            sourceLinks: "",
            targetLength: ArticleLength.medium.rawValue,
            tone: ArticleTone.informative.rawValue,
            updatedAt: Date()
        )
    }

    private func makeContextSnapshot(
        title: String = "",
        topic: String = "",
        summary: String = ""
    ) -> AppleStructuredPlanningSnapshot {
        AppleStructuredPlanningSnapshot(
            articleID: UUID(),
            title: title,
            topic: topic,
            audience: "Developers",
            summary: summary,
            outline: "",
            purpose: "",
            style: "",
            keyTakeaway: "",
            publishingIntent: "",
            sourceLinks: "",
            targetLength: ArticleLength.medium.rawValue,
            tone: ArticleTone.informative.rawValue,
            updatedAt: Date()
        )
    }

    // MARK: – 1. Router blocks generic chat entry point (direct router unit test)

    func testRouterBlocksGenericChatEntryPointDirectly() {
        // Uses .draftAutofill to confirm generic-chat blocking is task-kind-agnostic.
        let router = DefaultAppleStructuredWorkflowRouter()
        let request = AppleWorkflowRouteRequest(
            taskKind: .draftAutofill,
            entryPoint: .genericChat,
            articleID: nil,
            hasSelection: false,
            rolloutPhase: .internalValidation,
            featureFlagEnabled: true
        )
        let decision = router.evaluateRoute(for: request)

        switch decision {
        case .blocked(let reason):
            XCTAssertTrue(
                reason.contains("cannot route through chat"),
                "Blocked reason should mention 'cannot route through chat'. Got: \(reason)"
            )
        default:
            XCTFail("Expected .blocked for genericChat entry point, got \(decision)")
        }
    }

    // MARK: – 2. Router blocks when feature flag is disabled

    func testRouterReturnsUnavailableWhenFeatureFlagDisabled() {
        let router = DefaultAppleStructuredWorkflowRouter()
        let request = AppleWorkflowRouteRequest(
            taskKind: .draftAutofill,
            entryPoint: .articleDraftCreation,
            articleID: nil,
            hasSelection: false,
            rolloutPhase: .internalValidation,
            featureFlagEnabled: false
        )
        let decision = router.evaluateRoute(for: request)

        switch decision {
        case .unavailable(let reason, _):
            XCTAssertEqual(reason, .featureFlagDisabled)
        default:
            XCTFail("Expected .unavailable(reason: .featureFlagDisabled, …), got \(decision)")
        }
    }

    // MARK: – 3. Router blocks selected-text tasks without selection

    func testRouterBlocksSelectionTaskWithoutSelection() {
        // .summarizeSelection is not in Slice 1's supportedTaskKinds, so the
        // router blocks it before the selection check. The outcome is still .blocked.
        let router = DefaultAppleStructuredWorkflowRouter()
        let request = AppleWorkflowRouteRequest(
            taskKind: .summarizeSelection,
            entryPoint: .articleEditorSelection,
            articleID: UUID(),
            hasSelection: false,
            rolloutPhase: .internalValidation,
            featureFlagEnabled: true
        )
        let decision = router.evaluateRoute(for: request)

        switch decision {
        case .blocked:
            break // Expected: task not enabled in slice 1 or selection required
        case .unavailable:
            break // Also acceptable if availability check fires first
        case .allowed:
            XCTFail("Expected .blocked or .unavailable for selection task without selection, got .allowed")
        }
    }

    // MARK: – 4. Router blocks outline task at wrong entry point

    func testRouterBlocksOutlineTaskAtArticleDraftCreationEntryPoint() {
        let router = DefaultAppleStructuredWorkflowRouter()
        let request = AppleWorkflowRouteRequest(
            taskKind: .outlineSuggestion,
            entryPoint: .articleDraftCreation, // Wrong: should be .articleOutlinePlanning
            articleID: UUID(),
            hasSelection: false,
            rolloutPhase: .internalValidation,
            featureFlagEnabled: true
        )
        let decision = router.evaluateRoute(for: request)

        switch decision {
        case .blocked:
            break // Expected
        default:
            XCTFail("Expected .blocked for outline task at articleDraftCreation entry point, got \(decision)")
        }
    }

    // MARK: – 5. Service returns validationFailed for empty summary

    func testServiceReturnsValidationFailedForEmptySummary() async {
        let spy = SpyAppleWorkflowObservabilityService()
        let service = AppleStructuredWorkflowService(
            heuristicDraftAutofillService: MockArticleDraftAutofillServicing(),
            contextMutationAdapter: ArticleContextMutationAdapter(),
            observabilityService: spy,
            availabilityEvaluator: { .available }
        )

        let result = await service.autofillDraft(from: "", articleSnapshot: nil)

        XCTAssertEqual(result.state, .validationFailed)
        XCTAssertNil(result.payload)
    }

    // MARK: – 6. Service falls back to heuristic on unsupported platform

    func testServiceFallsBackToHeuristicWhenPlatformUnsupported() async {
        let mockAutofill = MockArticleDraftAutofillServicing()
        mockAutofill.fallbackProposalResult = DraftAutofillProposal(
            title: "Heuristic Title",
            subtitle: "Heuristic Subtitle",
            tone: ArticleTone.informative.rawValue,
            targetLength: ArticleLength.medium.rawValue,
            confidenceNotes: ["Local heuristic path"]
        )
        let spy = SpyAppleWorkflowObservabilityService()
        let service = AppleStructuredWorkflowService(
            heuristicDraftAutofillService: mockAutofill,
            contextMutationAdapter: ArticleContextMutationAdapter(),
            observabilityService: spy,
            availabilityEvaluator: { .unsupportedPlatform }
        )

        let result = await service.autofillDraft(
            from: "This article explores how AI reshapes software engineering teams.",
            articleSnapshot: nil
        )

        XCTAssertEqual(result.state, .completedWithFallback)
        XCTAssertNotNil(result.payload)
    }

    // MARK: – 7. Service falls back (completedWithFallback or executionFailed) on executor throw

    func testServiceFallsBackWhenDraftExecutorThrows() async {
        let mockAutofill = MockArticleDraftAutofillServicing()
        mockAutofill.fallbackProposalResult = DraftAutofillProposal(
            title: "Fallback Title",
            subtitle: "Fallback Subtitle",
            tone: ArticleTone.informative.rawValue,
            targetLength: ArticleLength.medium.rawValue,
            confidenceNotes: []
        )
        let spy = SpyAppleWorkflowObservabilityService()
        let service = AppleStructuredWorkflowService(
            heuristicDraftAutofillService: mockAutofill,
            contextMutationAdapter: ArticleContextMutationAdapter(),
            observabilityService: spy,
            availabilityEvaluator: { .available },
            draftAutofillExecutor: { _ in
                throw WriteVibeError.generationFailed(reason: "Simulated executor failure")
            }
        )

        let result = await service.autofillDraft(
            from: "AI-driven teams produce better outcomes using async programming models.",
            articleSnapshot: nil
        )

        let isExpected = result.state == .completedWithFallback || result.state == .executionFailed
        XCTAssertTrue(
            isExpected,
            "Expected .completedWithFallback or .executionFailed, got \(result.state)"
        )
    }

    // MARK: – 8. Service returns validationFailed for outline with no title or topic

    func testServiceReturnsValidationFailedForOutlineWhenTitleAndTopicEmpty() async {
        let spy = SpyAppleWorkflowObservabilityService()
        let service = AppleStructuredWorkflowService(
            heuristicDraftAutofillService: MockArticleDraftAutofillServicing(),
            contextMutationAdapter: ArticleContextMutationAdapter(),
            observabilityService: spy,
            availabilityEvaluator: { .available }
        )

        let result = await service.suggestOutline(from: makeOutlineSnapshot(title: "", topic: ""))

        XCTAssertEqual(result.state, .validationFailed)
        XCTAssertNil(result.payload)
        XCTAssertEqual(result.unavailableReason, .validationFailed)
    }

    // MARK: – 9. Service outline execution success path

    func testServiceOutlineExecutorSuccessYieldsSuccessState() async {
        let spy = SpyAppleWorkflowObservabilityService()
        let expectedProposal = AppleStructuredOutlineSuggestionProposal(
            title: "Swift Concurrency Deep Dive",
            sections: [
                AppleStructuredOutlineSectionProposal(heading: "Introduction", summary: "Async/await overview"),
                AppleStructuredOutlineSectionProposal(heading: "Structured Concurrency", summary: "Task trees and actors")
            ],
            applyMode: .replaceOutlineText
        )
        let service = AppleStructuredWorkflowService(
            heuristicDraftAutofillService: MockArticleDraftAutofillServicing(),
            contextMutationAdapter: ArticleContextMutationAdapter(),
            observabilityService: spy,
            availabilityEvaluator: { .available },
            outlineExecutor: { _ in expectedProposal }
        )

        let result = await service.suggestOutline(
            from: makeOutlineSnapshot(title: "Swift Concurrency", topic: "concurrency")
        )

        XCTAssertEqual(result.state, .success)
        XCTAssertNotNil(result.payload)
        XCTAssertEqual(result.payload?.title, "Swift Concurrency Deep Dive")
        XCTAssertFalse(result.payload?.sections.isEmpty ?? true)
    }

    // MARK: – 10. Context suggestion validation failure

    func testServiceReturnsValidationFailedForContextWhenAllSnapshotFieldsEmpty() async {
        let spy = SpyAppleWorkflowObservabilityService()
        let service = AppleStructuredWorkflowService(
            heuristicDraftAutofillService: MockArticleDraftAutofillServicing(),
            contextMutationAdapter: ArticleContextMutationAdapter(),
            observabilityService: spy,
            availabilityEvaluator: { .available }
        )

        let result = await service.suggestContext(
            from: makeContextSnapshot(title: "", topic: "", summary: "")
        )

        XCTAssertEqual(result.state, .validationFailed)
        XCTAssertNil(result.payload)
    }

    // MARK: – 11. Context suggestion execution success with adapter validation

    func testServiceContextExecutorSuccessYieldsSuccessStateWithAcceptedFields() async {
        let spy = SpyAppleWorkflowObservabilityService()
        // All non-empty context fields use passthrough validation in the adapter matrix,
        // so any non-empty string produces a valid ArticleContextMutationRequest.
        let contextProposal = AppleStructuredContextSuggestionProposal(
            summary: "A practical exploration of Swift Concurrency patterns.",
            audience: "iOS and macOS developers",
            purpose: "Educate engineers on structured concurrency",
            style: "Technical",
            keyTakeaway: "Prefer async/await over callbacks for clarity and safety",
            publishingIntent: "Engineering blog post",
            sourceLinks: "https://swift.org/documentation/concurrency",
            acceptedFields: []
        )
        let service = AppleStructuredWorkflowService(
            heuristicDraftAutofillService: MockArticleDraftAutofillServicing(),
            contextMutationAdapter: ArticleContextMutationAdapter(),
            observabilityService: spy,
            availabilityEvaluator: { .available },
            contextExecutor: { _ in contextProposal }
        )

        let result = await service.suggestContext(
            from: makeContextSnapshot(
                title: "Swift Concurrency Guide",
                topic: "concurrency",
                summary: "About async patterns in Swift"
            )
        )

        XCTAssertEqual(result.state, .success)
        XCTAssertNotNil(result.payload)
        XCTAssertFalse(result.payload?.acceptedFields.isEmpty ?? true)
    }

    // MARK: – 12. Observability artifact recorded on every run (autofillDraft path)

    func testObservabilityArtifactRecordedOnAutofillDraftRun() async {
        let spy = SpyAppleWorkflowObservabilityService()
        let service = AppleStructuredWorkflowService(
            heuristicDraftAutofillService: MockArticleDraftAutofillServicing(),
            contextMutationAdapter: ArticleContextMutationAdapter(),
            observabilityService: spy,
            availabilityEvaluator: { .available },
            draftAutofillExecutor: { _ in
                DraftAutofillProposal(
                    title: "AI at Scale",
                    subtitle: "How enterprise teams adapt",
                    tone: ArticleTone.informative.rawValue,
                    targetLength: ArticleLength.medium.rawValue,
                    confidenceNotes: []
                )
            }
        )

        _ = await service.autofillDraft(
            from: "This article covers the economics of AI adoption across enterprise software teams.",
            articleSnapshot: nil
        )

        XCTAssertEqual(spy.recordedArtifacts.count, 1)
        XCTAssertEqual(spy.recordedArtifacts.first?.taskKind, .draftAutofill)
    }

    // MARK: – 13. AppleIntelligenceService is blocked for chat routing

    func testAppleIntelligenceChatProviderStreamThrowsGenerationFailed() async {
        let container = ServiceContainer()
        let provider = container.provider(for: .appleIntelligence)
        let stream = provider.stream(model: "Apple Intelligence", messages: [], systemPrompt: "")

        var caughtGenerationFailed = false
        do {
            for try await _ in stream {
                XCTFail("Stream should throw immediately — no chunks expected")
            }
        } catch let error as WriteVibeError {
            switch error {
            case .generationFailed:
                caughtGenerationFailed = true
            default:
                XCTFail("Expected WriteVibeError.generationFailed, got \(error)")
            }
        } catch {
            XCTFail("Expected WriteVibeError.generationFailed, got unexpected error: \(error)")
        }

        XCTAssertTrue(caughtGenerationFailed, "Stream must throw WriteVibeError.generationFailed")
    }
}
