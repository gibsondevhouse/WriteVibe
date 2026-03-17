//
//  WritingSessionViewModel.swift
//  WriteVibe
//
//  Holds a persistent `LanguageModelSession` across multiple calls within a single
//  analysis-panel session, enabling iterative rewriting ("make it shorter",
//  "change the tone") without losing prior context.
//
//  Usage:
//    @State private var writingSession = WritingSessionViewModel()
//    // On first prompt the session is lazily created.
//    let response = try await writingSession.respond(to: userText)
//    // On panel close, nil out the session to release memory:
//    writingSession.reset()
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels

// MARK: - WritingSessionViewModel

@available(macOS 26, *)
@MainActor
@Observable
final class WritingSessionViewModel {

    private var session: LanguageModelSession? = nil

    private let instructions = """
        You are a skilled writing coach. You remember the text you have already analyzed \
        and can apply iterative refinements based on follow-up instructions.
        """

    /// Sends a prompt using a persistent session, creating it on first use.
    func respond(to text: String) async throws -> String {
        if session == nil {
            session = LanguageModelSession(instructions: instructions)
        }
        // session is guaranteed non-nil here; the initializer above always succeeds.
        let response = try await session!.respond(to: text)  // swiftlint:disable:this force_unwrapping
        return response.content
    }

    /// Releases the session and its transcript from memory.
    /// Call this when the analysis panel closes.
    func reset() {
        session = nil
    }
}
#endif
