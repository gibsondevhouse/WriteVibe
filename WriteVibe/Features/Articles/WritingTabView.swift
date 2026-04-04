//
//  WritingTabView.swift
//  WriteVibe
//

import SwiftUI

enum WritingMode: String, CaseIterable {
    case draft   = "Draft"
    case outline = "Outline"
    case both    = "Both"

    var icon: String {
        switch self {
        case .draft:   return "doc.text"
        case .outline: return "list.bullet.indent"
        case .both:    return "rectangle.split.2x1"
        }
    }
}

struct WritingTabView: View {
    @Bindable var article: Article
    @State private var writingMode: WritingMode = .draft
    @State private var viewModel = ArticleEditorViewModel()

    var body: some View {
        VStack(spacing: 0) {
            modeSwitcherBar
            Divider()
            modeContent
        }
    }

    private var modeSwitcherBar: some View {
        HStack(spacing: 0) {
            ForEach(WritingMode.allCases, id: \.self) { mode in
                Button {
                    writingMode = mode
                } label: {
                    HStack(spacing: WVSpace.xs) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 10))
                        Text(mode.rawValue)
                            .font(.wvLabel)
                    }
                    .foregroundStyle(writingMode == mode ? .primary : .tertiary)
                    .padding(.horizontal, WVSpace.md)
                    .padding(.vertical, WVSpace.xs + 2)
                    .background(
                        writingMode == mode
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

    @ViewBuilder
    private var modeContent: some View {
        switch writingMode {
        case .draft:
            ArticleEditorView(article: article, viewModel: viewModel)
        case .outline:
            OutlineEditorView(article: article, viewModel: viewModel)
        case .both:
            HSplitView {
                OutlineEditorView(article: article, viewModel: viewModel)
                    .frame(minWidth: 240, idealWidth: 320, maxWidth: 400)
                ArticleEditorView(article: article, viewModel: viewModel)
            }
        }
    }
}
