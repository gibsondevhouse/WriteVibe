import SwiftUI

struct ArticleContextTab: View {
    @Bindable var article: Article

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WVSpace.lg) {
                header

                HStack(alignment: .top, spacing: WVSpace.xxl) {
                    leftColumn
                    rightColumn
                }
            }
            .padding(.top, WVSpace.xxl)
            .padding(.horizontal, WVSpace.xxl)
            .padding(.bottom, 48)
            .frame(maxWidth: 960)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: WVSpace.xs) {
            Text("Context")
                .font(.wvTitle)
            Text("The strategic briefing for this piece.")
                .font(.wvFootnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Left Column (Core)

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: WVSpace.lg) {
            Text("Core")
                .wvSectionLabel()

            contextField(
                label: "Premise",
                hint: "Your argument in one or two sentences.",
                text: $article.summary,
                placeholder: "What is this piece really about?",
                minHeight: 80
            )

            contextField(
                label: "Audience",
                hint: "Who are you writing for, and what do they already know?",
                text: $article.audience,
                placeholder: "Describe your target reader…",
                minHeight: 64
            )
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .topLeading)
    }

    // MARK: - Right Column (Voice + Constraints)

    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: WVSpace.xxl) {
            voiceSection
            constraintsSection
        }
        .frame(minWidth: 0, maxWidth: .infinity, alignment: .topLeading)
    }

    // MARK: - Voice

    private var voiceSection: some View {
        VStack(alignment: .leading, spacing: WVSpace.md) {
            Text("Voice")
                .wvSectionLabel()

            VStack(alignment: .leading, spacing: WVSpace.sm) {
                Text("Tone")
                    .font(.wvActionLabel)
                toneGrid
            }

            contextField(
                label: "Style",
                hint: "Formal, casual, academic, lyrical…",
                text: $article.style,
                placeholder: "e.g. Direct and conversational, short paragraphs…",
                minHeight: 44
            )

            contextField(
                label: "Purpose",
                hint: "What is this piece trying to do?",
                text: $article.purpose,
                placeholder: "Inform, persuade, explain, reflect…",
                minHeight: 44
            )
        }
    }

    // MARK: - Tone Grid

    private var toneGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: WVSpace.xs)], spacing: WVSpace.xs) {
            ForEach(ArticleTone.allCases, id: \.self) { tone in
                Button {
                    article.tone = tone
                    article.updatedAt = Date()
                } label: {
                    HStack(spacing: WVSpace.xs) {
                        Image(systemName: tone.icon)
                            .font(.system(size: 9))
                        Text(tone.rawValue)
                            .font(.wvLabel)
                    }
                    .foregroundStyle(article.tone == tone ? Color.accentColor : .secondary)
                    .padding(.horizontal, WVSpace.sm)
                    .padding(.vertical, WVSpace.xs + 2)
                    .frame(maxWidth: .infinity)
                    .background(
                        article.tone == tone
                            ? Color.accentColor.opacity(0.1)
                            : Color.primary.opacity(0.03),
                        in: RoundedRectangle(cornerRadius: WVRadius.chipLg)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: WVRadius.chipLg)
                            .strokeBorder(
                                article.tone == tone ? Color.accentColor.opacity(0.3) : Color.clear,
                                lineWidth: 1
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Constraints

    private var constraintsSection: some View {
        VStack(alignment: .leading, spacing: WVSpace.md) {
            Text("Constraints")
                .wvSectionLabel()

            VStack(alignment: .leading, spacing: WVSpace.sm) {
                Text("Target Length")
                    .font(.wvActionLabel)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: WVSpace.xs)], spacing: WVSpace.xs) {
                    ForEach(ArticleLength.allCases, id: \.self) { length in
                        Button {
                            article.targetLength = length
                            article.updatedAt = Date()
                        } label: {
                            VStack(spacing: 1) {
                                Text(length.rawValue)
                                    .font(.wvLabel)
                                Text(length.wordTarget)
                                    .font(.wvNano)
                                    .foregroundStyle(article.targetLength == length ? Color.accentColor.opacity(0.8) : .secondary)
                            }
                            .foregroundStyle(article.targetLength == length ? Color.accentColor : .secondary)
                            .padding(.horizontal, WVSpace.xs)
                            .padding(.vertical, WVSpace.xs + 2)
                            .frame(maxWidth: .infinity)
                            .background(
                                article.targetLength == length
                                    ? Color.accentColor.opacity(0.1)
                                    : Color.primary.opacity(0.03),
                                in: RoundedRectangle(cornerRadius: WVRadius.chipLg)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: WVRadius.chipLg)
                                    .strokeBorder(
                                        article.targetLength == length ? Color.accentColor.opacity(0.3) : Color.clear,
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            contextField(
                label: "Key Takeaway",
                hint: "What should the reader leave with?",
                text: $article.keyTakeaway,
                placeholder: "The one thing the reader remembers…",
                minHeight: 44
            )

            contextField(
                label: "Publishing Intent",
                hint: "Optional — what form might this take?",
                text: $article.publishingIntent,
                placeholder: "Blog post, essay, newsletter…",
                minHeight: 36
            )
        }
    }

    // MARK: - Reusable Field

    @ViewBuilder
    private func contextField(
        label: String,
        hint: String,
        text: Binding<String>,
        placeholder: String,
        minHeight: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: WVSpace.xs) {
            Text(label)
                .font(.wvActionLabel)
            Text(hint)
                .font(.wvNano)
                .foregroundStyle(.secondary)

            ZStack(alignment: .topLeading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .font(.wvBody)
                        .foregroundStyle(.quaternary)
                        .padding(.horizontal, WVSpace.sm)
                        .padding(.vertical, WVSpace.sm)
                        .allowsHitTesting(false)
                }

                TextEditor(text: text)
                    .font(.wvBody)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: minHeight)
                    .onChange(of: text.wrappedValue) {
                        article.updatedAt = Date()
                    }
            }
            .padding(WVSpace.sm)
            .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: WVRadius.card))
        }
    }
}
