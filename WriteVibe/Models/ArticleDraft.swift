//
//  ArticleDraft.swift
//  WriteVibe
//

import Foundation
import SwiftData

// MARK: - ArticleDraft

@Model
final class ArticleDraft: Identifiable {
    var id: UUID
    var title: String
    var content: String
    var createdAt: Date
    var updatedAt: Date

    init(title: String, content: String) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    var wordCount: Int {
        content
            .split { $0.isWhitespace }
            .count
    }
}
