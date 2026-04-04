//
//  FloatingFormatToolbar.swift
//  WriteVibe
//

import SwiftUI

struct FloatingFormatToolbar: View {
    let editorState: EditorState
    let isWorkflowRunning: Bool
    let onSummarizeSelection: () -> Void
    let onImproveSelection: () -> Void
    let onGenerateVariants: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            formatButton(icon: "bold", isActive: editorState.isBold) {
                editorState.toggleBold()
            }
            formatButton(icon: "italic", isActive: editorState.isItalic) {
                editorState.toggleItalic()
            }
            formatButton(icon: "chevron.left.forwardslash.chevron.right", isActive: false) {
                editorState.toggleInlineCode()
            }
            formatButton(icon: "link", isActive: editorState.isLink) {
                editorState.toggleLink()
            }

            Divider().frame(height: 16).padding(.horizontal, WVSpace.xs)

            Menu {
                Button("Paragraph") { editorState.setBlockType(.paragraph) }
                Button("Heading 1") { editorState.setBlockType(.heading(level: 1)) }
                Button("Heading 2") { editorState.setBlockType(.heading(level: 2)) }
                Button("Heading 3") { editorState.setBlockType(.heading(level: 3)) }
                Button("Quote")     { editorState.setBlockType(.blockquote) }
                Button("Code")      { editorState.setBlockType(.code(language: nil)) }
            } label: {
                Text(blockTypeLabel)
                    .font(.wvLabel)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Divider().frame(height: 16).padding(.horizontal, WVSpace.xs)

            Menu {
                Button("Summarize Selection", action: onSummarizeSelection)
                Button("Improve Selection", action: onImproveSelection)
                Button("Generate Variants", action: onGenerateVariants)
            } label: {
                HStack(spacing: WVSpace.xs) {
                    if isWorkflowRunning {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "sparkles.rectangle.stack")
                            .font(.system(size: 11, weight: .medium))
                    }
                    Text("Writing Tools")
                        .font(.wvLabel)
                }
            }
            .menuStyle(.borderlessButton)
            .disabled(isWorkflowRunning)
            .fixedSize()
        }
        .padding(.horizontal, WVSpace.md)
        .padding(.vertical, WVSpace.sm - 2)
        .background(
            RoundedRectangle(cornerRadius: WVRadius.chipLg)
                .fill(.ultraThickMaterial)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: WVRadius.chipLg)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func formatButton(icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isActive ? Color.accentColor : .primary)
                .frame(width: 28, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: WVSpace.xs)
                        .fill(isActive ? Color.accentColor.opacity(0.12) : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }

    private var blockTypeLabel: String {
        switch editorState.currentBlockType {
        case .paragraph:       return "¶"
        case .heading(let l):  return "H\(l)"
        case .blockquote:      return "❝"
        case .code:            return "</>"
        default:               return "¶"
        }
    }
}
