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
            appState.bindModelContextIfNeeded(modelContext)
            // Open copilot if the app starts on the articles destination
            if appState.destination == .articles && !appState.isCopilotOpen {
                appState.openCopilot()
            }
        }
        .onChange(of: modelContext) { _, newContext in
            appState.bindModelContextIfNeeded(newContext)
        }
        .onChange(of: appState.destination) { _, newDest in
            if newDest == .articles && !appState.isCopilotOpen {
                appState.openCopilot()
            }
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
            if appState.selected != nil {
                ChatView()
            } else {
                WelcomeView()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let services = ServiceContainer()
    WelcomeView()
        .environment(services)
        .environment(AppState(services: services))
        .frame(width: 700, height: 560)
}

