//
//  EditorState.swift
//  WriteVibe
//
//  Observable bridge between the AppKit NSTextView editor and SwiftUI.
//  Owns selection state, formatting commands, and block load/sync.
//  Never performs full-content replacement on keystroke — the NSTextView
//  is always source of truth during editing.
//

import AppKit
import SwiftUI

@MainActor
@Observable
final class EditorState {

    // MARK: - Selection State (read by FloatingFormatToolbar)

    var hasSelection = false
    var selectionScreenRect: CGRect = .zero
    var isBold = false
    var isItalic = false
    var isLink = false
    var currentBlockType: BlockType = .paragraph
    var showInsertionButton = false
    var insertionButtonYOffset: CGFloat = 0

    weak var textView: NSTextView?

    // MARK: - Load / Sync

    func loadBlocks(_ blocks: [ArticleBlock]) {
        guard let tv = textView else { return }
        let attrString = DocumentSyncEngine.blocksToAttributedString(blocks)
        tv.textStorage?.setAttributedString(attrString)
    }

    func syncToArticle(_ article: Article) {
        guard let tv = textView, let storage = tv.textStorage else { return }
        let bodyBlocks = article.bodyBlocks
        let updates = DocumentSyncEngine.attributedStringToBlocks(
            from: storage,
            existingBlocks: bodyBlocks
        )
        // Preserve the leading H1 title block, replace only body blocks
        let titleBlock = article.sortedBlocks.first { $0.blockType == .heading(level: 1) && $0.position == 0 }
        var newBlocks: [ArticleBlock] = []
        if let titleBlock { newBlocks.append(titleBlock) }
        reconcileBlocks(updates: updates, article: article, preservedBlocks: newBlocks)
    }

    // MARK: - Inline Formatting

    func toggleBold()   { toggleTrait(.boldFontMask);   isBold.toggle() }
    func toggleItalic() { toggleTrait(.italicFontMask);  isItalic.toggle() }

    func toggleInlineCode() {
        guard let tv = textView, tv.selectedRange().length > 0,
              let storage = tv.textStorage else { return }
        let range = tv.selectedRange()
        let currentFont = storage.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont
            ?? NSFont.systemFont(ofSize: 15)
        let isCode = currentFont.fontDescriptor.symbolicTraits.contains(.monoSpace)
        let newFont = isCode
            ? NSFont.systemFont(ofSize: currentFont.pointSize)
            : NSFont.monospacedSystemFont(ofSize: currentFont.pointSize, weight: .regular)
        storage.beginEditing()
        storage.addAttribute(.font, value: newFont, range: range)
        storage.endEditing()
    }

    func toggleLink() {
        guard let tv = textView, tv.selectedRange().length > 0,
              let storage = tv.textStorage else { return }
        let range = tv.selectedRange()

        if isLink {
            storage.beginEditing()
            storage.removeAttribute(.link, range: range)
            storage.addAttribute(.foregroundColor, value: NSColor.textColor, range: range)
            storage.removeAttribute(.underlineStyle, range: range)
            storage.endEditing()
            isLink = false
        } else {
            let selectedText = (storage.string as NSString).substring(with: range)
            let urlString = selectedText.hasPrefix("http") ? selectedText : "https://\(selectedText)"
            storage.beginEditing()
            storage.addAttribute(.link, value: urlString, range: range)
            storage.addAttribute(.foregroundColor, value: NSColor.linkColor, range: range)
            storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            storage.endEditing()
            isLink = true
        }
    }

    // MARK: - Block-Level Formatting

