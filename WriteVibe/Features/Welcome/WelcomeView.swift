//
//  WelcomeView.swift
//  WriteVibe
//

import SwiftUI
import SwiftData

// MARK: - WelcomeView

struct WelcomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var inputText = ""
    @FocusState private var inputFocused: Bool

    private let writingModes: [(icon: String, label: String, description: String, prompt: String)] = [
        ("doc.text",       "Essay",   "Write a well-structured essay",       "Write a well-structured essay about "),
        ("book.closed",    "Story",   "Write a compelling short story",      "Write a compelling short story about "),
        ("newspaper",      "Article", "Write an engaging article",           "Write an engaging article about "),
        ("envelope",       "Email",   "Write a professional email",          "Write a professional email that "),
        ("wand.and.stars", "Edit",    "Polish or reshape existing text",    "Please review and improve the following text: "),
        ("list.bullet",    "Outline", "Structure your thinking",             "Create a detailed outline for "),
    ]

    var body: some View {
        @Bindable var state = appState
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 0) {
                // Brand eyebrow
                Text("WRITEVIBE")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(5)
                    .foregroundStyle(.tertiary)

                Spacer().frame(height: 20)

                // Headline
                VStack(spacing: 8) {
                    Text("Begin writing.")
                        .font(.system(size: 30, weight: .semibold))
                        .multilineTextAlignment(.center)
                    Text("Describe what you need, or choose a direction below.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer().frame(height: 32)

                // Composer — primary action
                ChatInputBar(
                    text: $inputText,
                    isThinking: false,
                    tokenUsage: 0.0,
                    focused: $inputFocused,
                    onSend: { startWriting(with: inputText) },
                    onStop: {}
                )
                .frame(maxWidth: 540)

                Spacer().frame(height: 16)

                // Writing mode entry points
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 8
                ) {
                    ForEach(writingModes, id: \.label) { mode in
                        WritingModeCard(
                            icon: mode.icon,
                            label: mode.label,
                            description: mode.description
                        ) {
                            inputText = mode.prompt
                            inputFocused = true
                        }
                    }
                }
                .frame(maxWidth: 540)
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .onAppear { inputFocused = true }
        .onAppear {
            appState.bindModelContextIfNeeded(modelContext)
        }
        .onAppear {
            if let pending = appState.pendingPrompt {
                inputText = pending
                appState.pendingPrompt = nil
            }
        }
        .onChange(of: appState.pendingPrompt) { _, newValue in
            if let pending = newValue {
                inputText = pending
                appState.pendingPrompt = nil
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                ModelPickerTrigger(
                    model: $state.defaultModel,
                    ollamaModelName: $state.defaultOllamaModelName,
                    availableOllamaModels: state.availableOllamaModels
                )
            }
        }
    }

    // MARK: - Action

    private func startWriting(with text: String) {
        appState.bindModelContextIfNeeded(modelContext)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let id = appState.newConversation() else { return }
        if appState.send(trimmed, in: id) {
            inputText = ""
        }
    }
}

// MARK: - Preview

#Preview {
    WelcomeView()
        .environment(AppState())
        .frame(width: 720, height: 600)
}
