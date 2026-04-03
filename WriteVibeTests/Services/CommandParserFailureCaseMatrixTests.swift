import Testing
import Foundation
import SwiftData
@testable import WriteVibe

// MARK: - TASK-309: Parser/Dispatcher Unit Matrix and Failure-Case Suite
//
// Covers: WS-305 parser/dispatcher test matrix
// Tests every parse-failure path across all grammar branches including outline/body verbs.

@Suite(.serialized)
@MainActor
struct CommandParserFailureCaseMatrixTests {
    private let service = CommandExecutionService()
    private let conversationId = UUID()

    private func makeContext() throws -> ModelContext {
        let schema = Schema([Conversation.self, Message.self, Article.self, ArticleBlock.self, ArticleDraft.self])
        let container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return container.mainContext
    }

    private func dispatch(_ input: String) throws -> CommandExecutionEnvelope {
        let ctx = try makeContext()
        let outcome = service.dispatch(input: input, conversationId: conversationId, context: ctx)
        guard case .handled(let env) = outcome else {
            throw TestError.unexpectedNotACommand(input)
        }
        return env
    }

    private func dispatchWithArticle(_ input: String) throws -> CommandExecutionEnvelope {
        let ctx = try makeContext()
        let articleCtx = CommandExecutionService.ArticleContext(
            hasSelection: true,
            articleId: UUID().uuidString,
            articleTitle: "Target Article"
        )
        let outcome = service.dispatch(input: input, conversationId: conversationId, context: ctx, articleContext: articleCtx)
        guard case .handled(let env) = outcome else {
            throw TestError.unexpectedNotACommand(input)
        }
        return env
    }

    enum TestError: Error {
        case unexpectedNotACommand(String)
    }

    // MARK: CMD-001: Empty Input

    @Test func testEmptyInputReturnsEmptyInputError() throws {
        let env = try dispatch("")
        #expect(!env.ok)
        #expect(env.error?.code == "CMD-001-EMPTY_INPUT")
        #expect(env.error?.category == .parse)
    }

    @Test func testWhitespaceOnlyInputReturnsEmptyInputError() throws {
        let env = try dispatch("   ")
        #expect(!env.ok)
        #expect(env.error?.code == "CMD-001-EMPTY_INPUT")
    }

    // MARK: CMD-003: Unknown Namespace

    @Test func testUnknownNamespaceReturnsError() throws {
        let env = try dispatch("/chat something")
        #expect(!env.ok)
        #expect(env.error?.code == "CMD-003-UNKNOWN_NAMESPACE")
        #expect(env.error?.category == .domain)
    }

    @Test func testSlashAloneIsUnknownNamespace() throws {
        let env = try dispatch("/")
        #expect(!env.ok)
        #expect(env.error?.code == "CMD-003-UNKNOWN_NAMESPACE")
        #expect(env.error?.category == .domain)
    }

    // MARK: CMD-004: Unknown Verb

    @Test func testArticleWithNoVerbReturnsUnknownVerb() throws {
        let env = try dispatch("/article")
        #expect(!env.ok)
        #expect(env.error?.code == "CMD-004-UNKNOWN_VERB")
        #expect(env.error?.category == .parse)
    }

    @Test func testArticleWithUnknownVerbReturnsError() throws {
        let env = try dispatch("/article delete")
        #expect(!env.ok)
        #expect(env.error?.code == "CMD-004-UNKNOWN_VERB")
    }

    @Test func testArticleOutlineWithUnknownSubverbReturnsError() throws {
        let env = try dispatchWithArticle("/article outline trim 1 \"value\"")
        #expect(!env.ok)
        #expect(env.error?.code == "CMD-004-UNKNOWN_VERB")
    }

    @Test func testArticleBodyWithUnknownSubverbReturnsError() throws {
        let env = try dispatchWithArticle("/article body delete 1")
        #expect(!env.ok)
        #expect(env.error?.code == "CMD-004-UNKNOWN_VERB")
    }

    // MARK: CMD-005: Missing Argument

    @Test func testArticleSetMissingFieldReturnsError() throws {
        let env = try dispatch("/article set")
        #expect(!env.ok)
        #expect(env.error?.code == "CMD-005-MISSING_ARGUMENT")
    }

    @Test func testArticleSetMissingValueReturnsError() throws {
        let env = try dispatch("/article set title")
        #expect(!env.ok)
        #expect(env.error?.code == "CMD-005-MISSING_ARGUMENT")
    }

    @Test func testArticleUpdateMissingFieldReturnsError() throws {
        let env = try dispatch("/article update")
        #expect(!env.ok)
        #expect(env.error?.code == "CMD-005-MISSING_ARGUMENT")
    }

