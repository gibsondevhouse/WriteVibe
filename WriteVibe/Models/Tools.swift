//
//  Tools.swift
//  WriteVibe
//
//  Defines structures for AI tools and structured data generation that can be used by the language model.
//

import Foundation

// MARK: - Tool Protocol

/// A protocol defining the structure for a callable tool that an AI model can use.
/// Tools are expected to have a name, a description of their function,
/// and a way to execute their logic.
protocol Tool {
    var name: String { get }
    var description: String { get }
    /// The execution logic for the tool.
    /// It can take parameters (e.g., a JSON string) and return a result.
    /// The exact signature might vary depending on the LLM framework's expectations.
    /// For simplicity, we'll use a generic execute function here.
    func execute(arguments: String) async throws -> String
}

// MARK: - DateTimeTool

/// A tool that returns the current date and time.
struct DateTimeTool: Tool {
    let name = "get_current_datetime"
    let description = "Returns the current date and time in ISO 8601 format."

    func execute(arguments: String) async throws -> String {
        // Arguments are typically expected in JSON format, but this tool takes none.
        // We can validate arguments if needed, but for simplicity, we ignore them.
        let dateFormatter = ISO8601DateFormatter()
        return dateFormatter.string(from: Date())
    }
}

// MARK: - ClipboardTool

/// A tool that interacts with the system clipboard.
struct ClipboardTool: Tool {
    let name = "interact_with_clipboard"
    let description = "Reads text from the system clipboard or writes text to it. Arguments should be a JSON object with 'action' ('read' or 'write') and optionally 'content' for writing."

    func execute(arguments: String) async throws -> String {
        guard let data = arguments.data(using: .utf8) else {
            throw ToolError.invalidArguments("Arguments must be UTF-8 encoded.")
        }

        struct ClipboardArguments: Codable {
            let action: String // "read" or "write"
            let content: String? // Required for "write" action
        }

        let decoder = JSONDecoder()
        guard let decodedArgs = try? decoder.decode(ClipboardArguments.self, from: data) else {
            throw ToolError.invalidArguments("Invalid JSON format for clipboard arguments.")
        }

        switch decodedArgs.action {
        case "read":
            if let clipboardText = NSPasteboard.general.string(forType: .string) {
                return clipboardText
            } else {
                return "Clipboard is empty or contains non-text data."
            }
        case "write":
            guard let textToPaste = decodedArgs.content, !textToPaste.isEmpty else {
                throw ToolError.invalidArguments("Content must be provided for 'write' action.")
            }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(textToPaste, forType: .string)
            return "Text successfully written to clipboard."
        default:
            throw ToolError.invalidArguments("Invalid action '\(decodedArgs.action)'. Use 'read' or 'write'.")
        }
    }
}

// MARK: - Writing Analysis Data Structure

/// Represents the analysis of a piece of text, including tone, reading level, word count, and suggestions.
@Generable
struct WritingAnalysis {
    var tone: String // e.g., "Formal", "Informal", "Enthusiastic"
    var readingLevel: String // e.g., "Grade 8", "College"
    var wordCount: Int
    var suggestions: [String] // List of actionable suggestions for improvement
}


// MARK: - Tool Error

enum ToolError: Error {
    case invalidArguments(String)
    case executionFailed(String)
    case clipboardError(String)
}

extension ToolError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidArguments(let msg): return "Invalid arguments: \(msg)"
        case .executionFailed(let msg): return "Tool execution failed: \(msg)"
        case .clipboardError(let msg): return "Clipboard operation failed: \(msg)"
        }
    }
}
