//
//  SidebarView.swift
//  WriteVibe
//

import SwiftUI
import SwiftData

// MARK: - SidebarView

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var isShowingSettings = false

    var body: some View {
        List {
            Section {
                Label("Articles", systemImage: "newspaper")
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentColor)
                    .listRowBackground(Color.accentColor.opacity(0.08))
            } header: {
                Text("Writing")
            }

            Section {
                comingSoonRow("Emails",    icon: "envelope.open")
                comingSoonRow("Stories",   icon: "book.closed")
                comingSoonRow("Essays",    icon: "doc.text")
                comingSoonRow("Poetry",    icon: "text.quote")
                comingSoonRow("Scripts",   icon: "scroll")
                comingSoonRow("Research",  icon: "magnifyingglass.circle")
            } header: {
                Text("Coming Soon")
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("WriteVibe")
        .onAppear {
            appState.bindModelContextIfNeeded(modelContext)
        }
        .safeAreaInset(edge: .bottom) {
            sidebarFooter
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func comingSoonRow(_ title: String, icon: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            Text("Soon")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.primary.opacity(0.05), in: Capsule())
        }
        .foregroundStyle(.secondary)
        .opacity(0.6)
    }

    // MARK: - Footer

    private var sidebarFooter: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Button { isShowingSettings = true } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 12))
                        Text("Settings")
                            .font(.footnote)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
                    .padding(.leading, 2)
                }
                .buttonStyle(.borderless)
                .help("Settings")
                .sheet(isPresented: $isShowingSettings) {
                    SettingsView()
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(.bar)
    }
}

// MARK: - Preview

#Preview {
    let services = ServiceContainer()
    NavigationStack {
        SidebarView()
            .environment(services)
            .environment(AppState(services: services))
            .modelContainer(for: [Conversation.self, Message.self], inMemory: true)
    }
    .frame(width: 260, height: 560)
}

