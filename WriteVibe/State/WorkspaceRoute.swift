//
//  WorkspaceRoute.swift
//  WriteVibe
//

import Foundation
import Observation

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

// MARK: - WorkspaceNavigationState

/// Unified navigation contract for sidebar destination + workspace resource route.
///
/// Invariants:
/// - `.article` route always implies `.articles` destination.
/// - `.series` route always implies `.series` destination.
/// - `.styles` destination can never hold a resource route.
@MainActor
@Observable
final class WorkspaceNavigationState {
    private(set) var selectedDestination: SidebarDestination = .articles
    private(set) var route: WorkspaceRoute = .none
    var isArticlesSectionExpanded: Bool = true

    var currentArticleID: UUID? { route.articleID }
    var currentSeriesID: UUID? { route.seriesID }

    func selectDestination(_ destination: SidebarDestination) {
        selectedDestination = destination
        normalizeForDestination()
    }

    func setRoute(_ newRoute: WorkspaceRoute) {
        route = newRoute

        switch newRoute {
        case .article:
            selectedDestination = .articles
        case .series:
            selectedDestination = .series
        case .none:
            break
        }

        normalizeForDestination()
    }

    func showDashboard(in destination: SidebarDestination? = nil) {
        if let destination {
            selectedDestination = destination
        }
        route = .none
        normalizeForDestination()
    }

    func openArticle(id: UUID) {
        selectedDestination = .articles
        route = .article(id: id)
    }

    func openSeries(id: UUID) {
        selectedDestination = .series
        route = .series(id: id)
    }

    private func normalizeForDestination() {
        switch selectedDestination {
        case .articles:
            if case .series = route {
                route = .none
            }
        case .series:
            if case .article = route {
                route = .none
            }
        case .styles:
            route = .none
        }
    }
}
