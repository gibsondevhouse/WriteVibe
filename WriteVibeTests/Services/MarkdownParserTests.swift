import XCTest
@testable import WriteVibe

@MainActor
final class MarkdownParserTests: XCTestCase {

    func testParseRecognizesHeadingsRulesAndBodyBlocks() {
        let content = """
        # Title
        ## Subtitle
        ### Section
        #### Detail

        Intro paragraph
        still intro

        ---

        Tail paragraph
        """

        let blocks = MarkdownParser.parse(content: content, isStreaming: false)

        XCTAssertEqual(blocks.count, 7)
        assertHeading(blocks[0], level: 1, text: "Title")
        assertHeading(blocks[1], level: 2, text: "Subtitle")
        assertHeading(blocks[2], level: 3, text: "Section")
        assertHeading(blocks[3], level: 4, text: "Detail")
        assertBody(blocks[4], equals: "Intro paragraph\nstill intro")
        assertRule(blocks[5])
        assertBody(blocks[6], equals: "Tail paragraph")
    }

    func testParseGroupsBulletAndNumberedLists() {
        let content = """
        - alpha
        * beta
        1. first
        2. second
        body line
        """

        let blocks = MarkdownParser.parse(content: content, isStreaming: false)

        XCTAssertEqual(blocks.count, 3)
        assertBullets(blocks[0], equals: ["alpha", "beta"])
        assertNumbered(blocks[1], equals: ["first", "second"])
        assertBody(blocks[2], equals: "body line")
    }

    func testParseGroupsBlockquotesAndFlushesOnNonQuoteLine() {
        let content = """
        > first quote
        > second quote
        >
        paragraph
        """

        let blocks = MarkdownParser.parse(content: content, isStreaming: false)

        XCTAssertEqual(blocks.count, 2)
        assertBlockquote(blocks[0], equals: ["first quote", "second quote", ""])
        assertBody(blocks[1], equals: "paragraph")
    }

    func testParseRecognizesTablesAndFallsBackForShortTableCandidates() {
        let validTable = """
        | Name | Role |
        | --- | --- |
        | Ada | Writer |
        | Bob | Editor |
        """

        let validBlocks = MarkdownParser.parse(content: validTable, isStreaming: false)
        XCTAssertEqual(validBlocks.count, 1)
        assertTable(validBlocks[0], headers: ["Name", "Role"], rows: [["Ada", "Writer"], ["Bob", "Editor"]])

        let fallbackTable = """
        just text
        only | one row
        """

        let fallbackBlocks = MarkdownParser.parse(content: fallbackTable, isStreaming: false)
        XCTAssertEqual(fallbackBlocks.count, 2)
        assertBody(fallbackBlocks[0], equals: "just text")
        assertBody(fallbackBlocks[1], equals: "only | one row")
    }

    func testParseRecognizesClosedAndUnclosedCodeBlocks() {
        let closedCode = """
        ```swift
        let value = 1
        print(value)
        ```
        """
        let closedBlocks = MarkdownParser.parse(content: closedCode, isStreaming: false)
        XCTAssertEqual(closedBlocks.count, 1)
        assertCode(closedBlocks[0], lang: "swift", src: "let value = 1\nprint(value)")

        let unclosedCode = """
        ```json
        {"ok":true}
        """
        let unclosedBlocks = MarkdownParser.parse(content: unclosedCode, isStreaming: false)
        XCTAssertEqual(unclosedBlocks.count, 1)
        assertCode(unclosedBlocks[0], lang: "json", src: "{\"ok\":true}")
    }

    func testParseTreatsStreamingPartialLineAsBody() {
        let streamingHeading = MarkdownParser.parse(content: "# Incomplete", isStreaming: true)
        XCTAssertEqual(streamingHeading.count, 1)
        assertBody(streamingHeading[0], equals: "# Incomplete")

        let streamingMixed = MarkdownParser.parse(
            content: """
            # Stable
            complete line
            partial tail
            """,
            isStreaming: true
        )

        XCTAssertEqual(streamingMixed.count, 3)
        assertHeading(streamingMixed[0], level: 1, text: "Stable")
        assertBody(streamingMixed[1], equals: "complete line")
        assertBody(streamingMixed[2], equals: "partial tail")
    }

