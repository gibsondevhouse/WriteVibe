//
//  ChatView.swift
//  WriteVibe
//

import SwiftUI
import SwiftData

// MARK: - ChatView

struct ChatView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var inputText = ""
    @FocusState private var inputFocused: Bool

    @State private var showExportToast = false
    @State private var toastMessage = ""

    // State to control the visibility of the analysis panel
    @State private var isAnalysisPanelVisible: Bool = false

    private var conversation: Conversation? { appState.selected }
    // Sort by timestamp so SwiftData insertion order doesn't affect display order.
    private var messages: [Message] {
        (conversation?.messages ?? []).sorted { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack {
                messageList
                // Conditionally display the analysis panel
                if isAnalysisPanelVisible {
                    WritingAnalysisPanelView(isPanelOpen: $isAnalysisPanelVisible)
                        .padding(.bottom, 8) // Add some padding below the panel
                }
                floatingInput
            }
        }
        .navigationTitle(conversation?.title ?? "New Thread")
        .toolbar {
            if let conv = conversation {
                @Bindable var c = conv
                ToolbarItem(placement: .navigation) {
                    ModelPickerTrigger(
                        model: $c.model,
                        modelIdentifier: $c.modelIdentifier,
                        availableOllamaModels: appState.availableOllamaModels
                    )
                }
            }
            ToolbarItem {

                Menu {
                    Button {
                        guard let conv = conversation else { return }
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
                        guard let conv = conversation else { return }
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
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .help("Export thread")
            }
        }
        .onAppear {
            appState.bindModelContextIfNeeded(modelContext)
            inputFocused = true
            // Sync state when view appears
            isAnalysisPanelVisible = appState.isAnalysisPanelOpen
        }
        .onChange(of: appState.selectedId) { inputFocused = true }
        .onChange(of: appState.isAnalysisPanelOpen) { newValue in
            // Update local state when AppState changes
            isAnalysisPanelVisible = newValue
        }
        .task {
            await appState.refreshOllamaModels()
        }
        .overlay(alignment: .top) {
            if showExportToast {
                Text(toastMessage)
                    .font(.footnote)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                    .padding(.top, 40)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { showExportToast = false }
                        }
                    }
            }
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ChatScrollContainer(
            messages: messages,
            isThinking: appState.isThinkingInSelected,
            tailID: "tail",
            tailHeight: 160,
            horizontalPadding: 24,
            verticalPadding: 20
        ) { i, msg in
            MessageBubble(
                message: msg,
                isLast: i == messages.count - 1 && !appState.isThinkingInSelected,
                isStreaming: appState.isThinkingInSelected && i == messages.count - 1,
                showAvatar: isGroupEnd(at: i),
                topPad: isGroupStart(at: i) ? 28 : 8,
                onFeedback: { feedback in
                    guard let conversationID = appState.selectedId else { return }
                    appState.setFeedback(feedback, for: msg.id, in: conversationID)
                },
                onRegenerate: {
                    guard let conversationID = appState.selectedId else { return }
                    appState.regenerateLastAssistantResponse(in: conversationID)
                }
            )
        }
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Grouping Helpers

    private func isGroupEnd(at i: Int) -> Bool {
        i == messages.count - 1 || messages[i].role != messages[i + 1].role
    }

    private func isGroupStart(at i: Int) -> Bool {
        i == 0 || messages[i].role != messages[i - 1].role
    }

    // MARK: - Floating Input

    private var floatingInput: some View {
        VStack(spacing: 0) {
            if messages.last?.role == .assistant && !appState.isThinkingInSelected {
                writingActionsBar
                    .padding(.bottom, 8)
            }

            ChatInputBar(
                text: $inputText,
                isThinking: appState.isThinkingInSelected,
                tokenUsage: appState.selectedId.map { appState.estimatedTokenUsage(for: $0) / 4096.0 } ?? 0.0,
                focused: $inputFocused,
                onDocumentAttached: { extractedText in
                    inputText = """
Please read the following document and help me improve it:

\(extractedText)
"""
                },
                onDocumentImportFailed: { errorMessage in
                    toastMessage = errorMessage
                    withAnimation { showExportToast = true }
                },
                onSend: sendMessage,
                onStop: stopGeneration
            )
            .padding(.bottom, 16)
        }
        .frame(maxWidth: 760)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Writing Actions

    private var writingActionsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                // Existing Writing Actions (Improve, Expand, etc.)
                ForEach(WritingAction.all) { action in
                    Button {
                        guard let id = appState.selectedId else { return }
                        appState.send(action.prompt, in: id)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: action.icon).font(.caption)
                            Text(action.label).font(.callout)
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(in: Capsule())
                }

                // Analyze Button - conditionally shown
                if let lastAssistantMessage = messages.last(where: { $0.role == .assistant && !$0.content.isEmpty }),
                   !appState.isAnalysisPanelOpen { // Only show if panel is not already open and there's assistant content
                    Button {
                        // Action to trigger analysis and open the panel
                        // This button triggers the analysis and then ensures the panel is open.
                        // The MessageBubble's action chip will handle the actual analysis call and state updates.
                        // This button here primarily acts as a toggle for the panel,
                        // ensuring analysis is done if needed before opening.
                        
                        // Check if analysis is already loaded or if it's stale
                        // For simplicity, re-analyze if panel is closed or no result is present.
                        Task {
                            // Check if analysis is already loaded for the last assistant message or if it's stale
                            // For now, re-analyze if panel is closed or no result is present.
                            if appState.analysisResult == nil { // Only analyze if no result is available
                                do {
                                    let analysis = try await AppleIntelligenceService.analyzeWriting(text: lastAssistantMessage.content)
                                    appState.analysisResult = analysis
                                    appState.isAnalysisPanelOpen = true
                                } catch {
                                    print("Error triggering analysis from ChatView: \(error.localizedDescription)")
                                    // Optionally show an error toast
                                    appState.analysisResult = nil // Clear any stale result
                                    appState.isAnalysisPanelOpen = false // Close panel if analysis fails
                                }
                            } else {
                                // If results are already present, just open the panel
                                appState.isAnalysisPanelOpen = true
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "chart.bar").font(.caption) // Icon for analysis
                            Text("Analyze").font(.callout)
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(in: Capsule())
                    .help("Analyze writing")
                }
            }
        }
    }

    // MARK: - Send

    private func sendMessage() {
        appState.bindModelContextIfNeeded(modelContext)
        let id: UUID?
        if let selectedId = appState.selectedId,
           appState.fetchConversation(selectedId) != nil {
            id = selectedId
        } else {
            id = appState.newConversation()
        }
        guard let id else { return }
        let text = inputText
        if appState.send(text, in: id) {
            inputText = ""
        }
    }

    private func stopGeneration() {
        appState.bindModelContextIfNeeded(modelContext)
        guard let id = appState.selectedId else { return }
        appState.stopGeneration(for: id)
    }
}

