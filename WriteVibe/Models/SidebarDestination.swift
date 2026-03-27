//
//  SidebarDestination.swift
//  WriteVibe
//

import Foundation

// MARK: - SidebarDestination

enum SidebarDestination: String, Hashable, CaseIterable, Identifiable {
    case articles
    case series
    case styles

    var id: String { rawValue }

    var label: String {
        switch self {
        case .articles: "Articles"
        case .series: "Series"
        case .styles: "Styles"
        }
    }

    var icon: String {
        switch self {
        case .articles: "newspaper"
        case .series: "books.vertical"
        case .styles: "paintbrush"
        }
    }
}
