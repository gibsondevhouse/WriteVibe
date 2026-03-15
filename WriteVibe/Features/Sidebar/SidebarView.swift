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
    @Query(sort: \Conversation.updatedAt, order: .reverse) private var conversations: [Conversation]
    @State private var searchQuery = ""
    @State private var showExportToast = false
    @State private var toastMessage = ""
    @State private var isExportingFile = false
    @State private var isShowingSettings = false
    @State private var appsExpanded: Bool = true
    @State private var libraryExpanded: Bool = true
    @State private var expandedSections: Set<String> = ["Today", "Yesterday", "Last 7 Days", "Older"]

    private var sections: [(label: String, items: [Conversation])] {
        let now = Date()
        let cal = Calendar.current
        let availableConversations = appState.mergedConversations(from: conversations)
        let list = searchQuery.isEmpty
            ? availableConversations
            : availableConversations.filter { $0.title.localizedCaseInsensitiveContains(searchQuery) }

        var today:     [Conversation] = []
        var yesterday: [Conversation] = []
        var week:      [Conversation] = []
        var older:     [Conversation] = []

        for c in list {
            if cal.isDateInToday(c.updatedAt)                                                    { today.append(c) }
            else if cal.isDateInYesterday(c.updatedAt)                                          { yesterday.append(c) }
            else if let d = cal.dateComponents([.day], from: c.updatedAt, to: now).day, d <= 7 { week.append(c) }
            else                                                                                 { older.append(c) }
        }

        return [("Today", today), ("Yesterday", yesterday), ("Last 7 Days", week), ("Older", older)]
            .filter { !$1.isEmpty }
    }

    var body: some View {
        @Bindable var state = appState
        List(selection: $state.selectedId) {
            // Area A — Top-level navigation
            if searchQuery.isEmpty {
                Section {
                    if appsExpanded {
                        HStack {
                            Label("Images", systemImage: "photo.on.rectangle.angled")
                            Spacer()
                            Text("Soon")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.primary.opacity(0.05), in: Capsule())
                        }
                        .foregroundStyle(.secondary)
                        .opacity(0.7)
                        .padding(.vertical, 2)

                        HStack {
                            Label("Canvas", systemImage: "rectangle.and.pencil.and.ellipsis")
                            Spacer()
                            Text("Soon")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.primary.opacity(0.05), in: Capsule())
                        }
                        .foregroundStyle(.secondary)
                        .opacity(0.7)
                        .padding(.vertical, 2)

                        HStack {
                            Label("Templates", systemImage: "doc.on.doc")
                            Spacer()
                            Text("Soon")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.primary.opacity(0.05), in: Capsule())
                        }
                        .foregroundStyle(.secondary)
                        .opacity(0.7)
                        .padding(.vertical, 2)

                        HStack {
                            Label("Mood Board", systemImage: "theatermask.and.paintbrush")
                            Spacer()
                            Text("Soon")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.primary.opacity(0.05), in: Capsule())
                        }
                        .foregroundStyle(.secondary)
                        .opacity(0.7)
                        .padding(.vertical, 2)
                    }
                } header: {
                    CollapsibleSectionHeader(title: "Apps", isExpanded: appsExpanded) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { appsExpanded.toggle() }
                    }
                }

                Section {
                    if libraryExpanded {
                        Button {
                            appState.selectedId = nil
                            appState.destination = .articles
                        } label: {
                            Label("Articles", systemImage: "newspaper")
                                .foregroundStyle(appState.destination == .articles ? Color.accentColor : .primary)
                                .fontWeight(appState.destination == .articles ? .semibold : .regular)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(
                            appState.destination == .articles
                                ? Color.accentColor.opacity(0.1)
                                : Color.clear
                        )

                        Group {
                            HStack {
                                Label("Emails", systemImage: "envelope.open")
                                Spacer()
                                Text("Soon")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.tertiary)
                            }
                            HStack {
                                Label("Stories", systemImage: "book.closed")
                                Spacer()
                                Text("Soon")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.tertiary)
                            }
                            HStack {
                                Label("Essays", systemImage: "doc.text")
                                Spacer()
                                Text("Soon")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.tertiary)
                            }
                            HStack {
                                Label("Poetry", systemImage: "text.quote")
                                Spacer()
                                Text("Soon")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.tertiary)
                            }
                            HStack {
                                Label("Scripts", systemImage: "scroll")
                                Spacer()
                                Text("Soon")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.tertiary)
                            }
                            HStack {
                                Label("Research", systemImage: "magnifyingglass.circle")
                                Spacer()
                                Text("Soon")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .foregroundStyle(.secondary)
                        .opacity(0.7)
                        .padding(.vertical, 2)
                    }
                } header: {
                    CollapsibleSectionHeader(title: "Library", isExpanded: libraryExpanded) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { libraryExpanded.toggle() }
                    }
                }
            }

            // Area B — time-grouped thread sections (only shown in chat destination)
            if sections.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(searchQuery.isEmpty ? "No chats yet" : "No matches")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Text(searchQuery.isEmpty
                             ? "Start a new thread to see it here."
                             : "Try a different search term.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 6)
                }
            }

            ForEach(sections, id: \.label) { section in
                let isExpanded = expandedSections.contains(section.label)
                Section {
                    if isExpanded {
                        ForEach(section.items) { conv in
                            ConversationRow(conversation: conv)
                                .tag(conv.id)
                        }
                    }
                } header: {
                    CollapsibleSectionHeader(
                        title: section.label,
                        isExpanded: isExpanded
                    ) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                            if isExpanded {
                                expandedSections.remove(section.label)
                            } else {
                                expandedSections.insert(section.label)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $searchQuery, prompt: "Search threads")
        .onAppear {
            appState.bindModelContextIfNeeded(modelContext)
        }
        .onChange(of: appState.selectedId) { _, newId in
            // Selecting any conversation switches the detail back to chat
            if newId != nil {
                appState.destination = .chat
            }
        }
        .navigationTitle("WriteVibe")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    appState.pendingPrompt = nil
                    appState.selectedId = nil
                    appState.destination = .chat
                } label: {
                    Label("New Thread", systemImage: "square.and.pencil")
                }
                .help("New Thread")
            }
        }
        .safeAreaInset(edge: .bottom) {
            sidebarFooter
        }
        .overlay(alignment: .bottom) {
            if showExportToast {
                Text(toastMessage)
                    .font(.footnote)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                    .padding(.bottom, 60)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { showExportToast = false }
                        }
                    }
            }
        }
    }

    // MARK: - Footer

    private var sidebarFooter: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 0) {
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

                Menu {
                    Button {
                        guard let id = appState.selectedId,
                              let conv = appState.fetchConversation(id)
                        else { return }
                        if let content = ExportService.lastAssistantMessage(from: conv) {
                            ExportService.copyToClipboard(content)
                            toastMessage = "Copied to clipboard"
                            withAnimation { showExportToast = true }
                        } else {
                            toastMessage = "Nothing to export yet"
                            withAnimation { showExportToast = true }
                        }
                    } label: {
                        Label("Copy Last Reply", systemImage: "doc.on.doc")
                    }
                    
                    Button {
                        guard let id = appState.selectedId,
                              let conv = appState.fetchConversation(id)
                        else { return }
                        let markdown = ExportService.buildMarkdownExport(for: conv)
                        if ExportService.saveAsMarkdown(content: markdown, suggestedName: "\(conv.title).md") {
                            toastMessage = "Saved to file"
                        } else {
                            toastMessage = "Failed to save"
                        }
                        withAnimation { showExportToast = true }
                    } label: {
                        Label("Save as Markdown...", systemImage: "doc.text")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .menuStyle(.borderlessButton)
                .help("Export")
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

