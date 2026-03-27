//
//  ArticleAIActionsPanel.swift
//  WriteVibe
//

import SwiftUI

struct ArticleAIActionsPanel: View {
    @Bindable var article: Article
    @Binding var uploadStatusMessage: String?

    @State private var isGeneratingOutline: Bool = false
    @State private var isGeneratingWordCount: Bool = false
    @State private var wordCountPlan: WordCountPlan? = nil
    @State private var outlineVM = ArticleEditorViewModel()

    var body: some View {
        Group {
            wordCountPlanSection
            generateOutlineButton
        }
    }

    // MARK: - Word Count Plan

    @ViewBuilder
    private var wordCountPlanSection: some View {
        if #available(macOS 26, *), AppleIntelligenceService.isAvailable {
            VStack(alignment: .leading, spacing: WVSpace.xs) {
                HStack {
                    Text("Word Count Plan")
                        .font(.wvActionLabel)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        generateWordCountPlan()
                    } label: {
                        if isGeneratingWordCount {
                            ProgressView().controlSize(.mini).scaleEffect(0.7)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.wvNano)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(isGeneratingWordCount)
                    .help("Estimate words per section using Apple Intelligence")
                }

                if let plan = wordCountPlan {
                    wordCountPlanDetails(plan)
                } else if !isGeneratingWordCount {
                    Text("Tap ✦ to estimate.")
                        .font(.wvNano)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func wordCountPlanDetails(_ plan: WordCountPlan) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(plan.sections, id: \.heading) { section in
                HStack {
                    Text(section.heading)
                        .font(.wvNano)
                        .lineLimit(1)
                    Spacer()
                    Text("~\(section.estimatedWords)")
                        .font(.wvNano)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            Divider()
            HStack {
                Text("Total estimate")
                    .font(.wvLabel)
                Spacer()
                Text("~\(plan.totalEstimate)")
                    .font(.wvLabel)
                    .monospacedDigit()
            }
        }
        .padding(WVSpace.sm)
        .background(
            RoundedRectangle(cornerRadius: WVRadius.card)
                .fill(Color.secondary.opacity(0.06))
        )
    }

    // MARK: - Generate Outline

    @ViewBuilder
    private var generateOutlineButton: some View {
        if #available(macOS 26, *), AppleIntelligenceService.isAvailable {
            Button {
                generateOutline()
            } label: {
                if isGeneratingOutline {
                    Label("Generating…", systemImage: "sparkles")
                        .font(.wvActionLabel)
                } else {
                    Label("Generate Outline", systemImage: "list.bullet.rectangle")
                        .font(.wvActionLabel)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isGeneratingOutline || article.title.isEmpty)
            .help("Use Apple Intelligence to generate a structured outline from your article metadata")
        }
    }

    // MARK: - Actions

    private func generateOutline() {
        guard #available(macOS 26, *), AppleIntelligenceService.isAvailable else { return }
        isGeneratingOutline = true
        uploadStatusMessage = nil
        Task { @MainActor in
            do {
                let outline = try await AppleIntelligenceService.generateOutline(
                    title: article.title,
                    topic: article.topic.isEmpty ? article.title : article.topic,
                    audience: article.audience.isEmpty ? "General" : article.audience,
                    targetLength: article.targetLength.rawValue
                )
                outlineVM.insertOutlineBlocks(outline, into: article)
                uploadStatusMessage = "Outline inserted into the editor (\(outline.sections.count) sections)."
            } catch {
                uploadStatusMessage = "Could not generate outline: \(error.localizedDescription)"
            }
            isGeneratingOutline = false
        }
    }

    private func generateWordCountPlan() {
        guard #available(macOS 26, *), AppleIntelligenceService.isAvailable else { return }
        isGeneratingWordCount = true
        Task { @MainActor in
            do {
                wordCountPlan = try await AppleIntelligenceService.generateWordCountPlan(
                    title: article.title,
                    outline: article.outline.isEmpty ? "No outline provided." : article.outline,
                    targetLength: article.targetLength.rawValue
                )
            } catch {
                // Silently discard — non-critical UI enhancement
            }
            isGeneratingWordCount = false
        }
    }
}
