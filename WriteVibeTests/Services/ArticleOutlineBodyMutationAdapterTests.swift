import Testing
import Foundation
import SwiftData
@testable import WriteVibe

// MARK: - Outline Adapter Tests

@Suite(.serialized)
@MainActor
struct ArticleOutlineMutationAdapterTests {
    private let adapter = ArticleOutlineMutationAdapter()

    private func makeArticle(outline: String = "") -> Article {
        let a = Article(title: "Test", subtitle: "", topic: "", tone: .conversational, targetLength: .medium)
        a.outline = outline
        return a
    }

    // MARK: Append

    @Test func testAppendToEmptyOutline() {
        let article = makeArticle(outline: "")
        let req = ArticleOutlineMutationRequest(operation: "append", index: nil, value: "1. Introduction")
        switch adapter.apply(req, to: article) {
        case .success(let result):
            #expect(result.operation == "append")
            #expect(article.outline == "1. Introduction")
            #expect(result.lineCount == 1)
        case .failure(let e):
            Issue.record("Expected success, got \(e)")
        }
    }

    @Test func testAppendToExistingOutline() {
        let article = makeArticle(outline: "1. Introduction")
        let req = ArticleOutlineMutationRequest(operation: "append", index: nil, value: "2. Background")
        switch adapter.apply(req, to: article) {
        case .success(let result):
            #expect(article.outline == "1. Introduction\n2. Background")
            #expect(result.lineCount == 2)
        case .failure(let e):
            Issue.record("Expected success, got \(e)")
        }
    }

    @Test func testAppendUpdatesTimestamp() {
        let article = makeArticle(outline: "")
        let before = article.updatedAt
        let req = ArticleOutlineMutationRequest(operation: "append", index: nil, value: "Line")
        _ = adapter.apply(req, to: article)
        #expect(article.updatedAt >= before)
    }

    // MARK: Replace

    @Test func testReplaceFirstLine() {
        let article = makeArticle(outline: "Old\nSecond\nThird")
        let req = ArticleOutlineMutationRequest(operation: "replace", index: 1, value: "Replaced")
        switch adapter.apply(req, to: article) {
        case .success:
            #expect(article.outline == "Replaced\nSecond\nThird")
        case .failure(let e):
            Issue.record("Expected success, got \(e)")
        }
    }

    @Test func testReplaceLastLine() {
        let article = makeArticle(outline: "First\nSecond\nOld")
        let req = ArticleOutlineMutationRequest(operation: "replace", index: 3, value: "New Third")
        switch adapter.apply(req, to: article) {
        case .success:
            #expect(article.outline == "First\nSecond\nNew Third")
        case .failure(let e):
            Issue.record("Expected success, got \(e)")
        }
    }

    @Test func testReplaceOutOfRangeReturnsError() {
        let article = makeArticle(outline: "Only one line")
        let req = ArticleOutlineMutationRequest(operation: "replace", index: 5, value: "X")
        switch adapter.apply(req, to: article) {
        case .success:
            Issue.record("Expected failure for out-of-range index")
        case .failure(let e):
            #expect(e.code == "CMD-007-INVALID_INDEX")
            #expect(e.message.contains("5"))
        }
    }

    @Test func testReplaceZeroIndexReturnsError() {
        let article = makeArticle(outline: "Line")
        let req = ArticleOutlineMutationRequest(operation: "replace", index: 0, value: "X")
        switch adapter.apply(req, to: article) {
        case .success:
            Issue.record("Expected failure for zero index")
        case .failure(let e):
            #expect(e.code == "CMD-007-INVALID_INDEX")
        }
    }

    @Test func testUnknownOperationReturnsError() {
        let article = makeArticle()
        let req = ArticleOutlineMutationRequest(operation: "delete", index: nil, value: "X")
        switch adapter.apply(req, to: article) {
        case .success:
            Issue.record("Expected failure for unknown operation")
        case .failure(let e):
            #expect(e.code == "CMD-004-UNKNOWN_VERB")
        }
    }

