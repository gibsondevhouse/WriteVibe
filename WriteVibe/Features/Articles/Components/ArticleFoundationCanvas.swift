//
//  ArticleFoundationCanvas.swift
//  WriteVibe
//

import SwiftUI

struct ArticleFoundationCanvas: View {
    @Bindable var article: Article

    private let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 520), spacing: 18)
    ]

    private var sortedDrafts: [ArticleDraft] {
        article.drafts.sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: WVSpace.xxl) {
            studioHero

            LazyVGrid(columns: columns, spacing: WVSpace.lg) {
                textCard(
                    title: "Premise",
                    subtitle: "Your argument in one or two sentences. What must the reader leave believing?",
                    text: $article.summary,
                    placeholder: "What is the one thing this piece must make the reader believe or understand?"
                )

                textCard(
                    title: "Audience",
                    subtitle: "Who are you writing for, and what do they already know?",
                    text: $article.audience,
                    placeholder: "e.g. General readers curious about American history. No prior knowledge assumed."
                )

                textCard(
                    title: "Outline",
                    subtitle: "The skeleton. Sections, scenes, arguments - rough order only.",
                    text: $article.outline,
                    placeholder: "Hook:\n\nMain argument:\n\nKey supporting points:\n  -\n  -\n  -\n\nCounterpoint or complication:\n\nConclusion:"
                )

                textCard(
                    title: "Research & Sources",
                    subtitle: "Quotes, links, facts, and raw material to draw from.",
                    text: $article.quickNotes,
                    placeholder: "Drop in quotes, citations, URLs, interview notes, and key facts - anything you'll want to reference while writing."
                )
            }

            draftsStrip
        }
        .padding(WVSpace.xxl)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    // MARK: - Studio Hero

    private var studioHero: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(Color.accentColor.opacity(0.45))
                .frame(width: 3)
                .clipShape(.rect(topLeadingRadius: WVRadius.panel, bottomLeadingRadius: WVRadius.panel))

            VStack(alignment: .leading, spacing: WVSpace.sm) {
                HStack(alignment: .firstTextBaseline, spacing: WVSpace.sm) {
                    Text("Writing Studio")
                        .font(.wvHeroTitle)
                    Spacer()
                    HStack(spacing: WVSpace.xs) {
                        WorkspacePill(icon: "lightbulb", text: "Premise")
                        WorkspacePill(icon: "person.2", text: "Audience")
                        WorkspacePill(icon: "list.bullet.rectangle", text: "Outline")
                        WorkspacePill(icon: "books.vertical", text: "Sources")
                    }
                }
                Text("Build your piece from premise to sources, then capture snapshots as you refine each draft.")
                    .font(.wvBody)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(WVSpace.lg)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .wvPanelCard()
    }

    // MARK: - Drafts Strip

    private var draftsStrip: some View {
        VStack(alignment: .leading, spacing: WVSpace.sm) {
            HStack(spacing: WVSpace.sm) {
                Text("Draft History")
                    .font(.wvActionLabel)
                WorkspacePill(icon: "doc.plaintext", text: "\(article.drafts.count) drafts")
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: WVSpace.sm) {
                    if sortedDrafts.isEmpty {
                        Text("No snapshots yet. Save one from the toolbar.")
                            .font(.wvBody)
                            .foregroundStyle(.tertiary)
                    } else {
                        ForEach(sortedDrafts) { draft in
                            VStack(alignment: .leading, spacing: WVSpace.xs) {
                                Text(draft.title)
                                    .font(.wvSubhead)
                                Text("\(draft.wordCount) words")
                                    .font(.wvFootnote)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            .padding(.horizontal, WVSpace.md)
                            .padding(.vertical, WVSpace.sm)
                            .wvCard()
                        }
                    }
                }
                .padding(.vertical, WVSpace.xs)
            }
        }
    }

    // MARK: - Text Card

    private func textCard(
        title: String,
        subtitle: String,
        text: Binding<String>,
        placeholder: String
    ) -> some View {
        WorkspaceCard(title: title, subtitle: subtitle) {
            ZStack(alignment: .topLeading) {
                if text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(placeholder)
                        .font(.wvBody)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }

                TextEditor(text: text)
                    .font(.wvBody)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 156)
                    .padding(.horizontal, -4)
                    .padding(.vertical, -6)
                    .onChange(of: text.wrappedValue) { _, _ in
                        article.updatedAt = Date()
                    }
            }
        }
        .frame(height: 260)
    }
}
