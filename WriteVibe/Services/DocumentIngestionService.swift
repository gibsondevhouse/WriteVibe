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
        
        return content
    }
    
    /// Fetches the content of a URL and returns it as a plain-text string.
    @MainActor
    static func fetchURL(urlString: String) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw WriteVibeError.decodingFailed(context: "Invalid URL format.")
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw WriteVibeError.apiError(provider: "URL Fetch", statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0, message: nil)
        }
        
        guard let content = String(data: data, encoding: .utf8) else {
            throw WriteVibeError.decodingFailed(context: "URL content is not UTF-8.")
        }
        
        // Simple HTML stripping
        let stripped = stripHTML(content)
        let trimmed = stripped.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.count > 8000 {
            let truncated = String(trimmed.prefix(8000))
            return truncated + "\n\n[URL content truncated to fit context window]"
        }
        return trimmed
    }
    
    private static func stripHTML(_ html: String) -> String {
        // Very basic HTML stripping using regex
        let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: .caseInsensitive)
        let range = NSRange(location: 0, length: html.utf16.count)
        let result = regex?.stringByReplacingMatches(in: html, options: [], range: range, withTemplate: " ") ?? html
        
        // Decode common HTML entities
        return result
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "  ", with: " ")
    }
}
