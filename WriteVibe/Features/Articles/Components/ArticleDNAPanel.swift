//
//  ArticleDNAPanel.swift
//  WriteVibe
//

import SwiftUI

struct ArticleDNAPanel: View {
    @Bindable var article: Article
    @Binding var uploadStatusMessage: String?
    let onImportDocument: () -> Void

    private var targetWordCeiling: Int {
        switch article.targetLength {
        case .brief: return 300
        case .short: return 500
        case .medium: return 1_000
        case .long: return 2_000
        case .deepDive: return 5_000
        }
    }

    private var statusColor: Color {
        switch article.publishStatus {
        case .draft: return .secondary
        case .inProgress: return .orange
        case .done: return .green
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WVSpace.lg) {
            Text("Article DNA")
                .wvSectionLabel()

            titleSection
            descriptionText
            Divider()
            tonePicker
            targetLengthGrid
            publishStatusPicker
            wordProgressSection

            ArticleAIActionsPanel(
                article: article,
                uploadStatusMessage: $uploadStatusMessage
            )

            uploadStatusText

            Spacer(minLength: 0)

            Button(action: onImportDocument) {
                Label("Upload Document", systemImage: "doc.badge.plus")
                    .font(.wvActionLabel)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(WVSpace.lg)
        .frame(width: 252, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(.background.opacity(0.6))
    }

    // MARK: - Subviews

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: WVSpace.xs) {
            TextField("Title", text: $article.title)
                .textFieldStyle(.plain)
                .font(.wvHeroTitle)
                .onChange(of: article.title) { _, _ in
                    article.updatedAt = Date()
                }

            TextField("Subtitle", text: $article.subtitle)
                .textFieldStyle(.plain)
                .font(.wvBody)
                .foregroundStyle(.secondary)
                .onChange(of: article.subtitle) { _, _ in
                    article.updatedAt = Date()
                }
        }
    }

    private var descriptionText: some View {
        Text("Set the voice, scope, and publishing intent before you draft.")
            .font(.wvFootnote)
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var tonePicker: some View {
        VStack(alignment: .leading, spacing: WVSpace.xs) {
            Text("Tone")
                .font(.wvActionLabel)
                .foregroundStyle(.secondary)
            Picker("Tone", selection: $article.tone) {
                ForEach(ArticleTone.allCases, id: \.self) { tone in
                    Label(tone.rawValue, systemImage: tone.icon)
                        .tag(tone)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .onChange(of: article.tone) { _, _ in
                article.updatedAt = Date()
            }
        }
    }

    private var targetLengthGrid: some View {
        VStack(alignment: .leading, spacing: WVSpace.sm) {
            Text("Target Length")
                .font(.wvActionLabel)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 98, maximum: 110), spacing: WVSpace.xs)], spacing: WVSpace.xs) {
                ForEach(ArticleLength.allCases, id: \.self) { len in
                    WorkspaceLengthChip(
                        label: len.rawValue,
                        sub: len.wordTarget,
                        isActive: article.targetLength == len
                    ) {
                        article.targetLength = len
                        article.updatedAt = Date()
                    }
                }
            }
        }
    }

    private var publishStatusPicker: some View {
        VStack(alignment: .leading, spacing: WVSpace.xs) {
            Text("Publish Status")
                .font(.wvActionLabel)
                .foregroundStyle(.secondary)

            Picker("Status", selection: $article.publishStatus) {
                ForEach(PublishStatus.allCases, id: \.self) { status in
                    Label(status.rawValue, systemImage: status.icon)
                        .tag(status)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .tint(statusColor)
            .foregroundStyle(statusColor)
            .onChange(of: article.publishStatus) { _, _ in
                article.updatedAt = Date()
            }
        }
    }

    private var wordProgressSection: some View {
        VStack(alignment: .leading, spacing: WVSpace.xs) {
            Text("Word Progress")
                .font(.wvActionLabel)
                .foregroundStyle(.secondary)

            ProgressView(value: Double(article.wordCount), total: Double(targetWordCeiling))
                .tint(.accentColor)

            Text("\(article.wordCount) / \(targetWordCeiling) words")
                .font(.wvFootnote)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private var uploadStatusText: some View {
        if let uploadStatusMessage {
            Text(uploadStatusMessage)
                .font(.wvFootnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, WVSpace.xs)
        }
    }
}
