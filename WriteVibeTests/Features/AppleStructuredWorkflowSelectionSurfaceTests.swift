import XCTest
@testable import WriteVibe

final class AppleStructuredWorkflowSelectionSurfaceTests: XCTestCase {

    func testSelectionSurfaceActionAffordancesMatchUtilityKind() {
        XCTAssertNil(SelectionWorkflowKind.summarize.primaryActionTitle)
        XCTAssertEqual(SelectionWorkflowKind.improve.primaryActionTitle, "Apply Revision")
        XCTAssertNil(SelectionWorkflowKind.variants.primaryActionTitle)

        XCTAssertFalse(SelectionWorkflowKind.summarize.requiresVariantActions)
        XCTAssertFalse(SelectionWorkflowKind.improve.requiresVariantActions)
        XCTAssertTrue(SelectionWorkflowKind.variants.requiresVariantActions)
    }

    func testSelectionSurfaceFallbackCopyIsDeterministic() {
        XCTAssertEqual(
            SelectionWorkflowKind.summarize.unavailableMessage,
            "Summarize is unavailable right now. Your selected text is unchanged."
        )
        XCTAssertEqual(
            SelectionWorkflowKind.summarize.failureMessage,
            "Summarize could not be completed. Your selected text is unchanged. Please retry."
        )
        XCTAssertEqual(
            SelectionWorkflowKind.summarize.validationMessage,
            "Select more text to summarize."
        )
        XCTAssertEqual(
            SelectionWorkflowKind.summarize.fallbackMessage,
            "Summarize completed with fallback. Your selected text is unchanged."
        )

        XCTAssertEqual(
            SelectionWorkflowKind.improve.unavailableMessage,
            "Improve is unavailable right now. Your selected text is unchanged."
        )
        XCTAssertEqual(
            SelectionWorkflowKind.improve.failureMessage,
            "Improve could not be completed. Your selected text is unchanged. Please retry."
        )
        XCTAssertEqual(
            SelectionWorkflowKind.improve.validationMessage,
            "Select more text to improve."
        )
        XCTAssertEqual(
            SelectionWorkflowKind.improve.fallbackMessage,
            "Improve completed with fallback. Your selected text is unchanged."
        )

        XCTAssertEqual(
            SelectionWorkflowKind.variants.unavailableMessage,
            "Variants are unavailable right now. Your selected text is unchanged."
        )
        XCTAssertEqual(
            SelectionWorkflowKind.variants.failureMessage,
            "Variants could not be generated. Your selected text is unchanged. Please retry."
        )
        XCTAssertEqual(
            SelectionWorkflowKind.variants.validationMessage,
            "Select more text to generate variants."
        )
        XCTAssertEqual(
            SelectionWorkflowKind.variants.fallbackMessage,
            "Variants completed with fallback. Your selected text is unchanged."
        )
    }
}
