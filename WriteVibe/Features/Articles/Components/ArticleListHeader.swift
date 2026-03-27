//
//  ArticleListHeader.swift
//  WriteVibe
//

import SwiftUI

// MARK: - ArticleListHeader

struct ArticleListHeader: View {
    @Binding var filterStatus: PublishStatus?
    @Binding var searchText: String
    var onNewArticle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: WVSpace.md) {
            titleRow
            searchField
            filterChips
        }
        .padding(.horizontal, WVSpace.xxl)
        .padding(.top, WVSpace.xxl)
        .padding(.bottom, WVSpace.lg)
    }

    // MARK: - Title Row

    private var titleRow: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: WVSpace.xs) {
                Text("Articles")
                    .font(.wvTitle)
                Text("Your writing library")
                    .font(.wvFootnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onNewArticle) {
                Label("New Article", systemImage: "plus")
                    .font(.wvActionLabel)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
    }

    // MARK: - Search Field

    private var searchField: some View {
        HStack(spacing: WVSpace.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            TextField("Search articles…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.wvBody)
        }
        .padding(.horizontal, WVSpace.md)
        .padding(.vertical, WVSpace.sm)
        .background(
            Capsule()
                .fill(Color.primary.opacity(0.05))
        )
        .overlay(
            Capsule()
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Filter Chips

    private var filterChips: some View {
        HStack(spacing: 6) {
            FilterChip(label: "All", isActive: filterStatus == nil) {
                filterStatus = nil
            }
            ForEach(PublishStatus.allCases, id: \.self) { status in
                FilterChip(label: status.rawValue, isActive: filterStatus == status) {
                    filterStatus = filterStatus == status ? nil : status
                }
            }
            Spacer()
        }
    }
}
