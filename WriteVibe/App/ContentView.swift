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
            detailContent
                .toolbar {
                    // Show copilot toggle only when not in the full-screen chat destination
                    if appState.destination != .chat {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    if appState.isCopilotOpen {
                                        appState.isCopilotOpen = false
                                    } else {
                                        appState.openCopilot()
                                    }
                                }
                            } label: {
                                Image(systemName: "sparkles")
                                    .symbolVariant(appState.isCopilotOpen ? .fill : .none)
                            }
                            .help(appState.isCopilotOpen ? "Close AI Copilot" : "Open AI Copilot")
                        }
                    }
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

    // MARK: - Detail content

    @ViewBuilder
    private var detailContent: some View {
        switch appState.destination {
        case .articles:
            HStack(spacing: 0) {
                ArticlesDashboardView()
                if appState.isCopilotOpen {
                    Divider()
                    CopilotPanel()
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        case .chat:
            if appState.selectedId != nil, appState.selected != nil {
                ChatView()
            } else {
                WelcomeView()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    WelcomeView()
        .environment(AppState())
        .frame(width: 700, height: 560)
}

