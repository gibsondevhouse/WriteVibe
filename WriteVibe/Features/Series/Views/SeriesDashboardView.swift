//
//  SeriesDashboardView.swift
//  WriteVibe
//

import SwiftUI

// MARK: - SeriesDashboardView

struct SeriesDashboardView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ContentUnavailableView {
            Label("Series", systemImage: "books.vertical")
        } description: {
            Text("Organize articles into series — coming soon.")
        }
    }
}