    func setBlockType(_ type: BlockType) {
        guard let tv = textView, let storage = tv.textStorage else { return }
        let paraRange = (storage.string as NSString).paragraphRange(for: tv.selectedRange())
        let (tag, meta) = blockTypeStorage(type)
        let font = DocumentSyncEngine.fontForBlockType(type)
        let pStyle = DocumentSyncEngine.paragraphStyleForBlockType(type)
        let fgColor: NSColor = type == .blockquote ? .secondaryLabelColor : .textColor

        // Apply to existing text in the paragraph
        if paraRange.length > 0 {
            storage.beginEditing()
            storage.addAttribute(.font, value: font, range: paraRange)
            storage.addAttribute(.paragraphStyle, value: pStyle, range: paraRange)
            storage.addAttribute(.wvBlockType, value: tag, range: paraRange)
            if let meta {
                storage.addAttribute(.wvBlockMeta, value: meta, range: paraRange)
            } else {
                storage.removeAttribute(.wvBlockMeta, range: paraRange)
            }
            storage.addAttribute(.foregroundColor, value: fgColor, range: paraRange)
            storage.endEditing()
        }

        // Also update typingAttributes so the next keystroke uses this style
        var typing = tv.typingAttributes
        typing[.font] = font
        typing[.paragraphStyle] = pStyle
        typing[.wvBlockType] = tag
        typing[.wvBlockMeta] = meta
        typing[.foregroundColor] = fgColor
        tv.typingAttributes = typing

        currentBlockType = type
    }

    // MARK: - Selection Update (called from Coordinator)

    func updateSelectionState(from textView: NSTextView) {
        let range = textView.selectedRange()
        hasSelection = range.length > 0

        guard let storage = textView.textStorage else {
            showInsertionButton = false
            return
        }

        if hasSelection {
            selectionScreenRect = selectionBounds(for: range, in: textView)
            showInsertionButton = false
            return
        }

        // Empty document
        if storage.length == 0 {
            isBold = false; isItalic = false; isLink = false
            currentBlockType = .paragraph
            showInsertionButton = true
            insertionButtonYOffset = caretYOffset(in: textView)
            return
        }

        let attrPos = min(range.location, storage.length - 1)
        let font = storage.attribute(.font, at: attrPos, effectiveRange: nil) as? NSFont
            ?? NSFont.systemFont(ofSize: 15)
        let fm = NSFontManager.shared
        isBold = fm.traits(of: font).contains(.boldFontMask)
        isItalic = fm.traits(of: font).contains(.italicFontMask)
        isLink = storage.attribute(.link, at: attrPos, effectiveRange: nil) != nil

        let tag = storage.attribute(.wvBlockType, at: attrPos, effectiveRange: nil) as? String
        let meta = storage.attribute(.wvBlockMeta, at: attrPos, effectiveRange: nil) as? String
        currentBlockType = DocumentSyncEngine.resolveBlockType(tag: tag, metadata: meta)

        updateInsertionButtonState(range: range, storage: storage, textView: textView)
    }

    // MARK: - Private

    private func toggleTrait(_ trait: NSFontTraitMask) {
        guard let tv = textView, tv.selectedRange().length > 0,
              let storage = tv.textStorage else { return }
        let range = tv.selectedRange()
        let current = storage.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont
            ?? NSFont.systemFont(ofSize: 15)
        let fm = NSFontManager.shared
        let newFont = fm.traits(of: current).contains(trait)
            ? fm.convert(current, toNotHaveTrait: trait)
            : fm.convert(current, toHaveTrait: trait)
        storage.beginEditing()
        storage.addAttribute(.font, value: newFont, range: range)
        storage.endEditing()
    }

    private func blockTypeStorage(_ type: BlockType) -> (String, String?) {
        switch type {
        case .paragraph:       return ("paragraph", nil)
        case .heading(let l):  return ("heading", String(l))
        case .blockquote:      return ("blockquote", nil)
        case .code(let lang):  return ("code", lang)
        case .image(let cap):  return ("image", cap)
        case .bulletList:      return ("bulletList", nil)
        case .numberedList:    return ("numberedList", nil)
        case .divider:         return ("divider", nil)
        }
    }

    private func reconcileBlocks(updates: [ArticleBlockUpdate], article: Article, preservedBlocks: [ArticleBlock] = []) {
        let existingMap = Dictionary(uniqueKeysWithValues: article.blocks.map { ($0.id, $0) })
        var newBlocks: [ArticleBlock] = preservedBlocks

        for update in updates {
            if let existingID = update.blockID, let existing = existingMap[existingID] {
                existing.content = update.content
                existing.blockType = update.blockType
                existing.position = update.position
                newBlocks.append(existing)
            } else {
                newBlocks.append(ArticleBlock(type: update.blockType, content: update.content, position: update.position))
            }
        }

        article.blocks = newBlocks
        article.updatedAt = Date()
    }
}