    @Test func testStructuredWorkflowSuggestionReplacesOutlineText() {
        let article = makeArticle(outline: "Old line")
        let proposal = AppleStructuredOutlineSuggestionProposal(
            title: "Planning",
            sections: [
                AppleStructuredOutlineSectionProposal(heading: "Opening", summary: "Frame the problem."),
                AppleStructuredOutlineSectionProposal(heading: "Decision", summary: "Explain the tradeoffs.")
            ],
            applyMode: .replaceOutlineText
        )

        switch adapter.applyStructuredWorkflowSuggestion(proposal, to: article) {
        case .success(let result):
            #expect(result.operation == "replaceOutlineText")
            #expect(article.outline == "1. Opening\n   Frame the problem.\n2. Decision\n   Explain the tradeoffs.")
        case .failure(let error):
            Issue.record("Expected outline replacement success, got \(error)")
        }
    }

    @Test func testStructuredWorkflowSuggestionRejectsInsertBlocksApplyMode() {
        let article = makeArticle(outline: "Old line")
        let proposal = AppleStructuredOutlineSuggestionProposal(
            title: "Planning",
            sections: [AppleStructuredOutlineSectionProposal(heading: "Opening", summary: "Frame the problem.")],
            applyMode: .insertBlocks
        )

        switch adapter.applyStructuredWorkflowSuggestion(proposal, to: article) {
        case .success:
            Issue.record("Expected insertBlocks apply mode to be rejected")
        case .failure(let error):
            #expect(error.code == "CMD-012-UNSUPPORTED_OUTLINE_APPLY_MODE")
        }
    }
}

// MARK: - Body Adapter Tests

@Suite(.serialized)
@MainActor
struct ArticleBodyMutationAdapterTests {
    private let adapter = ArticleBodyMutationAdapter()

    private func makeArticle() -> Article {
        let a = Article(title: "Test", subtitle: "", topic: "", tone: .conversational, targetLength: .medium)
        // H1 title block at position 0
        a.blocks = [ArticleBlock(type: .heading(level: 1), content: "Test", position: 0)]
        return a
    }

    // MARK: Append

    @Test func testAppendAddsParagraphBlock() {
        let article = makeArticle()
        let req = ArticleBodyMutationRequest(operation: "append", blockType: nil, index: nil, value: "Hello world")
        switch adapter.apply(req, to: article) {
        case .success(let result):
            #expect(result.operation == "append")
            #expect(article.blocks.count == 2)
            let body = article.bodyBlocks
            #expect(body.last?.content == "Hello world")
            #expect(body.last?.blockType == .paragraph)
        case .failure(let e):
            Issue.record("Expected success, got \(e)")
        }
    }

    @Test func testAppendPositionIsAfterLast() {
        let article = makeArticle()
        // Add an existing body block at position 5
        article.blocks.append(ArticleBlock(type: .paragraph, content: "Existing", position: 5))
        let req = ArticleBodyMutationRequest(operation: "append", blockType: nil, index: nil, value: "New")
        switch adapter.apply(req, to: article) {
        case .success:
            let sortedBlocks = article.sortedBlocks
            #expect(sortedBlocks.last?.content == "New")
            #expect(sortedBlocks.last!.position > 5)
        case .failure(let e):
            Issue.record("Expected success, got \(e)")
        }
    }

    @Test func testAppendUpdatesTimestamp() {
        let article = makeArticle()
        let before = article.updatedAt
        let req = ArticleBodyMutationRequest(operation: "append", blockType: nil, index: nil, value: "Content")
        _ = adapter.apply(req, to: article)
        #expect(article.updatedAt >= before)
    }

    // MARK: Insert Paragraph

    @Test func testInsertParagraphAtPositionOne() {
        let article = makeArticle()
        // Add two body blocks
        article.blocks.append(ArticleBlock(type: .paragraph, content: "First", position: 1))
        article.blocks.append(ArticleBlock(type: .paragraph, content: "Second", position: 2))

        let req = ArticleBodyMutationRequest(operation: "insert", blockType: "paragraph", index: 1, value: "Inserted")
        switch adapter.apply(req, to: article) {
        case .success(let result):
            #expect(result.blockCount == 4)  // H1 + 2 original + 1 inserted
            let body = article.bodyBlocks
            #expect(body[0].content == "Inserted")
            #expect(body[1].content == "First")
            #expect(body[2].content == "Second")
        case .failure(let e):
            Issue.record("Expected success, got \(e)")
        }
    }

