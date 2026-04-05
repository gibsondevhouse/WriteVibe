//
//  Series.swift
//  WriteVibe
//

import Foundation
import SwiftData

// MARK: - Series

@Model
final class Series: Identifiable {
    var id: UUID
    var title: String
    var seriesDescription: String?
    var slug: String?
    var createdAt: Date
    var updatedAt: Date

    /// Articles that belong to this series.
    /// Delete rule is nullify — deleting a Series detaches articles but does not delete them.
    @Relationship(deleteRule: .nullify, inverse: \Article.series)
    var articles: [Article] = []

    init(
        title: String,
        seriesDescription: String? = nil,
        slug: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.seriesDescription = seriesDescription
        self.slug = slug
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
