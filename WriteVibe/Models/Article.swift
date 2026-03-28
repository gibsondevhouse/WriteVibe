//
//  Article.swift
//  WriteVibe
//

import Foundation
import SwiftData

// MARK: - ArticleTone

enum ArticleTone: String, Codable, CaseIterable {
    case informative    = "Informative"
    case conversational = "Conversational"
    case persuasive     = "Persuasive"
    case narrative      = "Narrative"
    case technical      = "Technical"
    case humorous       = "Humorous"

    var icon: String {
        switch self {
        case .informative:    return "info.circle"
        case .conversational: return "bubble.left.and.bubble.right"
        case .persuasive:     return "megaphone"
        case .narrative:      return "book"
        case .technical:      return "terminal"
        case .humorous:       return "face.smiling"
        }
    }
}

// MARK: - ArticleLength

enum ArticleLength: String, Codable, CaseIterable {
    case brief    = "Brief"
    case short    = "Short"
    case medium   = "Medium"
    case long     = "Long"
    case deepDive = "Deep Dive"

    var wordTarget: String {
        switch self {
        case .brief:    return "~300 words"
        case .short:    return "~500 words"
        case .medium:   return "~1,000 words"
        case .long:     return "~2,000 words"
        case .deepDive: return "~5,000 words"
        }
    }
}

// MARK: - PublishStatus

enum PublishStatus: String, Codable, CaseIterable {
    case draft      = "Draft"
    case inProgress = "In Progress"
    case done       = "Done"

    var icon: String {
        switch self {
        case .draft:      return "circle.dashed"
        case .inProgress: return "pencil.circle"
        case .done:       return "checkmark.circle.fill"
        }
    }
}

// MARK: - Article

@Model
final class Article: Identifiable {
    var id: UUID
    var title: String
    var subtitle: String
    var seriesName: String?       // optional group label
    var topic: String
    var audience: String
    var quickNotes: String
    var sourceLinks: String
    var outline: String
    var summary: String
    var purpose: String
    var style: String
    var keyTakeaway: String
    var publishingIntent: String
    var tone: ArticleTone
    var targetLength: ArticleLength
    var publishStatus: PublishStatus
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade) var blocks: [ArticleBlock] = []
    @Relationship(deleteRule: .cascade) var drafts: [ArticleDraft] = []

    init(
        title: String = "Untitled Article",
        subtitle: String = "",
        topic: String = "",
        tone: ArticleTone = .conversational,
        targetLength: ArticleLength = .medium
    ) {
        self.id            = UUID()
        self.title         = title
        self.subtitle      = subtitle
        self.topic         = topic
        self.audience      = ""
        self.quickNotes    = ""
        self.sourceLinks   = ""
        self.outline       = ""
        self.summary       = ""
        self.purpose        = ""
        self.style          = ""
        self.keyTakeaway    = ""
        self.publishingIntent = ""
        self.tone          = tone
        self.targetLength  = targetLength
        self.publishStatus = .draft
        self.createdAt     = Date()
        self.updatedAt     = Date()
    }

    /// Approximate word count derived from all block plaintext
    var wordCount: Int {
        sortedBlocks
            .map { $0.plainText }
            .joined(separator: " ")
            .split { $0.isWhitespace }
            .count
    }

    var sortedBlocks: [ArticleBlock] {
        blocks.sorted { $0.position < $1.position }
    }

    /// Body blocks only — excludes the leading H1 title block used by TitleField
    var bodyBlocks: [ArticleBlock] {
        sortedBlocks.drop { $0.blockType == .heading(level: 1) && $0.position == 0 }
            .map { $0 }
    }
}