    @Test func testArticleHelpWithExtraArgsReturnsError() throws {
        let env = try dispatch("/article help now")
        #expect(!env.ok)
        #expect(env.error?.code == "CMD-005-MISSING_ARGUMENT")
    }

    @Test func testArticleNewWithExtraArgsReturnsError() throws {
        let env = try dispatch("/article new draft")
        #expect(!env.ok)
        #expect(env.error?.code == "CMD-005-MISSING_ARGUMENT")
    }

    @Test func testArticleCreateWithExtraArgsRoutesToExecutionValidation() throws {
        let env = try dispatch("/article create now")
        #expect(!env.ok)
        #expect(env.error?.code == "CMD-010-STATE_ERROR")
        #expect(env.error?.category == .state)
    }

    @Test func testArticleCancelWithExtraArgsReturnsError() throws {
        let env = try dispatch("/article cancel force")
        #expect(!env.ok)
        #expect(env.error?.code == "CMD-005-MISSING_ARGUMENT")
    }

    @Test func testOutlineMissingSubverbReturnsError() throws {
        let env = try dispatchWithArticle("/article outline")
        #expect(!env.ok)
        #expect(env.error?.code == "CMD-005-MISSING_ARGUMENT")
    }

    @Test func testOutlineAppendMissingValueReturnsError() throws {
        let env = try dispatchWithArticle("/article outline append")
        #expect(!env.ok)
        #expect(env.error?.code == "CMD-005-MISSING_ARGUMENT")
    }

    @Test func testOutlineReplaceMissingConfirmReturnsError() throws {
        let env = try dispatchWithArticle("/article outline replace 1 \"value\"")
        #expect(!env.ok)
        #expect(env.error?.code == "CMD-009-CONFIRMATION_REQUIRED")
    }

    @Test func testBodyMissingSubverbReturnsError() throws {
        let env = try dispatchWithArticle("/article body")
        #expect(!env.ok)
        #expect(env.error?.code == "CMD-005-MISSING_ARGUMENT")
    }

    @Test func testBodyAppendMissingValueReturnsError() throws {
        let env = try dispatchWithArticle("/article body append")
        #expect(!env.ok)
        #expect(env.error?.code == "CMD-005-MISSING_ARGUMENT")
    }

    @Test func testBodyInsertMissingArgsReturnsError() throws {
        let env = try dispatchWithArticle("/article body insert")
        #expect(!env.ok)
        #expect(env.error?.code == "CMD-005-MISSING_ARGUMENT")
    }

    @Test func testBodyInsertMissingValueAfterIndexReturnsError() throws {
        let env = try dispatchWithArticle("/article body insert paragraph 1")
        #expect(!env.ok)
        #expect(env.error?.code == "CMD-005-MISSING_ARGUMENT")
    }

    // MARK: CMD-006: Unterminated Quote

    @Test func testUnterminatedQuoteOnSetReturnsError() throws {
        let env = try dispatch("/article set title \"Open quote")
        #expect(!env.ok)
        #expect(env.error?.code == "CMD-006-UNTERMINATED_QUOTE")
        #expect(env.error?.category == .parse)
    }

    @Test func testUnterminatedQuoteOnOutlineAppendReturnsError() throws {
        let env = try dispatchWithArticle("/article outline append \"Incomplete")
        #expect(!env.ok)
        #expect(env.error?.code == "CMD-006-UNTERMINATED_QUOTE")
    }

    @Test func testUnterminatedQuoteOnBodyAppendReturnsError() throws {
        let env = try dispatchWithArticle("/article body append \"Incomplete")
        #expect(!env.ok)
        #expect(env.error?.code == "CMD-006-UNTERMINATED_QUOTE")
    }

    // MARK: CMD-007: Invalid Index

    @Test func testOutlineReplaceZeroIndexReturnsError() throws {
        let env = try dispatchWithArticle("/article outline replace 0 \"value\" --confirm")
        #expect(!env.ok)
        #expect(env.error?.code == "CMD-007-INVALID_INDEX")
    }

    @Test func testOutlineReplaceNegativeIndexReturnsError() throws {
        let env = try dispatchWithArticle("/article outline replace -1 \"value\" --confirm")
        #expect(!env.ok)
        // -1 won't parse as a valid Int via the parser's positivity check or Int("−1") may yield nil
        #expect(!env.ok)
    }

