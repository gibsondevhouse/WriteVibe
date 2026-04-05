//
//  ArticleCreationService.swift
//  WriteVibe
//

import Foundation
import SwiftData

struct ArticleCreationRequest {
    var title: String
    var subtitle: String = ""
    var topic: String = ""
    var audience: String = ""
    var quickNotes: String = ""
    var sourceLinks: String = ""
    var outline: String = ""
    var summary: String = ""
    var purpose: String = ""
    var style: String = ""
    var keyTakeaway: String = ""
    var publishingIntent: String = ""
    var tone: ArticleTone = .conversational
    var targetLength: ArticleLength = .medium
    var series: Series? = nil
}

@MainActor
final class ArticleCreationService {
    @discardableResult
    func createArticle(title: String, series: Series?, context: ModelContext) throws -> Article {
        try createArticle(
            ArticleCreationRequest(
                title: title,
                series: series
            ),
            context: context
        )
    }

    @discardableResult
    func createArticle(_ request: ArticleCreationRequest, context: ModelContext) throws -> Article {
        let finalTitle = request.title.trimmed.isEmpty ? "Untitled Article" : request.title.trimmed

        let article = Article(
            title: finalTitle,
            subtitle: request.subtitle,
            topic: request.topic,
            tone: request.tone,
            targetLength: request.targetLength
        )
        article.audience = request.audience
        article.quickNotes = request.quickNotes
        article.sourceLinks = request.sourceLinks
        article.outline = request.outline
        article.summary = request.summary
        article.purpose = request.purpose
        article.style = request.style
        article.keyTakeaway = request.keyTakeaway
        article.publishingIntent = request.publishingIntent

        if let series = request.series {
            article.series = series
            article.seriesPosition = nextSeriesPosition(in: series)
        }

        let titleBlock = ArticleBlock(type: .heading(level: 1), content: finalTitle, position: 0)
        let bodyBlock = ArticleBlock(type: .paragraph, content: "", position: 1000)
        article.blocks = [titleBlock, bodyBlock]
        article.drafts = [ArticleDraft(title: "Draft 1", content: finalTitle)]

        context.insert(article)
        try context.save()
        return article
    }

    private func nextSeriesPosition(in series: Series) -> Int {
        let maxPosition = series.articles.compactMap(\.seriesPosition).max() ?? 0
        return maxPosition + 1
    }
}