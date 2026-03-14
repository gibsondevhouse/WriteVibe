//
//  ExportService.swift
//  WriteVibe
//

import AppKit
import UniformTypeIdentifiers

/// Centralised export and clipboard operations.
///
/// Replaces the duplicated NSPasteboard / NSSavePanel code that was
/// scattered across ChatView, CopilotPanel, and SidebarView.
@MainActor
enum ExportService {

    // MARK: - Clipboard

    static func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    // MARK: - Save to File

    /// Presents an NSSavePanel and writes `content` as UTF-8 text.
    /// Returns `true` if the file was saved successfully.
    static func saveAsMarkdown(content: String, suggestedName: String) -> Bool {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = suggestedName

        guard panel.runModal() == .OK, let url = panel.url else { return false }

        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Conversation Export

    /// Returns the content of the last assistant message, if any.
    static func lastAssistantMessage(from conversation: Conversation) -> String? {
        conversation.messages.last(where: { $0.role == .assistant })?.content
    }

    /// Builds a full markdown transcript of a conversation.
    static func buildMarkdownExport(for conversation: Conversation) -> String {
        var markdown = ""
        let sorted = conversation.messages.sorted { $0.timestamp < $1.timestamp }
        for (index, msg) in sorted.enumerated() {
            let label = msg.role == .user ? "You" : "WriteVibe"
            markdown += "**\(label):** \(msg.content)\n\n"
            if index < sorted.count - 1 {
                markdown += "---\n\n"
            }
        }
        return markdown
    }
}