    @Test func testInsertHeadingProducesH2Block() {
        let article = makeArticle()
        article.blocks.append(ArticleBlock(type: .paragraph, content: "Body", position: 1))

        let req = ArticleBodyMutationRequest(operation: "insert", blockType: "heading", index: 1, value: "Section")
        switch adapter.apply(req, to: article) {
        case .success:
            let body = article.bodyBlocks
            let inserted = body.first { $0.content == "Section" }
            #expect(inserted?.blockType == .heading(level: 2))
        case .failure(let e):
            Issue.record("Expected success, got \(e)")
        }
    }

    @Test func testInsertAtEndEquivalentToAppend() {
        let article = makeArticle()
        article.blocks.append(ArticleBlock(type: .paragraph, content: "Only", position: 1))

        // bodyBlocks.count == 1, so index 2 is one past the end
        let req = ArticleBodyMutationRequest(operation: "insert", blockType: "paragraph", index: 2, value: "After")
        switch adapter.apply(req, to: article) {
        case .success:
            let body = article.bodyBlocks
            #expect(body.last?.content == "After")
        case .failure(let e):
            Issue.record("Expected success, got \(e)")
        }
    }

    @Test func testInsertOutOfRangeReturnsError() {
        let article = makeArticle()
        // No body blocks, so only index 1 is valid (insert at end)
        let req = ArticleBodyMutationRequest(operation: "insert", blockType: "paragraph", index: 5, value: "X")
        switch adapter.apply(req, to: article) {
        case .success:
            Issue.record("Expected failure for out-of-range index")
        case .failure(let e):
            #expect(e.code == "CMD-007-INVALID_INDEX")
        }
    }

    @Test func testInsertInvalidBlockTypeReturnsError() {
        let article = makeArticle()
        let req = ArticleBodyMutationRequest(operation: "insert", blockType: "image", index: 1, value: "X")
        switch adapter.apply(req, to: article) {
        case .success:
            Issue.record("Expected failure for invalid block type")
        case .failure(let e):
            #expect(e.code == "CMD-005-MISSING_ARGUMENT")
        }
    }

    @Test func testInsertZeroIndexReturnsError() {
        let article = makeArticle()
        let req = ArticleBodyMutationRequest(operation: "insert", blockType: "paragraph", index: 0, value: "X")
        switch adapter.apply(req, to: article) {
        case .success:
            Issue.record("Expected failure for zero index")
        case .failure(let e):
            #expect(e.code == "CMD-007-INVALID_INDEX")
        }
    }

    @Test func testUnknownOperationReturnsError() {
        let article = makeArticle()
        let req = ArticleBodyMutationRequest(operation: "delete", blockType: nil, index: nil, value: "X")
        switch adapter.apply(req, to: article) {
        case .success:
            Issue.record("Expected failure for unknown operation")
        case .failure(let e):
            #expect(e.code == "CMD-004-UNKNOWN_VERB")
        }
    }
}

// MARK: - Command Dispatch Integration Tests for outline/body

