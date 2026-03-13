//
//  ArticleBlock.swift
//  WriteVibe
//

import Foundation
import SwiftData

// MARK: - BlockType

enum BlockType: Codable, Equatable {
    case paragraph
    case heading(level: Int)   // 1–4
    case blockquote
    case code(language: String?)
    case image(caption: String?)

    var isTextEditable: Bool {
        switch self {
        case .image: return false
        default:     return true
        }
    }

    var defaultPlaceholder: String {
        switch self {
        case .paragraph:      return "Start writing…"
        case .heading(let l): return "Heading \(l)"
        case .blockquote:     return "Quote…"
        case .code:           return "// code"
        case .image:          return ""
        }
    }

    var icon: String {
        switch self {
        case .paragraph:      return "text.alignleft"
        case .heading(let l): return "h.\(l).square"
        case .blockquote:     return "quote.opening"
        case .code:           return "chevron.left.forwardslash.chevron.right"
        case .image:          return "photo"
        }
    }
}

// MARK: - ArticleBlock

@Model
final class ArticleBlock: Identifiable {
    var id: UUID
    // position controls display order; gaps allowed for easy reordering
    var position: Int
    var typeRaw: Data          // BlockType encoded as JSON
    var content: String        // plain UTF-8 text for all text-bearing blocks

    init(type: BlockType, content: String = "", position: Int = 0) {
        self.id       = UUID()
        self.position = position
        self.content  = content
        self.typeRaw  = (try? JSONEncoder().encode(type)) ?? Data()
    }

    var blockType: BlockType {
        get { (try? JSONDecoder().decode(BlockType.self, from: typeRaw)) ?? .paragraph }
        set { typeRaw = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    /// Plain-text content, stripping nothing (content is already plain)
    var plainText: String { content }
}
