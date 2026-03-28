//
//  DocumentSyncEngine.swift
//  WriteVibe
//

import AppKit
import Foundation

// MARK: - Custom Attributed String Keys

extension NSAttributedString.Key {
    static let wvBlockType = NSAttributedString.Key("wv.blockType")
    static let wvBlockMeta = NSAttributedString.Key("wv.blockMeta")
    static let wvBlockID = NSAttributedString.Key("wv.blockID")
}

// MARK: - ArticleBlockUpdate

struct ArticleBlockUpdate {
    let blockID: UUID?
    let blockType: BlockType
    let content: String
    let position: Int
}

// MARK: - DocumentSyncEngine

enum DocumentSyncEngine {

    // MARK: - Blocks → NSAttributedString

    static func blocksToAttributedString(_ blocks: [ArticleBlock]) -> NSAttributedString {
        let sorted = blocks.sorted { $0.position < $1.position }
        guard !sorted.isEmpty else {
            return NSAttributedString(string: "", attributes: [
                .font: NSFont.systemFont(ofSize: 15, weight: .regular)
            ])
        }

        let result = NSMutableAttributedString()

        for (index, block) in sorted.enumerated() {
            let attrs = attributes(for: block)
            let text = NSAttributedString(string: block.content, attributes: attrs)
            result.append(text)

            if index < sorted.count - 1 {
                let newline = NSAttributedString(string: "\n", attributes: attrs)
                result.append(newline)
            }
        }

        return result
    }

    // MARK: - NSTextStorage → Blocks

    static func attributedStringToBlocks(
        from textStorage: NSTextStorage,
        existingBlocks: [ArticleBlock]
    ) -> [ArticleBlockUpdate] {
        let fullString = textStorage.string
        let existingByID = Dictionary(uniqueKeysWithValues: existingBlocks.map { ($0.id, $0) })
        var updates: [ArticleBlockUpdate] = []
        var position = 1000

        fullString.enumerateSubstrings(
            in: fullString.startIndex..<fullString.endIndex,
            options: .byParagraphs
        ) { paragraph, paragraphRange, _, _ in
            guard let paragraph else { return }

            let nsRange = NSRange(paragraphRange, in: fullString)
            let midpoint = nsRange.location + nsRange.length / 2
            let attrIndex = min(midpoint, textStorage.length - 1)

            var tag: String?
            var meta: String?
            var rawID: UUID?

            if attrIndex >= 0, textStorage.length > 0 {
                tag = textStorage.attribute(.wvBlockType, at: attrIndex, effectiveRange: nil) as? String
                meta = textStorage.attribute(.wvBlockMeta, at: attrIndex, effectiveRange: nil) as? String
                rawID = textStorage.attribute(.wvBlockID, at: attrIndex, effectiveRange: nil) as? UUID
            }

            let matchedID: UUID? = if let rawID, existingByID[rawID] != nil { rawID } else { nil }
            let resolvedType = resolveBlockType(tag: tag, metadata: meta)

            updates.append(ArticleBlockUpdate(
                blockID: matchedID,
                blockType: resolvedType,
                content: paragraph,
                position: position
            ))
            position += 1000
        }

        return updates
    }

    // MARK: - Font

    static func fontForBlockType(_ type: BlockType) -> NSFont {
        switch type {
        case .heading(let level):
            switch level {
            case 1: return .systemFont(ofSize: 28, weight: .bold)
            case 2: return .systemFont(ofSize: 22, weight: .semibold)
            case 3: return .systemFont(ofSize: 18, weight: .semibold)
            default: return .systemFont(ofSize: 15, weight: .medium)
            }
        case .blockquote:
            let base = NSFont.systemFont(ofSize: 16)
            return NSFontManager.shared.convert(base, toHaveTrait: .italicFontMask)
        case .code:
            return .monospacedSystemFont(ofSize: 13, weight: .regular)
        case .paragraph, .bulletList, .numberedList, .divider, .image:
            return .systemFont(ofSize: 15, weight: .regular)
        }
    }

    // MARK: - Paragraph Style

    static func paragraphStyleForBlockType(_ type: BlockType) -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()

        switch type {
        case .heading(let level):
            switch level {
            case 1:
                style.paragraphSpacingBefore = 24
                style.paragraphSpacing = 8
                style.lineSpacing = 4
            case 2:
                style.paragraphSpacingBefore = 20
                style.paragraphSpacing = 6
                style.lineSpacing = 3
            case 3:
                style.paragraphSpacingBefore = 16
                style.paragraphSpacing = 4
                style.lineSpacing = 2
            default:
                style.paragraphSpacingBefore = 12
                style.paragraphSpacing = 4
                style.lineSpacing = 2
            }
        case .blockquote:
            style.paragraphSpacingBefore = 12
            style.paragraphSpacing = 12
            style.headIndent = 20
            style.firstLineHeadIndent = 20
        case .code:
            style.paragraphSpacingBefore = 8
            style.paragraphSpacing = 8
            style.headIndent = 12
            style.firstLineHeadIndent = 12
        case .bulletList, .numberedList:
            style.paragraphSpacing = 2
            style.headIndent = 24
            style.firstLineHeadIndent = 8
            let tabStop = NSTextTab(textAlignment: .left, location: 24)
            style.tabStops = [tabStop]
        case .paragraph:
            style.paragraphSpacing = 14
            style.lineSpacing = 3
        case .divider:
            style.paragraphSpacingBefore = 16
            style.paragraphSpacing = 16
        case .image:
            style.paragraphSpacing = 8
        }

        return style
    }

    // MARK: - Default Typing Attributes

    static func defaultTypingAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: fontForBlockType(.paragraph),
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: paragraphStyleForBlockType(.paragraph),
            .wvBlockType: "paragraph"
        ]
    }

    // MARK: - Private Helpers

    private static func attributes(for block: ArticleBlock) -> [NSAttributedString.Key: Any] {
        let type = block.blockType
        let foregroundColor: NSColor = type == .blockquote ? .secondaryLabelColor : .textColor

        return [
            .wvBlockType: block.typeTag,
            .wvBlockMeta: block.typeMetadata as Any,
            .wvBlockID: block.id,
            .font: fontForBlockType(type),
            .paragraphStyle: paragraphStyleForBlockType(type),
            .foregroundColor: foregroundColor
        ]
    }

    static func resolveBlockType(tag: String?, metadata: String?) -> BlockType {
        switch tag {
        case "paragraph": return .paragraph
        case "heading":
            if let metadata, let level = Int(metadata) { return .heading(level: level) }
            return .heading(level: 1)
        case "blockquote": return .blockquote
        case "code": return .code(language: metadata)
        case "bulletList": return .bulletList
        case "numberedList": return .numberedList
        case "divider": return .divider
        case "image": return .image(caption: metadata)
        default: return .paragraph
        }
    }
}
