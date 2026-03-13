//
//  DocumentIngestionService.swift
//  WriteVibe
//

import AppKit
import UniformTypeIdentifiers

enum DocumentIngestionService {
    /// Presents NSOpenPanel and returns the extracted plain-text content of the selected file.
    /// Supported types: .txt, .md, .rtf
    /// Returns nil if the user cancels or the file cannot be read.
    @MainActor
    static func pickAndExtract() async -> String? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        
        var allowedTypes: [UTType] = [.plainText, .rtf]
        if let mdType = UTType(filenameExtension: "md") {
            allowedTypes.append(mdType)
        }
        panel.allowedContentTypes = allowedTypes
        
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        
        do {
            var content = ""
            if url.pathExtension.lowercased() == "rtf" {
                if let attrString = try? NSAttributedString(url: url, options: [ : ], documentAttributes: nil) {
                    content = attrString.string
                }
            } else {
                content = try String(contentsOf: url, encoding: .utf8)
            }
            
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.count > 8000 {
                let truncated = String(trimmed.prefix(8000))
                return truncated + "\n\n[Document truncated to fit context window]"
            }
            return trimmed
        } catch {
            return nil
        }
    }
}
