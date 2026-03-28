//
//  OutlineEditorView.swift
//  WriteVibe
//

import SwiftUI

struct OutlineEditorView: View {
    @Bindable var article: Article

    var body: some View {
        VStack(alignment: .leading, spacing: WVSpace.sm) {
            header
            editor
            footerHint
        }
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, WVSpace.xxl)
        .padding(.vertical, WVSpace.lg)
        .background(.clear)
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: WVSpace.xs) {
            Text("Outline")
                .wvSectionLabel()
            Text("Plan your structure")
                .font(.wvFootnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Editor

    @ViewBuilder
    private var editor: some View {
        ZStack(alignment: .topLeading) {
            if article.outline.isEmpty {
                Text("Start with your main sections, key arguments, or scene beats…")
                    .font(.system(size: 14))
                    .foregroundStyle(.quaternary)
                    .padding(.top, 8)
                    .padding(.leading, 4)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $article.outline)
                .font(.system(size: 14))
                .scrollContentBackground(.hidden)
                .frame(maxHeight: .infinity)
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var footerHint: some View {
        Text("Use the outline to plan before drafting")
            .font(.wvNano)
            .foregroundStyle(.quaternary)
    }
}
