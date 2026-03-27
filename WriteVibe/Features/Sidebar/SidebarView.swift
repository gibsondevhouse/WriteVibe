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

    private var isAnyArticleChildSelected: Bool {
        SidebarDestination.allCases.contains(appState.selectedDestination)
    }

    var body: some View {
        List {
            Section {
                articlesSection
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

    // MARK: - Articles Section

    private var articlesSection: some View {
        VStack(spacing: 0) {
            articlesSectionHeader
            if appState.isArticlesSectionExpanded {
                articlesChildList
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var articlesSectionHeader: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                appState.isArticlesSectionExpanded.toggle()
            }
        } label: {
            HStack(spacing: WVSpace.sm) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .rotationEffect(.degrees(appState.isArticlesSectionExpanded ? 90 : 0))
                    .animation(.spring(response: 0.3, dampingFraction: 0.85), value: appState.isArticlesSectionExpanded)
                    .foregroundStyle(isAnyArticleChildSelected ? Color.accentColor : .secondary)

                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 13))
                    .foregroundStyle(isAnyArticleChildSelected ? Color.accentColor : .primary)

                Text("Articles")
                    .font(.wvActionLabel)
                    .foregroundStyle(isAnyArticleChildSelected ? Color.accentColor : .primary)

                Spacer()
            }
            .padding(.vertical, WVSpace.sm)
            .padding(.horizontal, WVSpace.md)
            .background(
                RoundedRectangle(cornerRadius: WVRadius.chip)
                    .fill(isAnyArticleChildSelected ? Color.accentColor.opacity(0.08) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Articles section")
        .accessibilityHint(appState.isArticlesSectionExpanded ? "Collapse" : "Expand")
        .accessibilityAddTraits(.isButton)
    }

    private var articlesChildList: some View {
        VStack(spacing: 2) {
            ForEach(SidebarDestination.allCases) { destination in
                childRow(destination)
            }
        }
        .padding(.top, WVSpace.xs)
    }

    private func childRow(_ destination: SidebarDestination) -> some View {
        let isSelected = appState.selectedDestination == destination
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                appState.selectedDestination = destination
            }
        } label: {
            HStack(spacing: WVSpace.sm) {
                Image(systemName: destination.icon)
                    .font(.system(size: 12))
                    .frame(width: 18)
                Text(destination.label)
                    .font(.wvBody)
                    .fontWeight(isSelected ? .semibold : .regular)
                Spacer()
            }
            .foregroundStyle(isSelected ? .white : .secondary)
            .padding(.vertical, 6)
            .padding(.horizontal, WVSpace.md)
            .background(
                RoundedRectangle(cornerRadius: WVRadius.chip)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.leading, WVSpace.xl)
        .accessibilityLabel(destination.label)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
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

