//
//  ContentView.swift
//  WriteVibe
//

import SwiftUI
import SwiftData

// MARK: - ContentView

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var appState = AppState()
    @State private var columnVisibility = NavigationSplitViewVisibility.automatic

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 230, ideal: 270, max: 340)
        } detail: {
            if appState.selectedId != nil, appState.selected != nil {
                ChatView()
            } else {
                WelcomeView()
            }
        }
        .environment(appState)
        .frame(minWidth: 820, minHeight: 520)
        .onAppear {
            appState.modelContext = modelContext
        }
        .task {
            await appState.refreshOllamaModels()
        }
    }
}

// MARK: - Preview

#Preview {
    WelcomeView()
        .environment(AppState())
        .frame(width: 700, height: 560)
}

