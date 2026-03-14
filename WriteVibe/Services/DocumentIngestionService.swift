//
//  DocumentIngestionService.swift
//  WriteVibe
//

import AppKit
import UniformTypeIdentifiers

enum DocumentIngestionService {
    /// Presents NSOpenPanel and returns the extracted plain-text content of the selected file.
    /// Supported types: .txt, .md, .rtf
    /// Returns nil if the user cancels.
    @MainActor
    static func pickAndExtract() async throws -> String? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        
        var allowedTypes: [UTType] = [.plainText, .rtf]
        if let mdType = UTType(filenameExtension: "md") {
            allowedTypes.append(mdType)
        }
        panel.allowedContentTypes = allowedTypes
        
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        
        let content: String
        if url.pathExtension.lowercased() == "rtf" {
            do {
                let attrString = try NSAttributedString(url: url, options: [:], documentAttributes: nil)
                content = attrString.string
            } catch {
                throw WriteVibeError.decodingFailed(context: "RTF import for \(url.lastPathComponent)")
            }
        } else {
            do {
                content = try String(contentsOf: url, encoding: .utf8)
            } catch {
                throw WriteVibeError.decodingFailed(context: "Text import for \(url.lastPathComponent)")
            }
        }
            
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 8000 {
            let truncated = String(trimmed.prefix(8000))
            return truncated + "\n\n[Document truncated to fit context window]"
        }
        return trimmed
    }
}
