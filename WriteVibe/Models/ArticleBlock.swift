//
//  ArticleBlock.swift
//  WriteVibe
//

import Foundation
import SwiftData

// MARK: - BlockType

nonisolated enum BlockType: Codable, Equatable {
    case paragraph
    case heading(level: Int)   // 1–4
    case blockquote
    case code(language: String?)
    case image(caption: String?)
    case bulletList
    case numberedList
    case divider

    var isTextEditable: Bool {
        switch self {
        case .image, .divider: return false
        default:               return true
        }
    }

    var defaultPlaceholder: String {
        switch self {
        case .paragraph:      return "Start writing…"
        case .heading(let l): return "Heading \(l)"
        case .blockquote:     return "Quote…"
        case .code:           return "// code"
        case .image:          return ""
        case .bulletList:     return "List item…"
        case .numberedList:   return "List item…"
        case .divider:        return ""
        }
    }

    var icon: String {
        switch self {
        case .paragraph:      return "text.alignleft"
        case .heading(let l): return "h.\(l).square"
        case .blockquote:     return "quote.opening"
        case .code:           return "chevron.left.forwardslash.chevron.right"
        case .image:          return "photo"
        case .bulletList:     return "list.bullet"
        case .numberedList:   return "list.number"
        case .divider:        return "minus"
        }
    }
}

// MARK: - ArticleBlock

@Model
final class ArticleBlock: Identifiable {
    var id: UUID
    // position controls display order; gaps allowed for easy reordering
    var position: Int
    var typeTag: String
    var typeMetadata: String?
    @Attribute(originalName: "typeRaw") private var legacyTypeRaw: Data?
    var content: String        // plain UTF-8 text for all text-bearing blocks

    init(type: BlockType, content: String = "", position: Int = 0) {
        let storage = Self.storage(from: type)
        self.id       = UUID()
        self.position = position
        self.typeTag = storage.tag
        self.typeMetadata = storage.metadata
        self.legacyTypeRaw = nil
        self.content  = content
    }

    var blockType: BlockType {
        get {
            if let legacyTypeRaw,
               let decodedLegacyType = try? JSONDecoder().decode(BlockType.self, from: legacyTypeRaw) {
                // Normalize migrated legacy values on first read.
                let storage = Self.storage(from: decodedLegacyType)
                if typeTag != storage.tag || typeMetadata != storage.metadata {
                    typeTag = storage.tag
                    typeMetadata = storage.metadata
                }
                self.legacyTypeRaw = nil
                return decodedLegacyType
            }

            return Self.blockType(from: typeTag, metadata: typeMetadata)
        }
        set {
            let storage = Self.storage(from: newValue)
            typeTag = storage.tag
            typeMetadata = storage.metadata
            legacyTypeRaw = nil
        }
    }

    /// Plain-text content, stripping nothing (content is already plain)
    var plainText: String { content }

    private static func storage(from blockType: BlockType) -> (tag: String, metadata: String?) {
        switch blockType {
        case .paragraph:
            return ("paragraph", nil)
        case .heading(let level):
            return ("heading", String(level))
        case .blockquote:
            return ("blockquote", nil)
        case .code(let language):
            return ("code", language)
        case .image(let caption):
            return ("image", caption)
        case .bulletList:
            return ("bulletList", nil)
        case .numberedList:
            return ("numberedList", nil)
        case .divider:
            return ("divider", nil)
        }
    }

    private static func blockType(from tag: String, metadata: String?) -> BlockType {
        switch tag {
        case "paragraph":
            return .paragraph
        case "heading":
            if let metadata, let level = Int(metadata) {
                return .heading(level: level)
            }
            return .heading(level: 1)
        case "blockquote":
            return .blockquote
        case "code":
            return .code(language: metadata)
        case "image":
            return .image(caption: metadata)
        case "bulletList":
            return .bulletList
        case "numberedList":
            return .numberedList
        case "divider":
            return .divider
        default:
            return .paragraph
        }
    }
}

