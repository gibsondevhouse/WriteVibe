//
//  SourceLinksView.swift
//  WriteVibe
//

import SwiftUI

struct SourceLinksView: View {
    @Bindable var article: Article
    @State private var newLinkText: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WVSpace.lg) {
                VStack(alignment: .leading, spacing: WVSpace.xs) {
                    Text("Links")
                        .font(.wvHeadline)
                    Text("Web references and reading material.")
                        .font(.wvNano)
                        .foregroundStyle(.secondary)
                }

                linkInput

                if linkEntries.isEmpty {
                    emptyShelf
                } else {
                    VStack(spacing: WVSpace.xs) {
                        ForEach(Array(linkEntries.enumerated()), id: \.offset) { index, link in
                            linkRow(link, index: index)
                        }
                    }
                }
            }
            .padding(.top, WVSpace.lg)
            .padding(.horizontal, WVSpace.xxl)
            .padding(.bottom, 48)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Link Input

    private var linkInput: some View {
        HStack(spacing: WVSpace.sm) {
            TextField("Paste a URL…", text: $newLinkText)
                .font(.wvBody)
                .textFieldStyle(.plain)
                .padding(.horizontal, WVSpace.sm)
                .padding(.vertical, WVSpace.sm)
                .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: WVRadius.chipLg))
                .onSubmit { addLink() }

            Button(action: addLink) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(newLinkText.isEmpty ? Color.secondary.opacity(0.3) : Color.accentColor)
            }
            .buttonStyle(.plain)
            .disabled(newLinkText.trimmed.isEmpty)
        }
    }

    // MARK: - Link Row

    private func linkRow(_ link: String, index: Int) -> some View {
        HStack(spacing: WVSpace.sm) {
            Image(systemName: "link")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Text(link)
                .font(.wvBody)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            Button {
                removeLink(at: index)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.quaternary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, WVSpace.md)
        .padding(.vertical, WVSpace.sm)
        .background(Color.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: WVRadius.chipLg))
    }

    // MARK: - Empty State

    private var emptyShelf: some View {
        VStack(spacing: WVSpace.sm) {
            Image(systemName: "link.badge.plus")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.quaternary)
            Text("No links added yet.")
                .font(.wvBody)
                .foregroundStyle(.secondary)
            Text("Add URLs to articles, research, or references you want to keep close.")
                .font(.wvNano)
                .foregroundStyle(.quaternary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Helpers

    private var linkEntries: [String] {
        article.sourceLinks
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private func addLink() {
        let trimmed = newLinkText.trimmed
        guard !trimmed.isEmpty else { return }
        let separator = article.sourceLinks.isEmpty ? "" : "\n"
        article.sourceLinks += separator + trimmed
        article.updatedAt = Date()
        newLinkText = ""
    }

    private func removeLink(at index: Int) {
        var links = linkEntries
        guard links.indices.contains(index) else { return }
        links.remove(at: index)
        article.sourceLinks = links.joined(separator: "\n")
        article.updatedAt = Date()
    }
}
