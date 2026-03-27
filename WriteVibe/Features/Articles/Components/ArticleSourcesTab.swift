import SwiftUI

struct ArticleSourcesTab: View {
    @Bindable var article: Article
    let onImport: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WVSpace.lg) {
                VStack(alignment: .leading, spacing: WVSpace.xs) {
                    Text("Sources")
                        .font(.wvTitle)
                    Text("Collect research, quotes, and reference material.")
                        .font(.wvFootnote)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: WVSpace.sm) {
                    Text("Research & Notes")
                        .font(.wvActionLabel)
                    Text("Drop in quotes, facts, URLs, and anything you'll reference while writing.")
                        .font(.wvFootnote)
                        .foregroundStyle(.tertiary)

                    ZStack(alignment: .topLeading) {
                        if article.quickNotes.isEmpty {
                            Text("Paste research, quotes, links, interview notes…")
                                .font(.wvBody)
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, WVSpace.sm)
                                .padding(.vertical, WVSpace.sm)
                                .allowsHitTesting(false)
                        }

                        TextEditor(text: $article.quickNotes)
                            .font(.wvBody)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 300)
                            .onChange(of: article.quickNotes) {
                                article.updatedAt = Date()
                            }
                    }
                    .padding(WVSpace.md)
                    .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: WVRadius.card))
                }

                Button(action: onImport) {
                    Label("Import Document", systemImage: "doc.badge.plus")
                        .font(.wvActionLabel)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.top, WVSpace.xxl)
            .padding(.horizontal, WVSpace.xxl)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
    }
}
