//
//  ContentView.swift
//  WriteVibe
//

import SwiftUI
import SwiftData

// MARK: - ContentView

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @State private var columnVisibility = NavigationSplitViewVisibility.automatic

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
        } detail: {
            HStack(spacing: 0) {
                switch appState.selectedDestination {
                case .articles:
                    ArticlesDashboardView()
                case .series:
                    SeriesDashboardView()
                case .styles:
                    StylesDashboardView()
                }
                if appState.isCopilotOpen {
                    Divider()
                    CopilotPanel()
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .toolbar {
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
        .environment(appState)
        .frame(minWidth: 820, minHeight: 520)
        .onAppear {
            appState.bindModelContextIfNeeded(modelContext)
        }
        .onChange(of: modelContext) { _, newContext in
            appState.bindModelContextIfNeeded(newContext)
        }
        .task {
            await appState.refreshOllamaModels()
        }
        .overlay(alignment: .top) {
            if let issue = appState.runtimeIssue {
                Text(issue)
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.red.opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(.top, 10)
                    .padding(.horizontal, 12)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let services = ServiceContainer()
    ArticlesDashboardView()
        .environment(services)
        .environment(AppState(services: services))
        .frame(width: 700, height: 560)
}

