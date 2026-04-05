//
//  OutlineEditorView.swift
//  WriteVibe
//

import SwiftUI

struct OutlineEditorView: View {
    @Bindable var article: Article
    let viewModel: ArticleEditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: WVSpace.sm) {
            header
            outlineWorkflowCard
            editor
            footerHint
        }
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, WVSpace.xxl)
        .padding(.vertical, WVSpace.lg)
        .background(.clear)
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: WVSpace.xs) {
                Text("Outline")
                    .wvSectionLabel()
                Text("Plan your structure with a bounded outline suggestion, then apply it explicitly if it fits.")
                    .font(.wvFootnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                viewModel.requestOutlineSuggestion(for: article)
            } label: {
                if viewModel.isOutlineWorkflowRunning {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 80)
                } else {
                    Label("Suggest Outline", systemImage: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(viewModel.isOutlineWorkflowRunning)
        }
    }

    // MARK: - Editor

    @ViewBuilder
    private var editor: some View {
        ZStack(alignment: .topLeading) {
            if article.outline.isEmpty {
                Text("Start with your main sections, key arguments, or scene beats…")
                    .font(.system(size: 14))
                    .foregroundStyle(.quaternary)
                    .padding(.top, 8)
                    .padding(.leading, 4)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $article.outline)
                .font(.system(size: 14))
                .scrollContentBackground(.hidden)
                .frame(maxHeight: .infinity)
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var footerHint: some View {
        Text("Use the outline to plan before drafting")
            .font(.wvNano)
            .foregroundStyle(.quaternary)
    }

    @ViewBuilder
    private var outlineWorkflowCard: some View {
        if let result = viewModel.latestOutlineWorkflowResult {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: iconName(for: result.state))
                        .foregroundStyle(iconColor(for: result.state))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Outline Suggestion")
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

                if let proposal = result.payload {
                    Text(proposal.previewText)
                        .font(.system(size: 12))
                        .textSelection(.enabled)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                }

                HStack(spacing: 10) {
                    if result.state == .success {
                        Button("Apply Outline") {
                            viewModel.applyOutlineSuggestion(to: article)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                    Button("Retry") {
                        viewModel.requestOutlineSuggestion(for: article)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Button("Dismiss") {
                        viewModel.dismissOutlineWorkflow()
                    }
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
