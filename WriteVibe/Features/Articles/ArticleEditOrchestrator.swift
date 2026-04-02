//
//  ArticleEditOrchestrator.swift
//  WriteVibe
//
//  Conductor for article edit workflows with explicit state machine:
//  pending → applying → finalized → (accept/reject cycle) → pending
//  Boundaries: Pure state machine; orchestrator does not directly commit to SwiftData.
//  View model handles SwiftData persistence after accept/reject.

import Foundation

// MARK: - Edit Orchestration State Machine

/// State of the current edit orchestration cycle.
/// - **pending**: No active edit operation; ready to request new edits
/// - **applying**: Edit request in flight (network call)
/// - **finalized**: Edit result captured; awaiting accept/reject from user
enum EditOrchestrationState {
    case pending
    case applying
    case finalized(result: EditApplyResult)
    
    var isPending: Bool {
        guard case .pending = self else { return false }
        return true
    }
    
    var isApplying: Bool {
        guard case .applying = self else { return false }
        return true
    }
    
    var isFinalized: Bool {
        guard case .finalized = self else { return false }
        return true
    }
}

// MARK: - Contract Models

struct RejectedEditOperation {
    let reason: String
    let operation: ProposedBlockEdit
}

struct EditApplyResult {
    let summary: String?
    let appliedChanges: BlockChanges
    let rejectedOperations: [RejectedEditOperation]
}

// MARK: - ArticleEditOrchestrating (Protocol)

/// Main boundary for article edit orchestration.
/// Handles: request → apply → finalize → accept/reject workflow
/// Does NOT handle UI rendering or SwiftData writes (delegated to caller).
@MainActor
protocol ArticleEditOrchestrating {
    
    /// Request AI edits for the article. Moves state: `pending` → `applying` → `finalized`.
    ///
    /// - Parameters:
    ///   - article: Article to edit (may be mutated during apply phase).
    ///   - modelID: Selected AI model identifier.
    ///   - existingChanges: Previously proposed changes not yet accepted (for continuity).
    ///
    /// - Returns: Complete edit result (summary + tracked changes).
    ///
    /// - Throws: Network errors, parse errors, validation errors.
    func requestAndApplyEdits(
        article: Article,
        modelID: String,
        existingChanges: BlockChanges
    ) async throws -> EditApplyResult
    
    /// Accept a single proposed change span and remove it from tracking.
    /// After all spans accepted, state transitions: `finalized` → `pending`.
    func acceptSpan(_ span: ChangeSpan, in blockID: UUID, article: Article)
    
    /// Reject a single proposed change span by reverting block content.
    /// After all spans rejected, state transitions: `finalized` → `pending`.
    func rejectSpan(_ span: ChangeSpan, in blockID: UUID, article: Article)
    
    /// Accept all pending changes at once.
    /// State transitions: `finalized` → `pending`.
    func acceptAllChanges()
    
    /// Reject all pending changes by restoring baseline content.
    /// State transitions: `finalized` → `pending`.
    func rejectAllChanges(for article: Article)
    
    /// True if any changes are pending acceptance/rejection.
    var hasPendingChanges: Bool { get }
    
    /// Current edit operation state.
    var state: EditOrchestrationState { get }
}

// MARK: - DefaultArticleEditOrchestrator

/// Default implementation of article edit orchestration.
/// 
/// Responsibilities:
/// 1. Coordinate AI edit proposal → apply cycle
/// 2. Track proposed changes (spans) per block
/// 3. Store baseline for reject operations
/// 4. Validate operations (block existence, content consistency)
/// 5. Manage state transitions
///
/// Non-responsibilities:
/// - SwiftData writes (caller handles)
/// - View rendering (caller handles)
/// - Message persistence (ArticleAIService handles)
@MainActor
final class DefaultArticleEditOrchestrator: ArticleEditOrchestrating {
    
    typealias ProposeEditsClosure = @MainActor (_ blocks: [ArticleBlock], _ modelID: String) async throws -> ProposedEdits

    private let proposeEdits: ProposeEditsClosure
    private(set) var blockChanges: BlockChanges = [:]
    private var baseline: BaselineDocument? = nil
    private(set) var state: EditOrchestrationState = .pending

    init(proposeEdits: @escaping ProposeEditsClosure = { blocks, modelID in
        try await ArticleAIService.proposeEdits(blocks: blocks, modelID: modelID)
    }) {
        self.proposeEdits = proposeEdits
    }

    // MARK: - State Inspection

    var hasPendingChanges: Bool {
        blockChanges.values.contains { !$0.isEmpty }
    }

    // MARK: - Edit Request → Apply Workflow

    func requestAndApplyEdits(
        article: Article,
        modelID: String,
        existingChanges: BlockChanges
    ) async throws -> EditApplyResult {
        
        // State: pending → applying
        state = .applying
        
        let currentBlocks = article.sortedBlocks
        let proposed = try await proposeEdits(currentBlocks, modelID)
        baseline = BaselineDocument(blocks: currentBlocks)
        
        let applyResult = apply(proposed: proposed, blocks: currentBlocks, article: article, existingChanges: existingChanges)
        blockChanges = applyResult.changes
        
        // State: applying → finalized
        let result = EditApplyResult(
            summary: proposed.summary,
            appliedChanges: applyResult.changes,
            rejectedOperations: applyResult.rejected
        )
        state = .finalized(result: result)
        
        return result
    }
    
