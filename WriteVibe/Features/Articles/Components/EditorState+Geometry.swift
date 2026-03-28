//
//  EditorState+Geometry.swift
//  WriteVibe
//
//  Selection bounds, insertion-button positioning, and paragraph Y-offset
//  helpers extracted from EditorState to keep each file under 250 LOC.
//

import AppKit

extension EditorState {

    // MARK: - Insertion Button

    func updateInsertionButtonState(range: NSRange, storage: NSTextStorage, textView: NSTextView) {
        // Cursor at end after trailing newline → new empty paragraph
        if range.location >= storage.length {
            let lastChar = (storage.string as NSString).character(at: storage.length - 1)
            showInsertionButton = (lastChar == 0x0A)
            if showInsertionButton {
                insertionButtonYOffset = paragraphYOffset(for: range.location, in: textView)
            }
            return
        }
        let paraRange = (storage.string as NSString).paragraphRange(for: NSRange(location: range.location, length: 0))
        let paraText = (storage.string as NSString).substring(with: paraRange)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        showInsertionButton = paraText.isEmpty
        if showInsertionButton {
            insertionButtonYOffset = paragraphYOffset(for: range.location, in: textView)
        }
    }

    // MARK: - Paragraph Y Offset

    func paragraphYOffset(for charIndex: Int, in textView: NSTextView) -> CGFloat {
        let insetY = textView.textContainerInset.height
        let length = textView.textStorage?.length ?? 0

        // TextKit 2
        if let tlm = textView.textLayoutManager,
           let cs = tlm.textContentManager as? NSTextContentStorage {
            if charIndex >= length {
                if let frag = tlm.textLayoutFragment(for: cs.documentRange.endLocation) {
                    return frag.layoutFragmentFrame.maxY + insetY
                }
                // Fallback: use extraLineFragmentRect via TK1 if available
            } else if let loc = cs.location(cs.documentRange.location, offsetBy: charIndex),
                      let frag = tlm.textLayoutFragment(for: loc) {
                return frag.layoutFragmentFrame.origin.y + insetY
            }
        }

        // TextKit 1 fallback
        if let lm = textView.layoutManager, let container = textView.textContainer {
            if charIndex >= length {
                let rect = lm.extraLineFragmentRect
                return (rect != .zero ? rect.origin.y : lm.usedRect(for: container).maxY) + insetY
            }
            let glyph = lm.glyphIndexForCharacter(at: charIndex)
            return lm.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil).origin.y + insetY
        }

        return insetY
    }

    // MARK: - Selection Bounds

    func selectionBounds(for range: NSRange, in textView: NSTextView) -> CGRect {
        // TextKit 2 path
        if let tlm = textView.textLayoutManager,
           let contentStorage = tlm.textContentManager as? NSTextContentStorage {
            let docStart = contentStorage.documentRange.location
            if let selStart = contentStorage.location(docStart, offsetBy: range.location),
               let selEnd = contentStorage.location(selStart, offsetBy: range.length),
               let selRange = NSTextRange(location: selStart, end: selEnd) {
                var unionRect = CGRect.null
                tlm.enumerateTextSegments(in: selRange, type: .selection) { _, rect, _, _ in
                    unionRect = unionRect.union(rect)
                    return true
                }
                if !unionRect.isNull {
                    return textView.convert(unionRect, to: nil)
                }
            }
        }
        // Fallback: first rect for character range
        guard let lm = textView.layoutManager, let container = textView.textContainer else {
            return .zero
        }
        let glyphRange = lm.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
        let rect = lm.boundingRect(forGlyphRange: glyphRange, in: container)
        return textView.convert(rect, to: nil)
    }
}
