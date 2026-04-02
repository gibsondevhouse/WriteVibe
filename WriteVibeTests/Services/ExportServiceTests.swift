import XCTest
import AppKit
import ObjectiveC.runtime
@testable import WriteVibe

private enum SavePanelTestDouble {
    static var response: NSApplication.ModalResponse = .cancel
    static var stubbedURL: URL?
    static var didSwizzle = false

    static func installIfNeeded() {
        guard !didSwizzle else { return }
        didSwizzle = true

        let runModalOriginal = class_getInstanceMethod(NSSavePanel.self, #selector(NSSavePanel.runModal))
        let runModalReplacement = class_getInstanceMethod(NSSavePanel.self, #selector(NSSavePanel.wv_test_runModal))
        method_exchangeImplementations(runModalOriginal!, runModalReplacement!)

        let urlOriginal = class_getInstanceMethod(NSSavePanel.self, #selector(getter: NSSavePanel.url))
        let urlReplacement = class_getInstanceMethod(NSSavePanel.self, #selector(getter: NSSavePanel.wv_test_url))
        method_exchangeImplementations(urlOriginal!, urlReplacement!)
    }

    static func reset() {
        response = .cancel
        stubbedURL = nil
    }
}

private extension NSSavePanel {
    @objc func wv_test_runModal() -> NSApplication.ModalResponse {
        SavePanelTestDouble.response
    }

    @objc var wv_test_url: URL? {
        SavePanelTestDouble.stubbedURL
    }
}

@MainActor
final class ExportServiceTests: XCTestCase {

    override class func setUp() {
        super.setUp()
        SavePanelTestDouble.installIfNeeded()
    }

    override func tearDown() {
        NSPasteboard.general.clearContents()
        SavePanelTestDouble.reset()
        super.tearDown()
    }

    func testCopyToClipboardWritesString() {
        ExportService.copyToClipboard("Copied text")

        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "Copied text")
    }

    func testLastAssistantMessageReturnsLatestAssistantContent() {
        let conversation = Conversation(title: "Export")
        conversation.messages = [
            Message(role: .assistant, content: "first"),
            Message(role: .user, content: "question"),
            Message(role: .assistant, content: "latest")
        ]

        XCTAssertEqual(ExportService.lastAssistantMessage(from: conversation), "latest")
    }

    func testLastAssistantMessageReturnsNilWhenConversationHasNoAssistantReply() {
        let conversation = Conversation(title: "Export")
        conversation.messages = [Message(role: .user, content: "question")]

        XCTAssertNil(ExportService.lastAssistantMessage(from: conversation))
    }

    func testBuildMarkdownExportSortsMessagesAndAddsSeparators() {
        let base = Date(timeIntervalSince1970: 10)
        let later = Date(timeIntervalSince1970: 20)

        let user = Message(role: .user, content: "Hello")
        user.timestamp = later
        let assistant = Message(role: .assistant, content: "Hi there")
        assistant.timestamp = base

        let conversation = Conversation(title: "Transcript")
        conversation.messages = [user, assistant]

        let markdown = ExportService.buildMarkdownExport(for: conversation)

        XCTAssertEqual(
            markdown,
            "**WriteVibe:** Hi there\n\n---\n\n**You:** Hello\n\n"
        )
    }

    func testSaveAsMarkdownReturnsFalseWhenPanelIsCancelled() {
        SavePanelTestDouble.response = .cancel
        SavePanelTestDouble.stubbedURL = nil

        XCTAssertFalse(ExportService.saveAsMarkdown(content: "Body", suggestedName: "note.md"))
    }

    func testSaveAsMarkdownWritesFileWhenPanelProvidesURL() throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("export-\(UUID().uuidString).md")
        SavePanelTestDouble.response = .OK
        SavePanelTestDouble.stubbedURL = tempURL

        defer { try? FileManager.default.removeItem(at: tempURL) }

        XCTAssertTrue(ExportService.saveAsMarkdown(content: "Body", suggestedName: "note.md"))
        XCTAssertEqual(try String(contentsOf: tempURL, encoding: .utf8), "Body")
    }

    func testSaveAsMarkdownReturnsFalseWhenWriteFails() throws {
        let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent("export-dir-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        SavePanelTestDouble.response = .OK
        SavePanelTestDouble.stubbedURL = directoryURL

        defer { try? FileManager.default.removeItem(at: directoryURL) }

        XCTAssertFalse(ExportService.saveAsMarkdown(content: "Body", suggestedName: "note.md"))
    }
}