    func testParseDoesNotTreatStreamingPartialRuleAsDivider() {
        let blocks = MarkdownParser.parse(content: "text\n---", isStreaming: true)

        XCTAssertEqual(blocks.count, 2)
        assertBody(blocks[0], equals: "text")
        assertBody(blocks[1], equals: "---")
    }

    private func assertHeading(_ block: MarkdownBlock, level: Int, text: String, file: StaticString = #filePath, line: UInt = #line) {
        switch block {
        case .h1(let value):
            XCTAssertEqual(level, 1, file: file, line: line)
            XCTAssertEqual(value, text, file: file, line: line)
        case .h2(let value):
            XCTAssertEqual(level, 2, file: file, line: line)
            XCTAssertEqual(value, text, file: file, line: line)
        case .h3(let value):
            XCTAssertEqual(level, 3, file: file, line: line)
            XCTAssertEqual(value, text, file: file, line: line)
        case .h4(let value):
            XCTAssertEqual(level, 4, file: file, line: line)
            XCTAssertEqual(value, text, file: file, line: line)
        default:
            XCTFail("Expected heading level \(level), got \(String(describing: block))", file: file, line: line)
        }
    }

    private func assertBody(_ block: MarkdownBlock, equals expected: String, file: StaticString = #filePath, line: UInt = #line) {
        guard case .body(let actual) = block else {
            return XCTFail("Expected body block, got \(String(describing: block))", file: file, line: line)
        }
        XCTAssertEqual(actual, expected, file: file, line: line)
    }

    private func assertBullets(_ block: MarkdownBlock, equals expected: [String], file: StaticString = #filePath, line: UInt = #line) {
        guard case .bullets(let actual) = block else {
            return XCTFail("Expected bullets block, got \(String(describing: block))", file: file, line: line)
        }
        XCTAssertEqual(actual, expected, file: file, line: line)
    }

    private func assertNumbered(_ block: MarkdownBlock, equals expected: [String], file: StaticString = #filePath, line: UInt = #line) {
        guard case .numbered(let actual) = block else {
            return XCTFail("Expected numbered block, got \(String(describing: block))", file: file, line: line)
        }
        XCTAssertEqual(actual, expected, file: file, line: line)
    }

    private func assertRule(_ block: MarkdownBlock, file: StaticString = #filePath, line: UInt = #line) {
        guard case .rule = block else {
            return XCTFail("Expected rule block, got \(String(describing: block))", file: file, line: line)
        }
    }

    private func assertBlockquote(_ block: MarkdownBlock, equals expected: [String], file: StaticString = #filePath, line: UInt = #line) {
        guard case .blockquote(let actual) = block else {
            return XCTFail("Expected blockquote block, got \(String(describing: block))", file: file, line: line)
        }
        XCTAssertEqual(actual, expected, file: file, line: line)
    }

    private func assertTable(_ block: MarkdownBlock, headers expectedHeaders: [String], rows expectedRows: [[String]], file: StaticString = #filePath, line: UInt = #line) {
        guard case .table(let headers, let rows) = block else {
            return XCTFail("Expected table block, got \(String(describing: block))", file: file, line: line)
        }
        XCTAssertEqual(headers, expectedHeaders, file: file, line: line)
        XCTAssertEqual(rows, expectedRows, file: file, line: line)
    }

    private func assertCode(_ block: MarkdownBlock, lang expectedLang: String, src expectedSource: String, file: StaticString = #filePath, line: UInt = #line) {
        guard case .code(let lang, let src) = block else {
            return XCTFail("Expected code block, got \(String(describing: block))", file: file, line: line)
        }
        XCTAssertEqual(lang, expectedLang, file: file, line: line)
        XCTAssertEqual(src, expectedSource, file: file, line: line)
    }
}