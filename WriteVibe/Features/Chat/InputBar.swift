//
//  InputBar.swift
//  WriteVibe
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - ChatInputBar

struct ChatInputBar: View {
    @Environment(AppState.self) private var appState // Access AppState to observe isSearchFetching

    @Binding var text: String
    let isThinking: Bool
    let tokenUsage: Double
    var focused: FocusState<Bool>.Binding
    var onDocumentAttached: ((String) -> Void)? = nil
    var onDocumentImportFailed: ((String) -> Void)? = nil
    let onSend: () -> Void
    let onStop: () -> Void

    @State private var showAttachMenu = false
    @State private var showURLAlert = false
    @State private var urlInput = ""

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
        .alert("Attach URL", isPresented: $showURLAlert) {
            TextField("https://example.com", text: $urlInput)
            Button("Cancel", role: .cancel) { urlInput = "" }
            Button("Attach") {
                let urlToFetch = urlInput
                urlInput = ""
                Task {
                    do {
                        let content = try await DocumentIngestionService.fetchURL(urlString: urlToFetch)
                        onDocumentAttached?(content)
                    } catch {
                        onDocumentImportFailed?(error.localizedDescription)
                    }
                }
            }
        } message: {
            Text("Paste a URL to fetch its content and add it to your prompt.")
        }
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
            }, onDocumentImportFailed: { error in
                showAttachMenu = false
                onDocumentImportFailed?(error)
            }, onShowURLAlert: {
                showAttachMenu = false
                // Small delay to allow popover to dismiss before showing alert
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showURLAlert = true
                }
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

    private var capabilityChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                // Search Toggle with spinner when fetching
                CapabilityChip(
                    icon: appState.isSearchFetching ? "" : "globe", // Hide icon when spinner is shown
                    label: appState.isSearchFetching ? "" : "Search", // Hide label when spinner is shown
                    isActive: appState.isSearchEnabled && !appState.isSearchFetching // Only active if enabled and not fetching
                ) {
                    if !appState.isSearchFetching { // Prevent toggling while fetching
                        appState.isSearchEnabled.toggle()
                    }
                }
                // Conditionally display spinner or the chip content
                .overlay {
                    if appState.isSearchFetching {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.7)
                            .frame(width: 32, height: 32)
                            .padding(.horizontal, 2) // Adjust padding to align with normal chip
                    }
                }

                // Tone Menu
                Menu {
                    Picker("Tone", selection: Bindable(appState).selectedTone) {
                        Text("Balanced").tag("Balanced")
                        Text("Professional").tag("Professional")
                        Text("Creative").tag("Creative")
                        Text("Concise").tag("Concise")
                    }
                } label: {
                    CapabilityChip(
                        icon: "theatermasks",
                        label: appState.selectedTone,
                        hasChevron: true,
                        isActive: appState.selectedTone != "Balanced"
                    )
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                // Length Menu
                Menu {
                    Picker("Length", selection: Bindable(appState).selectedLength) {
                        Text("Short").tag("Short")
                        Text("Normal").tag("Normal")
                        Text("Long").tag("Long")
                    }
                } label: {
                    CapabilityChip(
                        icon: "textformat.size",
                        label: appState.selectedLength,
                        hasChevron: true,
                        isActive: appState.selectedLength != "Normal"
                    )
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                // Format Menu
                Menu {
                    Picker("Format", selection: Bindable(appState).selectedFormat) {
                        Text("Markdown").tag("Markdown")
                        Text("Plain Text").tag("Plain Text")
                        Text("JSON").tag("JSON")
                    }
                } label: {
                    CapabilityChip(
                        icon: "doc.richtext",
                        label: appState.selectedFormat,
                        hasChevron: true,
                        isActive: appState.selectedFormat != "Markdown"
                    )
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                // Memory Toggle
                CapabilityChip(
                    icon: "memories",
                    label: "Memory",
                    hasChevron: false,
                    isActive: appState.isMemoryEnabled
                ) {
                    appState.isMemoryEnabled.toggle()
                }
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
    var onDocumentImportFailed: ((String) -> Void)? = nil
    var onShowURLAlert: (() -> Void)? = nil

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
                    switch opt.label {
                    case "Upload Document":
                        Task { @MainActor in
                            do {
                                if let text = try await DocumentIngestionService.pickAndExtract() {
                                    onDocumentAttached?(text)
                                }
                            } catch {
                                onDocumentImportFailed?(error.localizedDescription)
                            }
                        }
                    case "Attach URL":
                        onShowURLAlert?()
                    case "Upload Image":
                        Task { @MainActor in
                            let panel = NSOpenPanel()
                            panel.allowedContentTypes = [.image]
                            panel.allowsMultipleSelection = false
                            if panel.runModal() == .OK, let url = panel.url {
                                // For now, we attach the name as a reference
                                onDocumentAttached?("[Image Attached: \(url.lastPathComponent)]")
                            }
                        }
                    case "Voice Input":
                        onDocumentImportFailed?("Voice Input coming soon (macOS 15+ Dictation API)")
                    default:
                        break
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
    var isActive: Bool = false
    var action: (() -> Void)? = nil
    
    // Inject AppState to observe isSearchFetching for the spinner logic
    @Environment(AppState.self) private var appState

    var body: some View {
        Button {
            action?()
        } label: {
            if appState.isSearchFetching && icon == "globe" { // Special handling for search spinner
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.7)
                    .frame(width: 32, height: 32)
                    .padding(.horizontal, 2) // Adjust padding to align with normal chip
            } else {
                HStack(spacing: 4) {
                    if !icon.isEmpty { // Only show icon if not empty (for spinner case)
                        Image(systemName: icon)
                            .font(.system(size: 10, weight: .medium))
                    }
                    if !label.isEmpty { // Only show label if not empty (for spinner case)
                        Text(label)
                            .font(.system(size: 11, weight: .medium))
                    }
                    if hasChevron {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                    }
                }
                .foregroundStyle(isActive ? .white : Color.secondary.opacity(0.8))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    isActive ? Color.accentColor : Color.secondary.opacity(0.07),
                    in: Capsule()
                )
            }
        }
        .buttonStyle(.plain)
        .help(action == nil ? "\(label) · Choose from menu" : "Toggle \(label)")
        .disabled(appState.isSearchFetching && icon == "globe") // Disable search chip while fetching
    }
}
