//
//  StylesDashboardView.swift
//  WriteVibe
//

import SwiftUI

// MARK: - StylesDashboardView

struct StylesDashboardView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ContentUnavailableView {
            Label("Styles", systemImage: "paintbrush")
        } description: {
            Text("Define reusable writing styles — coming soon.")
        }
    }
}
