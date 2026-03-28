//
//  EditorTextView.swift
//  WriteVibe
//
//  NSViewRepresentable wrapping a self-sizing NSTextView for the article body.
//  Uses the system-default TextKit stack (TextKit 2 on macOS 14+).
//  The BodyTextView subclass overrides intrinsicContentSize so SwiftUI
//  can measure height. No enclosing NSScrollView — the parent SwiftUI
//  ScrollView handles scrolling.
//

import AppKit
import SwiftUI

// MARK: - BodyTextView (self-sizing subclass)

final class BodyTextView: NSTextView {

    private lazy var placeholderLayer: CATextLayer = {
        let layer = CATextLayer()
        layer.string = "Start writing…"
        layer.font = NSFont.systemFont(ofSize: 15, weight: .regular)
        layer.fontSize = 15
        layer.foregroundColor = NSColor.placeholderTextColor.cgColor
        layer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        layer.isWrapped = true
        return layer
    }()

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        setupPlaceholder()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupPlaceholder()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func setupPlaceholder() {
        wantsLayer = true
        layer?.addSublayer(placeholderLayer)
    }

    override func layout() {
        super.layout()
        let inset = textContainerInset
        let containerInset = textContainer?.lineFragmentPadding ?? 0
        placeholderLayer.frame = CGRect(
            x: inset.width + containerInset,
            y: inset.height,
            width: bounds.width - (inset.width + containerInset) * 2,
            height: 22
        )
    }

    func updatePlaceholderVisibility() {
        let isEmpty = (textStorage?.length ?? 0) == 0
        placeholderLayer.isHidden = !isEmpty
    }

    override func didChangeText() {
        super.didChangeText()
        invalidateIntrinsicContentSize()
        updatePlaceholderVisibility()
    }

    override var intrinsicContentSize: NSSize {
        guard let container = textContainer else { return super.intrinsicContentSize }

        // TextKit 2
        if let tlm = textLayoutManager {
            tlm.ensureLayout(for: tlm.documentRange)
            let bounds = tlm.usageBoundsForTextContainer
            let height = ceil(bounds.height + bounds.origin.y) + textContainerInset.height * 2
            return NSSize(width: NSView.noIntrinsicMetric, height: max(height, 100))
        }

        // TextKit 1 fallback
        if let lm = layoutManager {
            lm.ensureLayout(for: container)
            let height = ceil(lm.usedRect(for: container).height) + textContainerInset.height * 2
            return NSSize(width: NSView.noIntrinsicMetric, height: max(height, 100))
        }

        return super.intrinsicContentSize
    }
}

// MARK: - EditorTextView

struct EditorTextView: NSViewRepresentable {
    let editorState: EditorState
    let initialBlocks: [ArticleBlock]

    func makeNSView(context: Context) -> BodyTextView {
        // System-default init creates a properly wired TextKit 2 stack on macOS 14+.
        // This guarantees textStorage is connected.
        let textView = BodyTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 200))
        textView.isRichText = true
        textView.allowsUndo = true
        textView.isEditable = true
        textView.isSelectable = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                  height: CGFloat.greatestFiniteMagnitude)
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.usesAdaptiveColorMappingForDarkAppearance = true
        textView.font = NSFont.systemFont(ofSize: 15)
        textView.textColor = .textColor
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false

        textView.typingAttributes = DocumentSyncEngine.defaultTypingAttributes()

        // Load initial block content into the text storage
        let attrString = DocumentSyncEngine.blocksToAttributedString(initialBlocks)
        if attrString.length > 0 {
            textView.textStorage?.setAttributedString(attrString)
        }

        textView.delegate = context.coordinator
        context.coordinator.textView = textView
        editorState.textView = textView

        // Force initial layout so intrinsicContentSize is accurate
        textView.invalidateIntrinsicContentSize()
        textView.updatePlaceholderVisibility()

        // Trigger initial insertion-button state
        editorState.updateSelectionState(from: textView)
        return textView
    }

    func updateNSView(_ textView: BodyTextView, context: Context) {
        // NSTextView owns content during editing. External reloads use EditorState.loadBlocks().
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(editorState: editorState)
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, NSTextViewDelegate {
        let editorState: EditorState
        weak var textView: BodyTextView?

        init(editorState: EditorState) {
            self.editorState = editorState
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            Task { @MainActor in
                self.editorState.updateSelectionState(from: tv)
            }
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            Task { @MainActor in
                self.editorState.updateSelectionState(from: tv)
            }
        }

        func textView(_ textView: NSTextView, doCommandBy sel: Selector) -> Bool {
            if sel == #selector(NSResponder.insertNewline(_:)) {
                // Shift+Return → soft line break, plain Return → new paragraph
                let isShift = NSApp.currentEvent?.modifierFlags.contains(.shift) == true
                if isShift {
                    handleSoftLineBreak(textView)
                } else {
                    handleReturn(textView)
                }
                return true
            }
            if sel == #selector(NSResponder.insertLineBreak(_:)) {
                handleSoftLineBreak(textView)
                return true
            }
            return false
        }

        // MARK: - Return → new paragraph

        private func handleReturn(_ textView: NSTextView) {
            let range = textView.selectedRange()
            guard let storage = textView.textStorage else { return }

            let attrs = DocumentSyncEngine.defaultTypingAttributes()

            storage.beginEditing()
            storage.replaceCharacters(in: range, with: NSAttributedString(string: "\n", attributes: attrs))
            storage.endEditing()

            textView.typingAttributes = attrs
            textView.setSelectedRange(NSRange(location: range.location + 1, length: 0))
        }

        // MARK: - Shift-Return → soft break (Unicode line separator)

        private func handleSoftLineBreak(_ textView: NSTextView) {
            let range = textView.selectedRange()
            guard let storage = textView.textStorage else { return }

            let lineSep = "\u{2028}"
            let currentAttrs = range.location > 0
                ? storage.attributes(at: max(range.location - 1, 0), effectiveRange: nil)
                : textView.typingAttributes

            storage.beginEditing()
            storage.replaceCharacters(in: range, with: NSAttributedString(string: lineSep, attributes: currentAttrs))
            storage.endEditing()

            textView.setSelectedRange(NSRange(location: range.location + 1, length: 0))
        }
    }
}
