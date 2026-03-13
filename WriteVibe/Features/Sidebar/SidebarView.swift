//
//  SidebarView.swift
//  WriteVibe
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - SidebarView

struct SidebarView: View {
    @Environment(AppState.self) private var appState
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
        let list = searchQuery.isEmpty
            ? conversations
            : conversations.filter { $0.title.localizedCaseInsensitiveContains(searchQuery) }

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
                        Label("Images",     systemImage: "photo.on.rectangle.angled")
                        Label("Canvas",     systemImage: "rectangle.and.pencil.and.ellipsis")
                        Label("Templates",  systemImage: "doc.on.doc")
                        Label("Mood Board", systemImage: "theatermask.and.paintbrush")
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
                        Label("Emails",    systemImage: "envelope.open")
                        Label("Stories",   systemImage: "book.closed")
                        Label("Essays",    systemImage: "doc.text")
                        Label("Poetry",    systemImage: "text.quote")
                        Label("Scripts",   systemImage: "scroll")
                        Label("Research",  systemImage: "magnifyingglass.circle")
                    }
                } header: {
                    CollapsibleSectionHeader(title: "Library", isExpanded: libraryExpanded) {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) { libraryExpanded.toggle() }
                    }
                }
            }

            // Area B — time-grouped thread sections (only shown in chat destination)
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
                        guard let id = appState.selectedId else { return }
                        if let content = appState.exportLastAssistantMessage(from: id) {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(content, forType: .string)
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
                        
                        let markdown = appState.buildMarkdownExport(for: id)
                        let panel = NSSavePanel()
                        panel.allowedContentTypes = [.plainText]
                        panel.nameFieldStringValue = "\(conv.title).md"
                        
                        if panel.runModal() == .OK, let url = panel.url {
                            do {
                                try markdown.write(to: url, atomically: true, encoding: .utf8)
                                toastMessage = "Saved to file"
                                withAnimation { showExportToast = true }
                            } catch {
                                toastMessage = "Failed to save"
                                withAnimation { showExportToast = true }
                            }
                        }
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
    NavigationStack {
        SidebarView()
            .environment(AppState())
            .modelContainer(for: [Conversation.self, Message.self], inMemory: true)
    }
    .frame(width: 260, height: 560)
}

