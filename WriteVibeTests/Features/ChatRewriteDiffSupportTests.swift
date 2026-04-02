//
//  ChatRewriteDiffSupportTests.swift
//  WriteVibeTests
//

import Testing
@testable import WriteVibe

struct ChatRewriteDiffSupportTests {

    @Test func preview_detectsInlineImprovePromptAndBuildsDiff() {
        let preview = ChatRewriteDiffSupport.preview(
            userPrompt: "Improve this: The launch plan is good but very vague.",
            assistantResponse: "The launch plan is promising but still lacks specificity."
        )

        #expect(preview?.action == .improve)
        #expect(preview?.sourceText == "The launch plan is good but very vague.")
        #expect(preview?.rewrittenText == "The launch plan is promising but still lacks specificity.")
        #expect(preview?.spans.isEmpty == false)
    }

    @Test func preview_detectsMultilineShortenPrompt() {
        let preview = ChatRewriteDiffSupport.preview(
            userPrompt: "Shorten this:\n\nThe product shipped with a very large amount of needless ceremony.",
            assistantResponse: "The product shipped with needless ceremony."
        )

        #expect(preview?.action == .shorten)
        #expect(preview?.sourceText == "The product shipped with a very large amount of needless ceremony.")
        #expect(preview?.spans.contains(where: { $0.changeType == .delete || $0.changeType == .replace }) == true)
    }

    @Test func preview_returnsNilForNonRewritePrompt() {
        let preview = ChatRewriteDiffSupport.preview(
            userPrompt: "What should we launch next quarter?",
            assistantResponse: "You should prioritize retention work."
        )

        #expect(preview == nil)
    }

    @Test func extractRewriteBody_stripsCommonPrefaceParagraph() {
        let extracted = ChatRewriteDiffSupport.extractRewriteBody(
            from: "Here's a rephrased version:\n\nThe meeting starts at noon and ends at one."
        )

        #expect(extracted == "The meeting starts at noon and ends at one.")
    }

    @Test func extractRewriteBody_usesSingleCodeFenceWhenPresent() {
        let extracted = ChatRewriteDiffSupport.extractRewriteBody(
            from: "```markdown\nA tighter rewritten sentence.\n```"
        )

        #expect(extracted == "A tighter rewritten sentence.")
    }
}