//
//  DiffEngine.swift
//  WriteVibe
//
//  Word-level LCS diff. Produces ChangeSpans at word-token granularity
//  so highlights are readable to humans, not noise-heavy character diffs.
//

import Foundation

// MARK: - DiffEngine

enum DiffEngine {

    // MARK: - Public API

    /// Computes word-level change spans between `baseline` and `current` text.
    /// Called once per block whenever the AI submits a `ProposedEdits`.
    ///
    /// Returns spans with ranges relative to `current`.
    static func diff(baseline: String, current: String, author: ChangeAuthor = .ai) -> [ChangeSpan] {
        let baseTokens   = tokenize(baseline)
        let currentTokens = tokenize(current)

        let edits = lcs(old: baseTokens.map(\.word), new: currentTokens.map(\.word))
        return buildSpans(edits: edits, baseTokens: baseTokens, currentTokens: currentTokens,
                          currentText: current, author: author)
    }

    // MARK: - Tokenisation

    private struct Token {
        let word: String
        let range: Range<String.Index>
    }

    /// Splits text into whitespace-delimited word tokens, preserving their ranges in the original string.
    private static func tokenize(_ text: String) -> [Token] {
        var tokens: [Token] = []
        var idx = text.startIndex
        while idx < text.endIndex {
            // skip whitespace
            while idx < text.endIndex && text[idx].isWhitespace { idx = text.index(after: idx) }
            guard idx < text.endIndex else { break }
            let start = idx
            while idx < text.endIndex && !text[idx].isWhitespace { idx = text.index(after: idx) }
            tokens.append(Token(word: String(text[start..<idx]), range: start..<idx))
        }
        return tokens
    }

    // MARK: - Edit operations (word-level)

    private enum Edit {
        case keep(Int, Int)           // (old index, new index)
        case insert(Int)              // new index
        case delete(Int)              // old index
        case replace(Int, Int)        // (old index, new index)
    }

    // MARK: - LCS-based diff (Myers O(ND) simplified for clarity)

    private static func lcs(old: [String], new: [String]) -> [Edit] {
        let m = old.count, n = new.count
        guard m > 0 || n > 0 else { return [] }

        // dp[i][j] = length of LCS of old[0..<i], new[0..<j]
        var dp = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)
        for i in 1...m {
            for j in 1...n {
                dp[i][j] = old[i-1] == new[j-1] ? dp[i-1][j-1] + 1 : max(dp[i-1][j], dp[i][j-1])
            }
        }

        // Traceback
        var edits: [Edit] = []
        var i = m, j = n
        while i > 0 || j > 0 {
            if i > 0 && j > 0 && old[i-1] == new[j-1] {
                edits.append(.keep(i-1, j-1))
                i -= 1; j -= 1
            } else if j > 0 && (i == 0 || dp[i][j-1] >= dp[i-1][j]) {
                edits.append(.insert(j-1))
                j -= 1
            } else {
                edits.append(.delete(i-1))
                i -= 1
            }
        }
        edits.reverse()

        // Coalesce adjacent insert+delete pairs into replace
        return coalesce(edits)
    }

    /// Merge consecutive .delete/.insert pairs into .replace
    private static func coalesce(_ raw: [Edit]) -> [Edit] {
        var out: [Edit] = []
        var k = 0
        while k < raw.count {
            if case .delete(let di) = raw[k],
               k + 1 < raw.count,
               case .insert(let ni) = raw[k + 1] {
                out.append(.replace(di, ni))
                k += 2
            } else {
                out.append(raw[k])
                k += 1
            }
        }
        return out
    }

    // MARK: - Build ChangeSpans from edit ops

    private static func buildSpans(
        edits: [Edit],
        baseTokens: [Token],
        currentTokens: [Token],
        currentText: String,
        author: ChangeAuthor
    ) -> [ChangeSpan] {
        var spans: [ChangeSpan] = []
        let now = Date()

        for edit in edits {
            switch edit {
            case .keep:
                break

            case .insert(let ni):
                let tok = currentTokens[ni]
                spans.append(ChangeSpan(
                    id: UUID(),
                    changeType: .insert,
                    author: author,
                    timestamp: now,
                    reason: nil,
                    proposedRange: tok.range,
                    originalText: nil,
                    proposedText: tok.word
                ))

            case .delete(let di):
                // A delete means the word existed in baseline but not in current.
                // We attach it at the nearest insertion point in current (end of string if nothing else).
                let insertionPoint = currentText.endIndex
                let emptyRange = insertionPoint..<insertionPoint
                spans.append(ChangeSpan(
                    id: UUID(),
                    changeType: .delete,
                    author: author,
                    timestamp: now,
                    reason: nil,
                    proposedRange: emptyRange,
                    originalText: baseTokens[di].word,
                    proposedText: nil
                ))

            case .replace(let di, let ni):
                let tok = currentTokens[ni]
                spans.append(ChangeSpan(
                    id: UUID(),
                    changeType: .replace,
                    author: author,
                    timestamp: now,
                    reason: nil,
                    proposedRange: tok.range,
                    originalText: baseTokens[di].word,
                    proposedText: tok.word
                ))
            }
        }
        return spans
    }

    // MARK: - Accept / Reject helpers

    /// Returns the new canonical text after accepting a single span.
    /// For inserts/replaces: text stays as-is (proposed already in string).
    /// For deletes: nothing to do (word is already absent from current).
    static func acceptedText(current: String, span: ChangeSpan) -> String {
        // The proposed text is already the current string; accepting just removes the markup.
        current
    }

    /// Returns the new canonical text after rejecting a single span.
    static func rejectedText(current: String, span: ChangeSpan) -> String {
        switch span.changeType {
        case .insert:
            // Remove the inserted word from current text
            return current.replacingCharacters(in: span.proposedRange, with: "")
                .condensingWhitespace()

        case .delete:
            // Restore the deleted word. Insert at the anchor point (end of string).
            let insertAt = span.proposedRange.lowerBound
            var result = current
            let prefix = insertAt == current.startIndex ? "" : " "
            result.insert(contentsOf: prefix + (span.originalText ?? ""), at: insertAt)
            return result

        case .replace:
            // Restore original word
            return current.replacingCharacters(in: span.proposedRange,
                                               with: span.originalText ?? "")
        }
    }
}

// MARK: - String helper

private extension String {
    func condensingWhitespace() -> String {
        components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
