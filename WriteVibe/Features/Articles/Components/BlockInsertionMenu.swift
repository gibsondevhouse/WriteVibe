//
//  BlockInsertionMenu.swift
//  WriteVibe
//

import SwiftUI

struct BlockInsertionMenu: View {
    let editorState: EditorState

    var body: some View {
        Menu {
            Section("Text") {
                blockItem(icon: "text.alignleft", label: "Paragraph", type: .paragraph)
                blockItem(icon: "h.square", label: "Heading 1", type: .heading(level: 1))
                blockItem(icon: "h.square", label: "Heading 2", type: .heading(level: 2))
                blockItem(icon: "h.square", label: "Heading 3", type: .heading(level: 3))
            }
            Section("Rich") {
                blockItem(icon: "quote.opening", label: "Block Quote", type: .blockquote)
                blockItem(icon: "chevron.left.forwardslash.chevron.right", label: "Code Block", type: .code(language: nil))
            }
            Section("Structure") {
                blockItem(icon: "list.bullet", label: "Bullet List", type: .bulletList)
                blockItem(icon: "list.number", label: "Numbered List", type: .numberedList)
                blockItem(icon: "minus", label: "Divider", type: .divider)
            }
        } label: {
            Image(systemName: "plus.circle")
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(.tertiary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func blockItem(icon: String, label: String, type: BlockType) -> some View {
        Button {
            editorState.setBlockType(type)
        } label: {
            Label(label, systemImage: icon)
        }
    }
}
