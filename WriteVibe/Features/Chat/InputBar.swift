//
//  InputBar.swift
//  WriteVibe
//

import SwiftUI

// MARK: - ChatInputBar

struct ChatInputBar: View {
    @Binding var text: String
    let isThinking: Bool
    let tokenUsage: Double
    var showSoftGlow: Bool = false
    var focused: FocusState<Bool>.Binding
    var onDocumentAttached: ((String) -> Void)? = nil
    var onDocumentImportFailed: ((String) -> Void)? = nil
    let onSend: () -> Void
    let onStop: () -> Void

    @State private var showAttachMenu = false
    @State private var showURLAlert = false
    @State private var urlInput = ""
    @State private var selectedCommandIndex = 0

    private struct CommandSuggestion: Identifiable {
        let command: String
        let hint: String
        var id: String { command }
    }

    private static let supportedSlashCommands: [CommandSuggestion] = [
        .init(command: "/article help", hint: "Show all available article commands"),
        .init(command: "/article new", hint: "Start or reset a draft session"),
        .init(command: "/article set title \"<value>\"", hint: "Set draft title"),
        .init(command: "/article set subtitle \"<value>\"", hint: "Set draft subtitle"),
        .init(command: "/article set topic \"<value>\"", hint: "Set draft topic"),
        .init(command: "/article set audience \"<value>\"", hint: "Set draft audience"),
        .init(command: "/article set tone \"<value>\"", hint: "Set draft tone"),
        .init(command: "/article create", hint: "Create an article from the draft"),
        .init(command: "/article cancel", hint: "Cancel and clear draft"),
        .init(command: "/article update title \"<value>\"", hint: "Update field on selected article"),
        .init(command: "/article outline append \"<value>\"", hint: "Append an outline line"),
        .init(command: "/article outline replace 1 \"<value>\" --confirm", hint: "Replace outline line by index"),
        .init(command: "/article body append \"<value>\"", hint: "Append a paragraph block"),
        .init(command: "/article body insert heading 1 \"<value>\"", hint: "Insert heading at body index"),
        .init(command: "/article body insert paragraph 1 \"<value>\"", hint: "Insert paragraph at body index")
    ]

    private var canSend: Bool {
        !text.trimmed.isEmpty && !isThinking && tokenUsage < 0.98
    }

    private var commandSuggestions: [CommandSuggestion] {
        guard focused.wrappedValue else { return [] }
        let query = text.trimmed.lowercased()
        guard query.hasPrefix("/") else { return [] }
        guard !query.isEmpty else { return [] }

        return Self.supportedSlashCommands.filter { suggestion in
            let command = suggestion.command.lowercased()
            return command.hasPrefix(query) || command.contains(query)
        }
    }

    private var showsCommandSuggestions: Bool {
        !commandSuggestions.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            if tokenUsage > 0.5 {
                TokenUsageBar(tokenUsage: tokenUsage)

                Rectangle()
                    .fill(Color.primary.opacity(0.12))
                    .frame(height: 1)
            }

            Rectangle()
                .fill(Color.primary.opacity(0.55))
                .frame(height: 1)

            if showsCommandSuggestions {
                commandSuggestionsPopup
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
            }

            ChatInputField(
                text: $text,
                focused: focused,
                onSubmit: handleReturn,
                onMoveUp: { moveCommandSelection(delta: -1) },
                onMoveDown: { moveCommandSelection(delta: 1) },
                onDismissSuggestions: dismissSuggestions
            )
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 10)

            HStack(alignment: .center, spacing: 6) {
                attachButton
                CapabilityChipsBar()
                Spacer(minLength: 0)
                ChatSendButton(isThinking: isThinking, canSend: canSend, onSend: onSend, onStop: onStop)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
        }
        .background(Color(.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .alert("Attach URL", isPresented: $showURLAlert) {
            TextField("https://example.com", text: $urlInput)
            Button("Cancel", role: .cancel) { urlInput = "" }
            Button("Attach") {
                let urlToFetch = urlInput
                urlInput = ""
                Task {
                    do {
                        let content = try await DocumentIngestionService.fetchURL(urlString: urlToFetch)
                        onDocumentAttached?(content)
                    } catch {
                        onDocumentImportFailed?(error.localizedDescription)
                    }
                }
            }
        } message: {
            Text("Paste a URL to fetch its content and add it to your prompt.")
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    focused.wrappedValue
                        ? Color.primary.opacity(0.35)
                        : Color.primary.opacity(0.14),
                    lineWidth: 1
                )
                .animation(.easeInOut(duration: 0.2), value: focused.wrappedValue)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(showSoftGlow ? 0.22 : 0), lineWidth: 1)
                .shadow(color: Color.accentColor.opacity(showSoftGlow ? 0.22 : 0), radius: 14, x: 0, y: 0)
                .animation(.easeInOut(duration: 0.24), value: showSoftGlow)
        }
        .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 4)
        .shadow(color: Color.accentColor.opacity(showSoftGlow ? 0.15 : 0), radius: 16, x: 0, y: 0)
        .onChange(of: text) { _, _ in
            selectedCommandIndex = 0
        }
    }

    private var commandSuggestionsPopup: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(Array(commandSuggestions.enumerated()), id: \.element.id) { index, suggestion in
                        Button {
                            applySuggestion(at: index)
                        } label: {
                            HStack(spacing: 10) {
                                Text(suggestion.command)
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .lineLimit(1)
                                Spacer(minLength: 8)
                                Text(suggestion.hint)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(index == selectedCommandIndex ? Color.accentColor.opacity(0.14) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .id(index)
                    }
                }
                .padding(6)
            }
            .frame(maxHeight: 160)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 1)
            }
            .onChange(of: selectedCommandIndex) { _, newValue in
                withAnimation(.easeInOut(duration: 0.12)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }

    private func handleReturn() -> KeyPress.Result {
        if showsCommandSuggestions {
            applySuggestion(at: selectedCommandIndex)
            return .handled
        }
        guard canSend else { return .ignored }
        onSend()
        return .handled
    }

    private func moveCommandSelection(delta: Int) -> KeyPress.Result {
        guard showsCommandSuggestions else { return .ignored }
        let count = commandSuggestions.count
        guard count > 0 else { return .ignored }

        let next = max(0, min(count - 1, selectedCommandIndex + delta))
        selectedCommandIndex = next
        return .handled
    }

    private func dismissSuggestions() -> KeyPress.Result {
        guard showsCommandSuggestions else { return .ignored }
        return .ignored
    }

    private func applySuggestion(at index: Int) {
        guard commandSuggestions.indices.contains(index) else { return }
        text = commandSuggestions[index].command
        selectedCommandIndex = 0
    }

    // MARK: - Attach

    private var attachButton: some View {
        Button { showAttachMenu.toggle() } label: {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showAttachMenu, arrowEdge: .top) {
            AttachMenu(onDocumentAttached: { text in
                showAttachMenu = false
                onDocumentAttached?(text)
            }, onDocumentImportFailed: { error in
                showAttachMenu = false
                onDocumentImportFailed?(error)
            }, onShowURLAlert: {
                showAttachMenu = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showURLAlert = true
                }
            })
        }
    }
}
