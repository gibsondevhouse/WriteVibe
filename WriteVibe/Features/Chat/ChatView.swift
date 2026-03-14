//
//  ChatView.swift
//  WriteVibe
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - ChatView

struct ChatView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var inputText = ""
    @FocusState private var inputFocused: Bool

    @State private var showExportToast = false
    @State private var toastMessage = ""

    private var conversation: Conversation? { appState.selected }
    // Sort by timestamp so SwiftData insertion order doesn't affect display order.
    private var messages: [Message] {
        (conversation?.messages ?? []).sorted { $0.timestamp < $1.timestamp }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            messageList
            floatingInput
        }
        .navigationTitle(conversation?.title ?? "New Thread")
        .toolbar {
            if let conv = conversation {
                @Bindable var c = conv
                ToolbarItem(placement: .navigation) {
                    ModelPickerTrigger(
                        model: $c.model,
                        ollamaModelName: $c.ollamaModelName,
                        availableOllamaModels: appState.availableOllamaModels
                    )
                }
            }
            ToolbarItem {

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
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .help("Export thread")
            }
        }
        .onAppear {
            appState.bindModelContextIfNeeded(modelContext)
            inputFocused = true
        }
        .onChange(of: appState.selectedId) { inputFocused = true }
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
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(messages.enumerated()), id: \.element.id) { i, msg in
                        MessageBubble(
                            message:     msg,
                            isLast:      i == messages.count - 1 && !appState.isThinkingInSelected,
                            isStreaming: appState.isThinkingInSelected && i == messages.count - 1,
                            showAvatar:  isGroupEnd(at: i),
                            topPad:      isGroupStart(at: i) ? 28 : 8
                        )
                    }

                    if appState.isThinkingInSelected {
                        ThinkingIndicator()
                            .padding(.top, 10)
                    }

                    Color.clear.frame(height: 160).id("tail")
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
                .animation(.easeOut(duration: 0.2), value: messages.count)
                .animation(.easeOut(duration: 0.2), value: appState.isThinkingInSelected)
            }
            .onChange(of: messages.count) {
                withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("tail") }
            }
            .onChange(of: appState.isThinkingInSelected) {
                withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo("tail") }
            }
            // While a response is streaming, keep scrolling to the tail so the
            // user always sees the latest tokens without having to scroll manually.
            .task(id: appState.isThinkingInSelected) {
                guard appState.isThinkingInSelected else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(150))
                    proxy.scrollTo("tail")
                }
            }
        }
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
                    inputText = "Please read the following document and help me improve it:\n\n\(extractedText)"
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

    private let writingActions: [(icon: String, label: String, prompt: String)] = [
        ("wand.and.stars",                     "Improve",  "Improve and polish that. Show only the improved version."),
        ("arrow.up.left.and.arrow.down.right", "Expand",   "Expand on that with more detail and depth."),
        ("arrow.down.right.and.arrow.up.left", "Shorten",  "Make that more concise while keeping every key point."),
        ("theatermasks.fill",                  "Rephrase", "Rephrase that with a fresh angle and different wording."),
        ("text.append",                        "Continue", "Continue writing from where you left off."),
    ]

    private var writingActionsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                ForEach(writingActions, id: \.label) { action in
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

