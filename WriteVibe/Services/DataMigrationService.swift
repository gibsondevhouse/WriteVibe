//
//  DataMigrationService.swift
//  WriteVibe
//

import Foundation
import SwiftData

/// One-time data migrations run at startup.
@MainActor
enum DataMigrationService {
    /// Extracts audience metadata previously encoded in `quickNotes` into the
    /// dedicated `Article.audience` field, then seeds sample articles if the
    /// store is empty.
    static func runStartupMigrations(context: ModelContext) throws {
        try migrateLegacySeriesNamesIfNeeded(context: context)

        let sentinel = "§AUDIENCE§"
        let endSentinel = "§END§"
        let descriptor = FetchDescriptor<Article>()
        let articles = try context.fetch(descriptor)

        var changed = false
        for article in articles where article.quickNotes.hasPrefix(sentinel) {
            guard let endRange = article.quickNotes.range(of: endSentinel) else { continue }
            let audienceStart = article.quickNotes.index(article.quickNotes.startIndex, offsetBy: sentinel.count)
            article.audience = String(article.quickNotes[audienceStart..<endRange.lowerBound])
            article.quickNotes = String(article.quickNotes[endRange.upperBound...])
            changed = true
        }
        if changed { try context.save() }

        try SampleArticleSeeder.seedIfNeeded(context: context)
    }

    /// One-time/idempotent migration from legacy `Article.seriesName` to `Series` relationship.
    private static func migrateLegacySeriesNamesIfNeeded(context: ModelContext) throws {
        let descriptor = FetchDescriptor<Article>()
        let allArticles = try context.fetch(descriptor)

        // Group only records that still need relationship backfill.
        var grouped: [String: [Article]] = [:]
        for article in allArticles where article.series == nil {
            guard let raw = article.seriesName else { continue }
            let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { continue }
            grouped[key, default: []].append(article)
        }

        guard !grouped.isEmpty else { return }

        // Reuse existing Series rows by normalized title to keep migration idempotent.
        let existingSeries = try context.fetch(FetchDescriptor<Series>())
        var seriesByKey: [String: Series] = [:]
        for series in existingSeries {
            let key = series.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { continue }
            seriesByKey[key] = series
        }

        var changed = false

        for (name, members) in grouped {
            let series: Series
            if let existing = seriesByKey[name] {
                series = existing
            } else {
                let created = Series(title: name)
                context.insert(created)
                seriesByKey[name] = created
                series = created
                changed = true
            }

            // Deterministic ordering: createdAt -> title (case-insensitive) -> id
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

            // Continue from existing max position if series already has members.
            var nextPosition = (series.articles.compactMap(\.seriesPosition).max() ?? 0) + 1
            for article in sorted where article.series == nil {
                article.series = series
                if article.seriesPosition == nil {
                    article.seriesPosition = nextPosition
                    nextPosition += 1
                }
                changed = true
            }
        }

        if changed {
            try context.save()
        }
    }
}
