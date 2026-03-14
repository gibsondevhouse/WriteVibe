//
//  InputBar.swift
//  WriteVibe
//

import SwiftUI

// MARK: - ChatInputBar

struct ChatInputBar: View {
    @Binding var text: String
    let isThinking: Bool
    let tokenUsage: Double
    var focused: FocusState<Bool>.Binding
    var onDocumentAttached: ((String) -> Void)? = nil
    let onSend: () -> Void
    let onStop: () -> Void

    @State private var showAttachMenu = false

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isThinking && tokenUsage < 0.98
    }

    private var tokenColor: Color {
        if tokenUsage < 0.8 { return .accentColor.opacity(0.5) }
        if tokenUsage < 0.95 { return .orange }
        return .red
    }

    var body: some View {
        VStack(spacing: 0) {
            if tokenUsage > 0.5 {
                VStack(alignment: .leading, spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.1))
                                .frame(height: 3)
                                .cornerRadius(1.5)
                            Rectangle()
                                .fill(tokenColor)
                                .frame(width: geo.size.width * min(tokenUsage, 1.0), height: 3)
                                .cornerRadius(1.5)
                        }
                    }
                    .frame(height: 3)
                    if tokenUsage >= 0.98 {
                        Text("Context full — please start a new chat")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.red)
                    } else if tokenUsage >= 0.95 {
                        Text("Context nearly full — start a new chat to continue")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)

                // separator after token bar
                Rectangle()
                    .fill(Color.primary.opacity(0.12))
                    .frame(height: 1)
            }

            // Top border line — text field sits between this and the chips separator
            Rectangle()
                .fill(Color.primary.opacity(0.55))
                .frame(height: 1)

            textField
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 10)

            // Chips + send — bound to the bottom inside the input card
            HStack(alignment: .center, spacing: 6) {
                attachButton
                capabilityChips
                Spacer(minLength: 0)
                sendButton
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
        }
        .background(Color(.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    focused.wrappedValue
                        ? Color.primary.opacity(0.35)
                        : Color.primary.opacity(0.14),
                    lineWidth: 1
                )
                .animation(.easeInOut(duration: 0.2), value: focused.wrappedValue)
        }
        .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 4)
    }

    // MARK: - Attach

    private var attachButton: some View {
        Button { showAttachMenu.toggle() } label: {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showAttachMenu, arrowEdge: .top) {
            AttachMenu(onDocumentAttached: { text in
                showAttachMenu = false
                onDocumentAttached?(text)
            })
        }
    }

    // MARK: - Text Field

    private var textField: some View {
        TextField("Describe your idea, draft, or edit…", text: $text, axis: .vertical)
            .lineLimit(3...20)
            .font(.body)
            .lineSpacing(4)
            .tint(.accentColor)
            .focused(focused)
            .textFieldStyle(.plain)
            // On macOS, axis:.vertical TextFields don't reliably fire onSubmit on Return,
            // so we intercept the key directly. Shift/Option+Return still inserts a newline.
            .onKeyPress(.return) {
                guard canSend else { return .ignored }
                onSend()
                return .handled
            }
    }

    // MARK: - Capability Chips
    // TODO: Implement — these are placeholder-only chips with no action handlers

    private var capabilityChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                CapabilityChip(icon: "globe", label: "Search")
                CapabilityChip(icon: "theatermasks", label: "Tone", hasChevron: true)
                CapabilityChip(icon: "textformat.size", label: "Length", hasChevron: true)
                CapabilityChip(icon: "doc.richtext", label: "Format", hasChevron: true)
                CapabilityChip(icon: "memories", label: "Memory", hasChevron: true)
            }
            .padding(.horizontal, 2)
        }
        .frame(maxHeight: 28)
    }

    // MARK: - Send / Stop

    private var sendButton: some View {
        Button(action: isThinking ? onStop : onSend) {
            Group {
                if isThinking {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(.white)
                        .frame(width: 10, height: 10)
                } else {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 32, height: 32)
            .background {
                Circle()
                    .fill(
                        canSend || isThinking
                            ? AnyShapeStyle(Color.accentColor)
                            : AnyShapeStyle(Color.secondary.opacity(0.2))
                    )
            }
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.return, modifiers: .command)
        .disabled(!canSend && !isThinking)
        .animation(.easeInOut(duration: 0.18), value: canSend)
    }


}
// MARK: - AttachMenu

struct AttachMenu: View {
    var onDocumentAttached: ((String) -> Void)? = nil

    private let options: [(icon: String, label: String)] = [
        ("photo.on.rectangle", "Upload Image"),
        ("doc.text",           "Upload Document"),
        ("link",               "Attach URL"),
        ("mic",                "Voice Input"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(options, id: \.label) { opt in
                Button {
                    if opt.label == "Upload Document" {
                        Task { @MainActor in
                            if let text = await DocumentIngestionService.pickAndExtract() {
                                onDocumentAttached?(text)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: opt.icon)
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundStyle(.tint)
                            .frame(width: 20, alignment: .center)
                        Text(opt.label)
                            .font(.body)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                if opt.label != options.last!.label {
                    Divider()
                }
            }
        }
        .frame(width: 200)
        .padding(8)
    }
}

// MARK: - CapabilityChip

private struct CapabilityChip: View {
    let icon: String
    let label: String
    var hasChevron: Bool = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
            Text(label)
                .font(.system(size: 11, weight: .medium))
            if hasChevron {
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
        }
        .foregroundStyle(Color.secondary.opacity(0.5))
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Color.secondary.opacity(0.07), in: Capsule())
        .help("\(label) · Coming soon")
    }
}