    // MARK: - Accept/Reject Flow

    func acceptSpan(_ span: ChangeSpan, in blockID: UUID, article: Article) {
        blockChanges[blockID]?.removeAll { $0.id == span.id }
        article.updatedAt = Date()
        clearEditStateIfDone()
    }
    
    func rejectSpan(_ span: ChangeSpan, in blockID: UUID, article: Article) {
        guard let block = article.blocks.first(where: { $0.id == blockID }) else { return }
        block.content = DiffEngine.rejectedText(current: block.content, span: span)
        blockChanges[blockID]?.removeAll { $0.id == span.id }
        article.updatedAt = Date()
        clearEditStateIfDone()
    }
    
    func acceptAllChanges() {
        blockChanges.removeAll()
        clearEditStateIfDone()
    }
    
    func rejectAllChanges(for article: Article) {
        guard let base = baseline else { return }
        for block in article.blocks {
            if let originalText = base.text[block.id] {
                block.content = originalText
            }
        }
        blockChanges.removeAll()
        clearEditStateIfDone()
    }
    
    // MARK: - State Management

    private func clearEditStateIfDone() {
        if !hasPendingChanges {
            baseline = nil
            // State: finalized → pending (no more pending changes)
            state = .pending
        }
    }

    // MARK: - Edit Application (Validation + Mutation)

    /// Apply proposed edits to blocks, validating each operation.
    /// Mutations are in-memory only (non-destructive on validation failure).
    private func apply(
        proposed: ProposedEdits,
        blocks: [ArticleBlock],
        article: Article,
        existingChanges: BlockChanges
    ) -> (changes: BlockChanges, rejected: [RejectedEditOperation]) {
        
        var changes = existingChanges
        var rejected: [RejectedEditOperation] = []
        var blockMap = Dictionary(uniqueKeysWithValues: blocks.map { ($0.id, $0) })

        for op in proposed.operations {
            switch op {
            
            case let .replace(blockID, range, newText, reason):
                guard let block = blockMap[blockID] else {
                    rejected.append(RejectedEditOperation(
                        reason: "Apply conflict: target block not found.",
                        operation: op
                    ))
                    continue
                }

                let original = String(block.content[range])
                block.content.replaceSubrange(range, with: newText)
                
                if let newRange = block.content.range(of: newText) {
                    let span = ChangeSpan(
                        id: UUID(),
                        changeType: .replace,
                        author: .ai,
                        timestamp: Date(),
                        reason: reason,
                        proposedRange: newRange,
                        originalText: original,
                        proposedText: newText
                    )
                    changes[blockID, default: []].append(span)
                }
                article.updatedAt = Date()

            case let .insert(blockID, at, text, reason):
                guard let block = blockMap[blockID] else {
                    rejected.append(RejectedEditOperation(
                        reason: "Apply conflict: target block not found.",
                        operation: op
                    ))
                    continue
                }

                let safeAt = at <= block.content.endIndex ? at : block.content.endIndex
                block.content.insert(contentsOf: text, at: safeAt)
                let end = block.content.index(safeAt, offsetBy: text.count, limitedBy: block.content.endIndex) ?? block.content.endIndex
                
                let span = ChangeSpan(
                    id: UUID(),
                    changeType: .insert,
                    author: .ai,
                    timestamp: Date(),
                    reason: reason,
                    proposedRange: safeAt..<end,
                    originalText: nil,
                    proposedText: text
                )
                changes[blockID, default: []].append(span)
                article.updatedAt = Date()

            case let .delete(blockID, range, reason):
                guard let block = blockMap[blockID] else {
                    rejected.append(RejectedEditOperation(
                        reason: "Apply conflict: target block not found.",
                        operation: op
                    ))
                    continue
                }

                let original = String(block.content[range])
                let anchor = range.lowerBound
                let emptyRange = anchor..<anchor
                
                let span = ChangeSpan(
                    id: UUID(),
                    changeType: .delete,
                    author: .ai,
                    timestamp: Date(),
                    reason: reason,
                    proposedRange: emptyRange,
                    originalText: original,
                    proposedText: nil
                )
                changes[blockID, default: []].append(span)
                block.content.removeSubrange(range)
                article.updatedAt = Date()

            case let .insertBlock(afterBlockID, type, content, _):
                guard let after = blockMap[afterBlockID] else {
                    rejected.append(RejectedEditOperation(
                        reason: "Apply conflict: anchor block not found.",
                        operation: op
                    ))
                    continue
                }

                let nextPosition = after.position + 10
                let block = ArticleBlock(type: type, content: content, position: nextPosition)
                article.blocks.append(block)
                blockMap[block.id] = block
                article.updatedAt = Date()

            case let .deleteBlock(blockID, _):
                guard let block = blockMap[blockID] else {
                    rejected.append(RejectedEditOperation(
                        reason: "Apply conflict: target block not found.",
                        operation: op
                    ))
                    continue
                }
                guard block.content.isEmpty, article.blocks.count > 1 else {
                    rejected.append(RejectedEditOperation(
                        reason: "Validation failure: block delete requires an empty non-last block.",
                        operation: op
                    ))
                    continue
                }

                if let idx = article.blocks.firstIndex(where: { $0.id == block.id }) {
                    article.blocks.remove(at: idx)
                    blockMap.removeValue(forKey: block.id)
                    article.updatedAt = Date()
                }
            }
        }

        return (changes, rejected)
    }
}
