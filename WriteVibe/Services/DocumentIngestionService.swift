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

        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            throw WriteVibeError.decodingFailed(context: "Only http and https URLs are supported.")
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
        let trimmed = stripped.trimmed
        
        if trimmed.count > 8000 {
            let truncated = String(trimmed.prefix(8000))
            return truncated + "\n\n[URL content truncated to fit context window]"
        }
        return trimmed
    }
    
    private static func stripHTML(_ html: String) -> String {
        var text = html

        // 1. Remove HTML comments
        if let commentRegex = try? NSRegularExpression(pattern: "<!--[\\s\\S]*?-->", options: []) {
            text = commentRegex.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: text.utf16.count), withTemplate: " ")
        }

        // 2. Remove script blocks (content + tags)
        if let scriptRegex = try? NSRegularExpression(pattern: "<script[^>]*>[\\s\\S]*?</script>", options: .caseInsensitive) {
            text = scriptRegex.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: text.utf16.count), withTemplate: " ")
        }

        // 3. Remove style blocks (content + tags)
        if let styleRegex = try? NSRegularExpression(pattern: "<style[^>]*>[\\s\\S]*?</style>", options: .caseInsensitive) {
            text = styleRegex.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: text.utf16.count), withTemplate: " ")
        }

        // 4. Remove all remaining tags (including self-closing)
        if let tagRegex = try? NSRegularExpression(pattern: "<[^>]+>", options: .caseInsensitive) {
            text = tagRegex.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: text.utf16.count), withTemplate: " ")
        }

        // Decode common HTML entities
        text = text
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")

        // Collapse runs of whitespace into a single space
        if let wsRegex = try? NSRegularExpression(pattern: "\\s{2,}", options: []) {
            text = wsRegex.stringByReplacingMatches(in: text, range: NSRange(location: 0, length: text.utf16.count), withTemplate: " ")
        }

        return text
    }
}
