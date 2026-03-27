import SwiftUI

struct ArticleContextTab: View {
    @Bindable var article: Article

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WVSpace.xxl) {
                VStack(alignment: .leading, spacing: WVSpace.xs) {
                    Text("Context")
                        .font(.wvTitle)
                    Text("Shape the direction of your article.")
                        .font(.wvFootnote)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: WVSpace.sm) {
                    Text("Premise")
                        .font(.wvActionLabel)
                    Text("Your argument in one or two sentences.")
                        .font(.wvFootnote)
                        .foregroundStyle(.tertiary)
                    contextField(
                        text: $article.summary,
                        placeholder: "What must the reader leave believing?",
                        minHeight: 100
                    )
                }

                VStack(alignment: .leading, spacing: WVSpace.sm) {
                    Text("Audience")
                        .font(.wvActionLabel)
                    Text("Who are you writing for, and what do they already know?")
                        .font(.wvFootnote)
                        .foregroundStyle(.tertiary)
                    contextField(
                        text: $article.audience,
                        placeholder: "Describe your target reader…",
                        minHeight: 80
                    )
                }

                VStack(alignment: .leading, spacing: WVSpace.sm) {
                    Text("Outline")
                        .font(.wvActionLabel)
                    Text("Sections, scenes, arguments — rough order only.")
                        .font(.wvFootnote)
                        .foregroundStyle(.tertiary)
                    contextField(
                        text: $article.outline,
                        placeholder: "Sketch the structure of your piece…",
                        minHeight: 140
                    )
                }
            }
            .padding(.top, WVSpace.xxl)
            .padding(.horizontal, WVSpace.xxl)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func contextField(
        text: Binding<String>,
        placeholder: String,
        minHeight: CGFloat
    ) -> some View {
        ZStack(alignment: .topLeading) {
            if text.wrappedValue.isEmpty {
                Text(placeholder)
                    .font(.wvBody)
                    .foregroundStyle(.tertiary)
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
        .padding(WVSpace.md)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: WVRadius.card))
    }
}
