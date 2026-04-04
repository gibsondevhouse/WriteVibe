import Foundation
@testable import WriteVibe

@MainActor
final class Slice2MockArticleDraftAutofillServicing: ArticleDraftAutofillServicing {
    var autofillResult = ArticleDraftAutofillResult(
        title: nil,
        subtitle: nil,
        tone: nil,
        targetLength: nil
    )
    var fallbackProposalResult: DraftAutofillProposal?

    func autofill(from summary: String) -> ArticleDraftAutofillResult {
        autofillResult
    }

    func fallbackProposal(from seed: DraftAutofillSeed) -> DraftAutofillProposal? {
        fallbackProposalResult
    }
}

@MainActor
final class Slice2SpyAppleWorkflowObservabilityService: AppleWorkflowObservabilityServicing {
    private(set) var recordedArtifacts: [AppleWorkflowRunArtifact] = []

    func recordRun(_ artifact: AppleWorkflowRunArtifact) async {
        recordedArtifacts.append(artifact)
    }
}
