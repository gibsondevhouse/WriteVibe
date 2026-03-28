import SwiftUI

// MARK: - SourceType

enum SourceType: String, CaseIterable {
    case documents = "Documents"
    case links     = "Links"
    case notes     = "Notes"

    var icon: String {
        switch self {
        case .documents: return "doc.text"
        case .links:     return "link"
        case .notes:     return "note.text"
        }
    }
}

// MARK: - ArticleSourcesTab

struct ArticleSourcesTab: View {
    @Bindable var article: Article
    let onImport: () -> Void

    @State private var sourceType: SourceType = .notes

    var body: some View {
        VStack(spacing: 0) {
            sourceHeader
            Divider()
            sourceContent
        }
    }

    // MARK: - Header

    private var sourceHeader: some View {
        HStack(spacing: 0) {
            ForEach(SourceType.allCases, id: \.self) { type in
                Button {
                    sourceType = type
                } label: {
                    HStack(spacing: WVSpace.xs) {
                        Image(systemName: type.icon)
                            .font(.system(size: 10))
                        Text(type.rawValue)
                            .font(.wvLabel)
                    }
                    .foregroundStyle(sourceType == type ? .primary : .tertiary)
                    .padding(.horizontal, WVSpace.md)
                    .padding(.vertical, WVSpace.xs + 2)
                    .background(
                        sourceType == type
                            ? Color.primary.opacity(0.06)
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: WVRadius.chipLg)
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, WVSpace.xl)
        .padding(.vertical, WVSpace.sm)
    }

    // MARK: - Content

    @ViewBuilder
    private var sourceContent: some View {
        switch sourceType {
        case .documents: documentsView
        case .links:     SourceLinksView(article: article)
        case .notes:     notesView
        }
    }

    // MARK: - Documents

    private var documentsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WVSpace.lg) {
                sectionHeader(
                    title: "Documents",
                    subtitle: "Imported files and reference documents."
                )

                Button(action: onImport) {
                    Label("Import Document", systemImage: "doc.badge.plus")
                        .font(.wvActionLabel)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                emptyShelf(
                    icon: "tray",
                    message: "No documents imported yet.",
                    hint: "Import PDFs, text files, or markdown to build your reference shelf."
                )
            }
            .padding(.top, WVSpace.lg)
            .padding(.horizontal, WVSpace.xxl)
            .padding(.bottom, 48)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Notes

    private var notesView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WVSpace.lg) {
                sectionHeader(
                    title: "Notes",
                    subtitle: "Quotes, excerpts, interview notes, and research fragments."
                )

                ZStack(alignment: .topLeading) {
                    if article.quickNotes.isEmpty {
                        Text("Paste research, quotes, interview notes, raw excerpts…")
                            .font(.wvBody)
                            .foregroundStyle(.quaternary)
                            .padding(.horizontal, WVSpace.sm)
                            .padding(.vertical, WVSpace.sm)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $article.quickNotes)
                        .font(.wvBody)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 280)
                        .onChange(of: article.quickNotes) {
                            article.updatedAt = Date()
                        }
                }
                .padding(WVSpace.sm)
                .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: WVRadius.card))
            }
            .padding(.top, WVSpace.lg)
            .padding(.horizontal, WVSpace.xxl)
            .padding(.bottom, 48)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Shared Components

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: WVSpace.xs) {
            Text(title)
                .font(.wvHeadline)
            Text(subtitle)
                .font(.wvNano)
                .foregroundStyle(.secondary)
        }
    }

    private func emptyShelf(icon: String, message: String, hint: String) -> some View {
        VStack(spacing: WVSpace.sm) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.quaternary)
            Text(message)
                .font(.wvBody)
                .foregroundStyle(.secondary)
            Text(hint)
                .font(.wvNano)
                .foregroundStyle(.quaternary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

}