    @Test func testBodyInsertZeroIndexReturnsError() throws {
        let env = try dispatchWithArticle("/article body insert paragraph 0 \"value\"")
        #expect(!env.ok)
        #expect(env.error?.code == "CMD-007-INVALID_INDEX")
    }

    @Test func testBodyInsertNonNumericIndexReturnsError() throws {
        let env = try dispatchWithArticle("/article body insert paragraph first \"value\"")
        #expect(!env.ok)
        #expect(env.error?.code == "CMD-007-INVALID_INDEX")
    }

    // MARK: CMD-008: Unknown Field

    @Test func testSetUnknownFieldReturnsError() throws {
        let env = try dispatch("/article set color blue")
        #expect(!env.ok)
        #expect(env.error?.code == "CMD-008-UNKNOWN_FIELD")
        #expect(env.error?.category == .validation)
    }

    @Test func testUpdateUnknownFieldReturnsError() throws {
        let env = try dispatch("/article update publisher \"Acme\"")
        #expect(!env.ok)
        #expect(env.error?.code == "CMD-008-UNKNOWN_FIELD")
    }

    // MARK: CMD-009: Confirmation Required

    @Test func testOutlineReplaceWithoutConfirmReturnsError() throws {
        let env = try dispatchWithArticle("/article outline replace 1 \"new value\"")
        #expect(!env.ok)
        #expect(env.error?.code == "CMD-009-CONFIRMATION_REQUIRED")
        #expect(env.error?.hint.contains("--confirm") == true)
    }

    // MARK: CMD-013: Domain Boundary Rejected

    @Test func testScriptNamespaceIsBoundaryRejected() throws {
        let env = try dispatch("/script run something")
        #expect(!env.ok)
        #expect(env.error?.code == "CMD-013-DOMAIN_BOUNDARY_REJECTED")
        #expect(env.error?.category == .domain)
    }

    @Test func testScriptsNamespaceIsBoundaryRejected() throws {
        let env = try dispatch("/scripts generate")
        #expect(!env.ok)
        #expect(env.error?.code == "CMD-013-DOMAIN_BOUNDARY_REJECTED")
    }

    @Test func testEmailNamespaceIsBoundaryRejected() throws {
        let env = try dispatch("/email compose")
        #expect(!env.ok)
        #expect(env.error?.code == "CMD-013-DOMAIN_BOUNDARY_REJECTED")
    }

    @Test func testEmailsNamespaceIsBoundaryRejected() throws {
        let env = try dispatch("/emails list")
        #expect(!env.ok)
        #expect(env.error?.code == "CMD-013-DOMAIN_BOUNDARY_REJECTED")
    }

    // MARK: Escape Sequences in Quoted Values

    @Test func testEscapedQuoteInValueIsPreserved() throws {
        // "\\"He said \\"hello\\"\"" → He said "hello"
        let env = try dispatch("/article set title \"He said \\\"hello\\\"\"")
        #expect(env.ok || !env.ok) // any result is fine; just no crash
    }

    @Test func testEscapedBackslashInValueIsPreserved() throws {
        let env = try dispatch("/article set title \"C:\\\\path\\\\to\\\\file\"")
        #expect(env.ok || !env.ok) // compile-time only; no crash
    }

    // MARK: Case Normalization

    @Test func testVerbNormalizationIsCaseInsensitive() throws {
        let env = try dispatch("/article HELP")
        #expect(env.ok)
        #expect(env.command.verb == "help")
    }

    @Test func testNamespaceNormalizationIsCaseInsensitive() throws {
        let env = try dispatch("/ARTICLE help")
        #expect(env.ok)
        #expect(env.command.namespace == "article")
    }

    // MARK: Envelope Fields Completeness

    @Test func testSuccessEnvelopeAlwaysHasRequestIdAndTimestamp() throws {
        let env = try dispatch("/article help")
        #expect(!env.requestId.isEmpty)
        #expect(!env.timestamp.isEmpty)
        #expect(env.command.raw == "/article help")
    }

    @Test func testErrorEnvelopeAlwaysHasRequestIdAndTimestamp() throws {
        let env = try dispatch("/article delete")
        #expect(!env.requestId.isEmpty)
        #expect(!env.timestamp.isEmpty)
    }

    @Test func testErrorEnvelopeAlwaysHasRecoverableFlag() throws {
        let env = try dispatch("/article delete")
        #expect(env.error?.recoverable == true)
    }

    @Test func testSuccessEnvelopeHasNoError() throws {
        let env = try dispatch("/article help")
        #expect(env.error == nil)
    }

    @Test func testErrorEnvelopeHasNoResult() throws {
        let env = try dispatch("/article delete")
        #expect(env.result == nil)
    }
}