@Suite(.serialized)
@MainActor
struct OutlineBodyCommandDispatchTests {
    private let service = CommandExecutionService()
    private let conversationId = UUID()
    private let articleId = UUID()

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Conversation.self, Message.self, Article.self, ArticleBlock.self, ArticleDraft.self, Series.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return container.mainContext
    }

    private func articleContext(id: UUID? = nil) -> CommandExecutionService.ArticleContext {
        let resolvedId = id ?? articleId
        return CommandExecutionService.ArticleContext(
            hasArticleContext: true,
            articleId: resolvedId.uuidString,
            articleTitle: "Test Article"
        )
    }

    // MARK: outline append

    @Test func testOutlineAppendDispatchSucceeds() throws {
        let result = service.dispatch(
            input: "/article outline append \"1. Introduction\"",
            conversationId: conversationId,
            context: try makeContext(),
            articleContext: articleContext()
        )
        guard case .handled(let env) = result else {
            Issue.record("Expected handled"); return
        }
        #expect(env.ok)
        #expect(env.command.verb == "outline")
        #expect(env.command.subverb == "append")
        #expect(env.outlineOperation?.operation == "append")
        #expect(env.outlineOperation?.value == "1. Introduction")
    }

    @Test func testOutlineAppendRequiresArticleContext() throws {
        let result = service.dispatch(
            input: "/article outline append \"value\"",
            conversationId: conversationId,
            context: try makeContext()
        )
        guard case .handled(let env) = result else {
            Issue.record("Expected handled"); return
        }
        #expect(!env.ok)
        #expect(env.error?.code == "CMD-010-STATE_ERROR")
    }

    // MARK: outline replace

    @Test func testOutlineReplaceDispatchSucceeds() throws {
        let result = service.dispatch(
            input: "/article outline replace 2 \"Updated line\" --confirm",
            conversationId: conversationId,
            context: try makeContext(),
            articleContext: articleContext()
        )
        guard case .handled(let env) = result else {
            Issue.record("Expected handled"); return
        }
        #expect(env.ok)
        #expect(env.outlineOperation?.operation == "replace")
        #expect(env.outlineOperation?.index == 2)
        #expect(env.outlineOperation?.value == "Updated line")
    }

    @Test func testOutlineReplaceRequiresConfirm() throws {
        let result = service.dispatch(
            input: "/article outline replace 1 \"Without confirm\"",
            conversationId: conversationId,
            context: try makeContext(),
            articleContext: articleContext()
        )
        guard case .handled(let env) = result else {
            Issue.record("Expected handled"); return
        }
        #expect(!env.ok)
        #expect(env.error?.code == "CMD-009-CONFIRMATION_REQUIRED")
    }

    // MARK: body append

    @Test func testBodyAppendDispatchSucceeds() throws {
        let result = service.dispatch(
            input: "/article body append \"New paragraph content\"",
            conversationId: conversationId,
            context: try makeContext(),
            articleContext: articleContext()
        )
        guard case .handled(let env) = result else {
            Issue.record("Expected handled"); return
        }
        #expect(env.ok)
        #expect(env.bodyOperation?.operation == "append")
        #expect(env.bodyOperation?.value == "New paragraph content")
    }

    @Test func testBodyAppendRequiresArticleContext() throws {
        let result = service.dispatch(
            input: "/article body append \"value\"",
            conversationId: conversationId,
            context: try makeContext()
        )
        guard case .handled(let env) = result else {
            Issue.record("Expected handled"); return
        }
        #expect(!env.ok)
        #expect(env.error?.code == "CMD-010-STATE_ERROR")
    }

    // MARK: body insert

    @Test func testBodyInsertParagraphDispatchSucceeds() throws {
        let result = service.dispatch(
            input: "/article body insert paragraph 1 \"Inserted paragraph\"",
            conversationId: conversationId,
            context: try makeContext(),
            articleContext: articleContext()
        )
        guard case .handled(let env) = result else {
            Issue.record("Expected handled"); return
        }
        #expect(env.ok)
        #expect(env.bodyOperation?.operation == "insert")
        #expect(env.bodyOperation?.blockType == "paragraph")
        #expect(env.bodyOperation?.index == 1)
        #expect(env.bodyOperation?.value == "Inserted paragraph")
    }

    @Test func testBodyInsertHeadingDispatchSucceeds() throws {
        let result = service.dispatch(
            input: "/article body insert heading 2 \"New Section\"",
            conversationId: conversationId,
            context: try makeContext(),
            articleContext: articleContext()
        )
        guard case .handled(let env) = result else {
            Issue.record("Expected handled"); return
        }
        #expect(env.ok)
        #expect(env.bodyOperation?.blockType == "heading")
        #expect(env.bodyOperation?.index == 2)
    }

    @Test func testBodyInsertMissingValueReturnsError() throws {
        let result = service.dispatch(
            input: "/article body insert paragraph 1",
            conversationId: conversationId,
            context: try makeContext(),
            articleContext: articleContext()
        )
        guard case .handled(let env) = result else {
            Issue.record("Expected handled"); return
        }
        #expect(!env.ok)
        #expect(env.error?.code == "CMD-005-MISSING_ARGUMENT")
    }

    @Test func testBodyInsertInvalidTypeReturnsError() throws {
        let result = service.dispatch(
            input: "/article body insert image 1 \"value\"",
            conversationId: conversationId,
            context: try makeContext(),
            articleContext: articleContext()
        )
        guard case .handled(let env) = result else {
            Issue.record("Expected handled"); return
        }
        #expect(!env.ok)
    }
}
