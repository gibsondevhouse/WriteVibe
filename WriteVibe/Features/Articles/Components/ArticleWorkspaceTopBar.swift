//
//  ArticleWorkspaceTopBar.swift
//  WriteVibe
//

import SwiftUI

struct ArticleWorkspaceTopBar: View {
    let article: Article
    let onBack: () -> Void
    let onImport: () -> Void
    let onSnapshot: () -> Void
    let onOpenEditor: () -> Void

    private var statusColor: Color {
        switch article.publishStatus {
        case .draft:
            return .secondary
        case .inProgress:
            return .orange
        case .done:
            return .green
        }
    }

    var body: some View {
        HStack(spacing: WVSpace.md) {
            Button(action: onBack) {
                HStack(spacing: WVSpace.xs) {
                    Image(systemName: "chevron.left")
                        .font(.wvLabel)
                    Text("Articles")
                        .font(.wvActionLabel)
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Divider().frame(height: 16)

            HStack(spacing: WVSpace.xs) {
                Image(systemName: article.publishStatus.icon)
                    .font(.wvLabel)
                    .foregroundStyle(statusColor)
                Text(article.publishStatus.rawValue)
                    .font(.wvLabel)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, WVSpace.sm)
            .padding(.vertical, WVSpace.xs)
            .background(Color.secondary.opacity(0.08), in: Capsule())

            Spacer()

            Text(article.updatedAt, style: .relative)
                .font(.wvFootnote)
                .foregroundStyle(.quaternary)

            Button(action: onImport) {
                Label("Import", systemImage: "doc.badge.plus")
                    .font(.wvActionLabel)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button(action: onSnapshot) {
                Label("Snapshot", systemImage: "camera")
                    .font(.wvActionLabel)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button(action: onOpenEditor) {
                Label("Open Editor", systemImage: "square.and.pencil")
                    .font(.wvActionLabel)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(.horizontal, WVSpace.xl)
        .padding(.vertical, WVSpace.sm)
    }
}
