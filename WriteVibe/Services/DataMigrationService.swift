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
}
