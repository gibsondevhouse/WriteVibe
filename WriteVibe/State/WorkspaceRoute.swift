//
//  WorkspaceRoute.swift
//  WriteVibe
//

import Foundation

// MARK: - WorkspaceRoute

/// Single authoritative workspace navigation state for the detail area.
///
/// Replaces the split ownership between `ArticlesDashboardView.selectedArticleID`
/// (local `@State`) and `AppState.currentArticleID` (app-level). All destinations
/// for articles and series are expressed here; callers must not maintain a parallel
/// local selection binding after TASK-1107 lands.
enum WorkspaceRoute: Equatable {
    /// No resource is selected; the relevant dashboard list is shown.
    case none
    /// An article with the given UUID is the active workspace resource.
    case article(id: UUID)
    /// A series with the given UUID is the active workspace resource.
    case series(id: UUID)

    /// Returns the article UUID if the route is `.article`, otherwise `nil`.
    var articleID: UUID? {
        guard case .article(let id) = self else { return nil }
        return id
    }

    /// Returns the series UUID if the route is `.series`, otherwise `nil`.
    var seriesID: UUID? {
        guard case .series(let id) = self else { return nil }
        return id
    }
}
