//
//  NewSeriesSheet.swift
//  WriteVibe
//

import SwiftData
import SwiftUI

struct NewSeriesSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    @Binding var isPresented: Bool
    var onCreate: (Article) -> Void

    @State private var seriesName = ""
    @State private var seriesDescription = ""
    @State private var articleTitle = ""
    @State private var topic = ""
    @State private var tone: ArticleTone = .conversational
    @State private var length: ArticleLength = .medium

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                seriesIdentitySection
                firstArticleSection
                actions
            }
            .padding(28)
        }
        .frame(width: 480, height: 640)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
            Text("New Series")
                .font(.title3.weight(.semibold))
        }
        .padding(.bottom, 22)
    }

    // MARK: - Series Identity

    private var seriesIdentitySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Series")

            fieldBlock("Series Name") {
                TextField("e.g. Swift Deep Dives", text: $seriesName)
                    .textFieldStyle(.roundedBorder)
            }

            fieldBlock("Description") {
                TextField("What is this series about? (optional)", text: $seriesDescription)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.bottom, 20)
        }
    }

    // MARK: - First Article

    private var firstArticleSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("First Article")

            fieldBlock("Title") {
                TextField("Article title…", text: $articleTitle)
                    .textFieldStyle(.roundedBorder)
            }

            fieldBlock("Topic / Subject") {
                TextField("What does this article cover?", text: $topic)
                    .textFieldStyle(.roundedBorder)
            }

            fieldBlock("Tone") {
                Picker("Tone", selection: $tone) {
                    ForEach(ArticleTone.allCases, id: \.self) { t in
                        Label(t.rawValue, systemImage: t.icon).tag(t)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            fieldBlock("Target Length") {
                HStack(spacing: 8) {
                    ForEach(ArticleLength.allCases, id: \.self) { len in
                        LengthChip(
                            label: len.rawValue,
                            sub: len.wordTarget,
                            isActive: length == len
                        ) {
                            length = len
                        }
                    }
                }
            }
            .padding(.bottom, 28)
        }
    }

    // MARK: - Actions

    private var actions: some View {
        HStack {
            Button("Cancel") { isPresented = false }
                .keyboardShortcut(.cancelAction)
            Spacer()
            Button("Create Series") { createSeriesFirstArticle() }
                .buttonStyle(.borderedProminent)
                .disabled(
                    seriesName.trimmingCharacters(in: .whitespaces).isEmpty ||
                    articleTitle.trimmingCharacters(in: .whitespaces).isEmpty
                )
                .keyboardShortcut(.defaultAction)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .wvSectionLabel()
            .padding(.bottom, 8)
    }

    @ViewBuilder
    private func fieldBlock<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.callout.weight(.medium))
            content()
        }
        .padding(.bottom, 14)
    }

    private func createSeriesFirstArticle() {
        let seriesTitle = seriesName.trimmingCharacters(in: .whitespaces)
        let title = articleTitle.trimmingCharacters(in: .whitespaces)
        guard !seriesTitle.isEmpty, !title.isEmpty else { return }

        let normalizedDescription = seriesDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let series = Series(
            title: seriesTitle,
            seriesDescription: normalizedDescription.isEmpty ? nil : normalizedDescription
        )
        modelContext.insert(series)

        let request = ArticleCreationRequest(
            title: title,
            subtitle: "",
            topic: topic.trimmingCharacters(in: .whitespaces),
            tone: tone,
            targetLength: length,
            series: series
        )
        guard let article = try? appState.services.articleCreationService.createArticle(request, context: modelContext) else {
            return
        }

        isPresented = false
        onCreate(article)
    }
}