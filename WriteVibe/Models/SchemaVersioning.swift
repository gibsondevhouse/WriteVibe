//
//  SchemaVersioning.swift
//  WriteVibe
//

import Foundation
import SwiftData

// MARK: - V1 (baseline)

enum WriteVibeSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Conversation.self, Message.self, Article.self, ArticleBlock.self, ArticleDraft.self]
    }
}

// MARK: - V2 (Series introduction)

enum WriteVibeSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Conversation.self, Message.self, Article.self, ArticleBlock.self, ArticleDraft.self, Series.self]
    }
}

// MARK: - Migration Plan

enum WriteVibeMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [WriteVibeSchemaV1.self, WriteVibeSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [WriteVibeMigrationStageV1toV2]
    }
}

// MARK: - V1 → V2 Migration Stage

/// Migrates legacy Article.seriesName strings into first-class Series records.
///
/// Groups articles by trimmed non-empty seriesName, creates one Series per unique legacy
/// name, attaches matching articles via the series relationship, and backfills
/// seriesPosition deterministically using:
///   1. createdAt ascending
///   2. title ascending (case-insensitive locale comparison)
///   3. id.uuidString ascending (deterministic final tiebreaker)
private let WriteVibeMigrationStageV1toV2 = MigrationStage.custom(
    fromVersion: WriteVibeSchemaV1.self,
    toVersion: WriteVibeSchemaV2.self,
    willMigrate: nil,
    didMigrate: { context in
        let descriptor = FetchDescriptor<Article>()
        let allArticles = try context.fetch(descriptor)

        // Group by normalized seriesName key; skip blank/missing values
        var grouped: [String: [Article]] = [:]
        for article in allArticles {
            guard let raw = article.seriesName else { continue }
            let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { continue }
            grouped[key, default: []].append(article)
        }

        // Create one Series per unique legacy name and attach its articles
        for (name, members) in grouped {
            let series = Series(title: name)
            context.insert(series)

            // Deterministic ordering: createdAt → title (case-insensitive) → id
            let sorted = members.sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt < rhs.createdAt
                }
                let titleCmp = lhs.title.compare(rhs.title, options: [.caseInsensitive, .diacriticInsensitive])
                if titleCmp != .orderedSame {
                    return titleCmp == .orderedAscending
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }

            for (index, article) in sorted.enumerated() {
                article.series = series
                article.seriesPosition = index + 1
            }
        }

        try context.save()
    }
)
