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
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.top, 1)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(issue.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(issue.message)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.94))
                        Text("Next step: \(issue.nextStep)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                    }

                    Spacer(minLength: 12)

                    Button("Dismiss") {
                        appState.clearRuntimeIssue()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.red.opacity(0.92))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: Color.black.opacity(0.18), radius: 10, y: 4)
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

