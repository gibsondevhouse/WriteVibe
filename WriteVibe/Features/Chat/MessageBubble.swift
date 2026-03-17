//
//  MessageBubble.swift
//  WriteVibe
//

import SwiftUI

// MARK: - MessageBubble

struct MessageBubble: View {
    @Environment(AppState.self) private var appState // Access AppState for analysis and panel state

    let message:    Message
    let isLast:     Bool
    let isStreaming: Bool
    let showAvatar: Bool
    let topPad:     CGFloat
    var onFeedback: ((Message.Feedback) -> Void)? = nil
    var onRegenerate: (() -> Void)? = nil

    @State private var isHovered = false
    @State private var copied    = false
    @State private var isAnalyzing = false
    @State private var isGeneratingVariants = false
    @State private var variantPickerContent: String? = nil

    private var isUser: Bool { message.role == .user }

    var body: some View {
        Group {
            if isUser { userTurn } else { assistantTurn }
        }
        .padding(.top, topPad)
        .onHover { isHovered = $0 }
    }

    // MARK: - User Turn

    private var userTurn: some View {
        VStack(alignment: .trailing, spacing: 5) {
            Text(message.content)
                .font(.body)
                .lineSpacing(4)
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.accentColor)
                }
                .frame(maxWidth: 480, alignment: .trailing)

            if isHovered {
                timestamp
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }

    // MARK: - Assistant Turn

    private var assistantTurn: some View {
        VStack(alignment: .leading, spacing: 10) {
            MarkdownMessageText(content: message.content, isStreaming: isStreaming)
                .textSelection(.enabled)

            if isHovered || isLast {
                messageActions
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeOut(duration: 0.15), value: isHovered)
        .animation(.easeOut(duration: 0.15), value: isLast)
        .sheet(item: Binding(
            get: { variantPickerContent.map { VariantSource(text: $0) } },
            set: { variantPickerContent = $0?.text }
        )) { source in
            if #available(macOS 26, *) {
                VariantPickerView(originalText: source.text) {
                    variantPickerContent = nil
                }
            }
        }
    }

    // MARK: - Message Actions

    private var messageActions: some View {
        HStack(spacing: 2) {
            MessageActionButton(
                symbol: copied ? "checkmark" : "doc.on.doc",
                label:  copied ? "Copied!" : "Copy"
            ) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(message.content, forType: .string)
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
            }

            MessageActionButton(
                symbol: message.feedback == .positive ? "hand.thumbsup.fill" : "hand.thumbsup",
                label: "Good response"
            ) {
                onFeedback?(.positive)
            }
            MessageActionButton(
                symbol: message.feedback == .negative ? "hand.thumbsdown.fill" : "hand.thumbsdown",
                label: "Bad response"
            ) {
                onFeedback?(.negative)
            }

            // Analyze button for writing analysis
            MessageActionButton(
                symbol: isAnalyzing ? "" : "chart.bar", // Use empty string or a different icon if analyzing
                label: isAnalyzing ? "Analyzing..." : "Analyze"
            ) {
                if !isAnalyzing {
                    isAnalyzing = true
                    Task {
                        do {
                            let analysis = try await AppleIntelligenceService.analyzeWriting(text: message.content)
                            appState.analysisResult = analysis
                            appState.isAnalysisPanelOpen = true // Open the panel
                        } catch {
                            // Handle error: perhaps show an alert or log it
                            print("Error analyzing writing: \(error.localizedDescription)")
                            appState.analysisResult = nil // Clear any previous result on error
                        }
                        isAnalyzing = false // Stop analyzing state
                    }
                }
            }
            .disabled(isAnalyzing) // Disable while analyzing

            // Variants chip — Apple Intelligence only, shown on last assistant message
            if isLast, #available(macOS 26, *), AppleIntelligenceService.isAvailable {
                MessageActionButton(
                    symbol: isGeneratingVariants ? "" : "square.on.square",
                    label: isGeneratingVariants ? "Generating…" : "Variants"
                ) {
                    guard !isGeneratingVariants else { return }
                    isGeneratingVariants = true
                    Task {
                        do {
                            let result = try await AppleIntelligenceService.generateVariants(
                                for: message.content,
                                tone: "Balanced"
                            )
                            if result.variants.count >= 3 {
                                variantPickerContent = message.content
                            }
                        } catch {
                            // Silently discard — no-op if Apple Intelligence is unavailable
                        }
                        isGeneratingVariants = false
                    }
                }
                .disabled(isGeneratingVariants)
            }

            if isLast {
                MessageActionButton(symbol: "arrow.counterclockwise", label: "Regenerate") {
                    onRegenerate?()
                }
            }

            Spacer()
        }
    }

    private var timestamp: some View {
        Text(message.timestamp, style: .time)
            .font(.caption2)
            .foregroundStyle(.tertiary)
    }
}

// MARK: - MessageActionButton

struct MessageActionButton: View {
    let symbol: String
    let label:  String
    let action: () -> Void
    @State private var isHovered = false

    // Inject AppState to check for analysis state if needed for button disabling/styling
    @Environment(AppState.self) private var appState

    var body: some View {
        Button(action: action) {
            HStack { // Use HStack to potentially include spinner if needed
                if symbol.isEmpty && label.contains("Analyzing") { // Special case for analysis spinner
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(0.6)
                        .frame(width: 28, height: 28)
                } else {
                    Image(systemName: symbol)
                        .font(.caption)
                        .foregroundStyle(isHovered ? Color.primary : Color.secondary)
                        .frame(width: 28, height: 28)
                }
            }
            .background {
                if isHovered {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            }
        }
        .buttonStyle(.plain)
        .help(label)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.1), value: isHovered)
        // Disable button if analysis is in progress and this is the analyze button
        .disabled(symbol.isEmpty && label.contains("Analyzing"))
    }
}

// MARK: - VariantSource

/// Thin `Identifiable` wrapper so `variantPickerContent` can drive a `.sheet(item:)`.
private struct VariantSource: Identifiable {
    let id = UUID()
    let text: String
}
