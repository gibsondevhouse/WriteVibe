//
//  ArticleEditorView.swift
//  WriteVibe
//

import SwiftUI
import SwiftData

struct ArticleEditorView: View {
    @Bindable var article: Article

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var vm = ArticleEditorViewModel()
    @State private var editorState = EditorState()

    var body: some View {
        VStack(spacing: 0) {
            if vm.hasPendingChanges {
                aiEditBar
                Divider()
            }
            if let errorMsg = vm.aiErrorMessage {
                errorBanner(errorMsg)
                Divider()
            }

            if vm.hasPendingChanges {
                blockReviewCanvas
            } else {
                mediumEditorCanvas
            }
        }
    }

    // MARK: - Medium Editor Canvas (write mode)

    private var mediumEditorCanvas: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Spacer()
                        aiEditButton
                    }

                    TitleField(text: $article.title)

                    SubtitleField(text: $article.subtitle)
                        .padding(.top, 8)

                    Rectangle()
                        .fill(Color.primary.opacity(0.06))
                        .frame(height: 1)
                        .padding(.top, 14)
                        .padding(.bottom, 2)

                    EditorTextView(editorState: editorState, initialBlocks: article.bodyBlocks)
                        .frame(minHeight: 200, alignment: .topLeading)
                        .overlay(alignment: .topLeading) {
                            if editorState.showInsertionButton {
                                BlockInsertionMenu(editorState: editorState)
                                    .offset(x: -32, y: editorState.insertionButtonYOffset)
                                    .transition(.opacity)
                            }
                        }
                        .animation(.easeOut(duration: 0.12), value: editorState.showInsertionButton)
                }
                .padding(.horizontal, 48)
                .padding(.vertical, 40)
                .frame(maxWidth: 740)
                .frame(maxWidth: .infinity)
            }

            if editorState.hasSelection {
                FloatingFormatToolbar(editorState: editorState)
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeOut(duration: 0.15), value: editorState.hasSelection)
        .onDisappear {
            editorState.syncToArticle(article)
        }
    }

    private var aiEditButton: some View {
        Button {
            editorState.syncToArticle(article)
            vm.requestAIEdits(for: article, defaultModel: appState.defaultModel)
        } label: {
            if vm.isRequestingEdits {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.small)
                    .frame(width: 60)
            } else {
                Label("AI Edit", systemImage: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .disabled(vm.isRequestingEdits || article.sortedBlocks.isEmpty)
        .help("Ask AI to propose edits to this article")
    }

    // MARK: - Block Review Canvas (AI edit review mode)

    private var blockReviewCanvas: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(article.sortedBlocks) { block in
                    BlockRowView(
                        block: block,
                        spans: vm.showEdits ? (vm.blockChanges[block.id] ?? []) : [],
                        showEdits: vm.showEdits,
                        onAccept: { span in vm.acceptSpan(span, in: block, article: article) },
                        onReject: { span in vm.rejectSpan(span, in: block, article: article) },
                        onReturnAtEnd: {
                            vm.addBlock(type: .paragraph, to: article, after: block)
                            try? modelContext.save()
                        },
                        onDeleteEmpty: {
                            vm.deleteBlockIfEmpty(block, from: article)
                            try? modelContext.save()
                        }
                    )
                    .padding(.horizontal, 2)
                }
            }
            .padding(48)
            .frame(maxWidth: 740)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - AI Edit Bar

    private var aiEditBar: some View {
        HStack(spacing: 12) {
            if let summary = vm.editSummary {
                Image(systemName: "sparkles")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.accentColor)
                Text(summary)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.15)) { vm.showEdits.toggle() }
            } label: {
                Label(
                    vm.showEdits ? "Hide Edits" : "Show Edits",
                    systemImage: vm.showEdits ? "eye.slash" : "eye"
                )
                .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button { vm.acceptAllChanges() } label: {
                Label("Accept All", systemImage: "checkmark.circle")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.green)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button { vm.rejectAllChanges(for: article) } label: {
                Label("Reject All", systemImage: "xmark.circle")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                editorState.syncToArticle(article)
                vm.requestAIEdits(for: article, defaultModel: appState.defaultModel)
            } label: {
                if vm.isRequestingEdits {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.small)
                        .frame(width: 60)
                } else {
                    Label("AI Edit", systemImage: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(vm.isRequestingEdits || article.sortedBlocks.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 11))
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Button("Dismiss") { vm.aiErrorMessage = nil }
                .font(.system(size: 11))
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.07))
    }
}
