import XCTest
@testable import WriteVibe

@MainActor
final class AppleStructuredWorkflowSlice2RoutingTests: XCTestCase {

    func testRouterBlocksGenericChatForSlice2Utilities() {
        let router = DefaultAppleStructuredWorkflowRouter()
        let tasks: [AppleWorkflowTaskKind] = [.summarizeSelection, .improveSelection, .generateVariants]

        for task in tasks {
            let request = AppleWorkflowRouteRequest(
                taskKind: task,
                entryPoint: .genericChat,
                articleID: UUID(),
                hasSelection: true,
                rolloutPhase: .internalValidation,
                featureFlagEnabled: true
            )
            let decision = router.evaluateRoute(for: request)

            switch decision {
            case .blocked(let reason):
                XCTAssertTrue(reason.contains("cannot route through chat"))
            default:
                XCTFail("Expected chat route to be blocked for \(task). Got \(decision)")
            }
        }
    }

    func testRouterBlocksSlice2UtilitiesWithoutSelection() {
        let router = DefaultAppleStructuredWorkflowRouter()
        let tasks: [AppleWorkflowTaskKind] = [.summarizeSelection, .improveSelection, .generateVariants]

        for task in tasks {
            let request = AppleWorkflowRouteRequest(
                taskKind: task,
                entryPoint: .articleEditorSelection,
                articleID: UUID(),
                hasSelection: false,
                rolloutPhase: .internalValidation,
                featureFlagEnabled: true
            )
            let decision = router.evaluateRoute(for: request)

            switch decision {
            case .blocked(let reason):
                XCTAssertTrue(reason.contains("requires an explicit text selection"))
            default:
                XCTFail("Expected missing-selection route to block for \(task). Got \(decision)")
            }
        }
    }

    func testRouterBlocksSlice2UtilitiesAtWrongEntryPoint() {
        let router = DefaultAppleStructuredWorkflowRouter()
        let tasks: [AppleWorkflowTaskKind] = [.summarizeSelection, .improveSelection, .generateVariants]

        for task in tasks {
            let request = AppleWorkflowRouteRequest(
                taskKind: task,
                entryPoint: .articleOutlinePlanning,
                articleID: UUID(),
                hasSelection: true,
                rolloutPhase: .internalValidation,
                featureFlagEnabled: true
            )
            let decision = router.evaluateRoute(for: request)

            switch decision {
            case .blocked:
                break
            default:
                XCTFail("Expected wrong-entry-point route to block for \(task). Got \(decision)")
            }
        }
    }

    func testCoordinatorReturnsFeatureFlagDisabledForSelectionWorkflow() async {
        let coordinator = AppleStructuredWorkflowCoordinator(
            router: DefaultAppleStructuredWorkflowRouter(),
            service: makeService(),
            featureFlagEvaluator: { false }
        )

        let text = String(repeating: "A", count: 80)
        let result = await coordinator.summarizeSelectedText(
            text: text,
            selection: makeSelectionPayload(text: text),
            article: makeArticle()
        )

        XCTAssertEqual(result.state, .featureFlagDisabled)
        XCTAssertNil(result.payload)
        XCTAssertEqual(result.unavailableReason, .featureFlagDisabled)
        XCTAssertEqual(result.fallbackCode, .manualSelectionEditing)
    }

    func testCoordinatorDelegatesToServiceWhenRouteAllowed() async {
        let coordinator = AppleStructuredWorkflowCoordinator(
            router: DefaultAppleStructuredWorkflowRouter(),
            service: makeService()
        )

        let text = String(repeating: "A", count: 80)
        let result = await coordinator.summarizeSelectedText(
            text: text,
            selection: makeSelectionPayload(text: text),
            article: makeArticle()
        )

        XCTAssertEqual(result.state, .success)
        XCTAssertEqual(result.payload?.summarizedText, "Coordinator summary")
    }

    private func makeService() -> AppleStructuredWorkflowService {
        AppleStructuredWorkflowService(
            heuristicDraftAutofillService: Slice2MockArticleDraftAutofillServicing(),
            contextMutationAdapter: ArticleContextMutationAdapter(),
            observabilityService: Slice2SpyAppleWorkflowObservabilityService(),
            availabilityEvaluator: { .available },
            summarizeSelectionExecutor: { _ in "Coordinator summary" }
        )
    }

    private func makeSelectionPayload(text: String) -> EditorSelectionPayload {
        EditorSelectionPayload(
            blockID: UUID(),
            range: NSRange(location: 0, length: (text as NSString).length),
            selectedText: text,
            surroundingContext: "Context",
            token: "routing-token"
        )
    }

    private func makeArticle() -> Article {
        Article(title: "Routing")
    }
}
