//
//  SeriesMembershipService.swift
//  WriteVibe
//

import Foundation

@MainActor
final class SeriesMembershipService {
    func nextPosition(in series: Series) -> Int {
        let maxPosition = series.articles.compactMap(\.seriesPosition).max() ?? 0
        return maxPosition + 1
    }

    func attach(_ article: Article, to series: Series) {
        article.series = series
        article.seriesPosition = nextPosition(in: series)
    }
}
