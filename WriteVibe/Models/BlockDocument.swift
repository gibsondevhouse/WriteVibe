//
//  BlockDocument.swift
//  WriteVibe
//
//  In-memory change-tracking layer for the block editor.
//  Nothing here touches SwiftData — this is a pure value-type overlay
//  that the ArticleEditorView uses at runtime. Changes are flushed to
//  SwiftData only on accept or autosave.
//

import Foundation

// MARK: - ChangeType

enum ChangeType: String, Codable {
    case insert
    case delete
    case replace
}

// MARK: - ChangeAuthor

enum ChangeAuthor: String, Codable {
    case human
    case ai
}

// MARK: - ChangeSpan
//
// A single highlighted region inside a block's text.
// Ranges are character-index ranges relative to the *current* block content string.

struct ChangeSpan: Identifiable, Equatable {
    let id: UUID
    let changeType: ChangeType
    let author: ChangeAuthor
    let timestamp: Date
    let reason: String?

    /// Range in the *current* (proposed) text.
    let proposedRange: Range<String.Index>
    /// Original text this span replaces (nil for pure inserts).
    let originalText: String?
    /// Proposed replacement text (nil for pure deletes).
    let proposedText: String?
}

// MARK: - BlockChanges
//
// Maps a block UUID to the list of change spans pending review.

typealias BlockChanges = [UUID: [ChangeSpan]]

// MARK: - BaselineDocument
//
// Snapshot of block content at the last "all accepted" state.
// Diff is computed between this and the live block contents.

struct BaselineDocument {
    /// Maps block ID → committed plain-text content.
    var text: [UUID: String]
    /// Ordered list of block IDs (for block-level inserts/deletes).
    var blockOrder: [UUID]

    init(blocks: [ArticleBlock]) {
        self.text = Dictionary(uniqueKeysWithValues: blocks.map { ($0.id, $0.content) })
        self.blockOrder = blocks.sorted { $0.position < $1.position }.map(\.id)
    }
}

// MARK: - ProposedBlockEdit
//
// Structured AI edit operation — the editor never applies raw completion strings.

enum ProposedBlockEdit {
    /// Insert new text at a specific character offset in the block.
    case insert(blockID: UUID, at: String.Index, text: String, reason: String?)
    /// Delete a range of text in the block.
    case delete(blockID: UUID, range: Range<String.Index>, reason: String?)
    /// Replace a range of text in the block with new text.
    case replace(blockID: UUID, range: Range<String.Index>, newText: String, reason: String?)
    /// Add an entirely new block after the given block ID.
    case insertBlock(afterBlockID: UUID, type: BlockType, content: String, reason: String?)
    /// Remove an entire block.
    case deleteBlock(blockID: UUID, reason: String?)
}

// MARK: - ProposedEdits

struct ProposedEdits {
    let operations: [ProposedBlockEdit]
    let summary: String?    // human-readable description of what the AI changed
}
