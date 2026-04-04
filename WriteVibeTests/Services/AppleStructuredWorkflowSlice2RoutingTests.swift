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
            case .unavailable:
                break
            default:
                XCTFail("Expected missing-selection route to block/unavailable for \(task). Got \(decision)")
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
}
