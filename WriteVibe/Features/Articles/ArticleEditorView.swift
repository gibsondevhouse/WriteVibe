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
    let viewModel: ArticleEditorViewModel
    @State private var editorState = EditorState()

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.hasPendingChanges {
                aiEditBar
                Divider()
            }
            if let issue = viewModel.aiError {
                errorBanner(issue)
                Divider()
            }

            if viewModel.hasPendingChanges {
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

                    selectionWorkflowCard
                        .padding(.top, 16)
                        .padding(.bottom, 8)

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
                FloatingFormatToolbar(
                    editorState: editorState,
                    isWorkflowRunning: viewModel.isSelectionWorkflowRunning,
                    onSummarizeSelection: { requestSelectionWorkflow(.summarize) },
                    onImproveSelection: { requestSelectionWorkflow(.improve) },
                    onGenerateVariants: { requestSelectionWorkflow(.variants) }
                )
                .padding(.top, 8)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeOut(duration: 0.15), value: editorState.hasSelection)
        .onChange(of: editorState.selectionPayload?.token) { _, newToken in
            viewModel.handleSelectionChange(currentToken: newToken)
        }
        .onDisappear {
            editorState.syncToArticle(article)
        }
    }

    private var aiEditButton: some View {
        Button {
            editorState.syncToArticle(article)
            viewModel.requestAIEdits(for: article, defaultModel: appState.defaultModel)
        } label: {
            if viewModel.isRequestingEdits {
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
        .disabled(viewModel.isRequestingEdits || article.sortedBlocks.isEmpty)
        .help("Ask AI to propose edits to this article")
    }

    // MARK: - Block Review Canvas (AI edit review mode)

    private var blockReviewCanvas: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 8) {
                ForEach(article.sortedBlocks) { block in
                    BlockRowView(
                        block: block,
                        spans: viewModel.showEdits ? (viewModel.blockChanges[block.id] ?? []) : [],
                        showEdits: viewModel.showEdits,
                        onAccept: { span in viewModel.acceptSpan(span, in: block, article: article) },
                        onReject: { span in viewModel.rejectSpan(span, in: block, article: article) },
                        onReturnAtEnd: {
                            viewModel.addBlock(type: .paragraph, to: article, after: block)
                            try? modelContext.save()
                        },
                        onDeleteEmpty: {
                            viewModel.deleteBlockIfEmpty(block, from: article)
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
            if let summary = viewModel.editSummary {
                Image(systemName: "sparkles")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.accentColor)
                Text(summary)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.15)) { viewModel.showEdits.toggle() }
            } label: {
                Label(
                    viewModel.showEdits ? "Hide Edits" : "Show Edits",
                    systemImage: viewModel.showEdits ? "eye.slash" : "eye"
                )
                .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button { viewModel.acceptAllChanges() } label: {
                Label("Accept All", systemImage: "checkmark.circle")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.green)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button { viewModel.rejectAllChanges(for: article) } label: {
                Label("Reject All", systemImage: "xmark.circle")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                editorState.syncToArticle(article)
                viewModel.requestAIEdits(for: article, defaultModel: appState.defaultModel)
            } label: {
                if viewModel.isRequestingEdits {
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
            .disabled(viewModel.isRequestingEdits || article.sortedBlocks.isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - Error Banner

    private func errorBanner(_ issue: RuntimeIssue) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(issue.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(issue.message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text("Next step: \(issue.nextStep)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Dismiss") { viewModel.aiError = nil }
                .font(.system(size: 11))
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.07))
    }

    @ViewBuilder
    private var selectionWorkflowCard: some View {
        if let workflow = viewModel.latestSelectionWorkflow {
            switch workflow.kind {
            case .summarize:
                workflowCard(
                    title: workflow.kind.title,
                    result: workflow.result,
                    bodyText: selectionBodyText(for: workflow.result.payload),
                    actionText: workflow.kind.primaryActionTitle,
                    onAction: nil,
                    onRetry: { retrySelectionWorkflow(workflow.kind) },
                    onDismiss: viewModel.dismissSelectionWorkflow
                )
            case .improve:
                workflowCard(
                    title: workflow.kind.title,
                    result: workflow.result,
                    bodyText: selectionBodyText(for: workflow.result.payload),
                    actionText: workflow.kind.primaryActionTitle,
                    onAction: applySelectionRewrite,
                    onRetry: { retrySelectionWorkflow(workflow.kind) },
                    onDismiss: viewModel.dismissSelectionWorkflow
                )
            case .variants:
                variantsWorkflowCard(
                    title: workflow.kind.title,
                    result: workflow.result,
                    variants: selectionVariants(for: workflow.result.payload),
                    onApplyVariant: applySelectionVariant,
                    onRetry: { retrySelectionWorkflow(workflow.kind) },
                    onDismiss: viewModel.dismissSelectionWorkflow
                )
            }
        }
    }

    private func requestSelectionWorkflow(_ kind: SelectionWorkflowKind) {
        guard let selection = editorState.selectionPayload else { return }
        viewModel.requestSelectionWorkflow(kind, article: article, selection: selection)
    }

    private func retrySelectionWorkflow(_ kind: SelectionWorkflowKind) {
        guard let selection = editorState.selectionPayload else { return }
        viewModel.requestSelectionWorkflow(kind, article: article, selection: selection)
    }

    private func applySelectionRewrite() {
        if viewModel.applySelectionRewrite(using: editorState) {
            editorState.syncToArticle(article)
        }
    }

    private func applySelectionVariant(_ index: Int) {
        if viewModel.applySelectionVariant(using: editorState, variantIndex: index) {
            editorState.syncToArticle(article)
        }
    }

    private func selectionBodyText(for payload: SelectionWorkflowPayload?) -> String? {
        guard let payload else { return nil }
        switch payload {
        case .summary(let proposal):
            return proposal.summaryText
        case .rewrite(let proposal):
            return proposal.rewrittenText
        case .variants:
            return nil
        }
    }

    private func selectionVariants(for payload: SelectionWorkflowPayload?) -> [SelectionVariantItem] {
        guard let payload,
              case .variants(let proposal) = payload else {
            return []
        }
        return proposal.variants
    }

    private func workflowCard<Payload>(
        title: String,
        result: AppleWorkflowTaskResult<Payload>,
        bodyText: String?,
        actionText: String?,
        onAction: (() -> Void)?,
        onRetry: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: iconName(for: result.state))
                    .foregroundStyle(iconColor(for: result.state))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                    Text(result.userMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text("Next step: \(result.nextStep)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if let bodyText, !bodyText.isEmpty {
                Text(bodyText)
                    .font(.system(size: 12))
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
            }

            HStack(spacing: 10) {
                if let actionText, let onAction, result.state == .success {
                    Button(actionText, action: onAction)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
                Button("Retry", action: onRetry)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("Dismiss", action: onDismiss)
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
            }
        }
        .padding(14)
        .background(cardBackgroundColor(for: result.state), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func variantsWorkflowCard(
        title: String,
        result: AppleWorkflowTaskResult<SelectionWorkflowPayload>,
        variants: [SelectionVariantItem],
        onApplyVariant: @escaping (Int) -> Void,
        onRetry: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: iconName(for: result.state))
                    .foregroundStyle(iconColor(for: result.state))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                    Text(result.userMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text("Next step: \(result.nextStep)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if result.state == .success {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(variants.enumerated()), id: \.offset) { index, item in
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.styleLabel.capitalized)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Text(item.text)
                                    .font(.system(size: 12))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            Button("Apply Variant") {
                                onApplyVariant(index)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                        .padding(12)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }

            HStack(spacing: 10) {
                Button("Retry", action: onRetry)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button("Dismiss", action: onDismiss)
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
            }
        }
        .padding(14)
        .background(cardBackgroundColor(for: result.state), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func iconName(for state: AppleWorkflowTaskState) -> String {
        switch state {
        case .success:
            return "checkmark.circle"
        case .unavailable:
            return "slash.circle"
        case .validationFailure:
            return "exclamationmark.circle"
        case .executionFailure:
            return "exclamationmark.triangle"
        case .fallbackComplete:
            return "arrow.triangle.2.circlepath.circle"
        }
    }

    private func iconColor(for state: AppleWorkflowTaskState) -> Color {
        switch state {
        case .success:
            return .green
        case .unavailable:
            return .orange
        case .validationFailure:
            return .yellow
        case .executionFailure:
            return .red
        case .fallbackComplete:
            return .blue
        }
    }

    private func cardBackgroundColor(for state: AppleWorkflowTaskState) -> Color {
        switch state {
        case .success:
            return Color.green.opacity(0.06)
        case .unavailable:
            return Color.orange.opacity(0.08)
        case .validationFailure:
            return Color.yellow.opacity(0.08)
        case .executionFailure:
            return Color.red.opacity(0.08)
        case .fallbackComplete:
            return Color.blue.opacity(0.08)
        }
    }
}
