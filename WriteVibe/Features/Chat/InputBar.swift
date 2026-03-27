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
    var onDocumentImportFailed: ((String) -> Void)? = nil
    let onSend: () -> Void
    let onStop: () -> Void

    @State private var showAttachMenu = false
    @State private var showURLAlert = false
    @State private var urlInput = ""

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isThinking && tokenUsage < 0.98
    }

    var body: some View {
        VStack(spacing: 0) {
            if tokenUsage > 0.5 {
                TokenUsageBar(tokenUsage: tokenUsage)

                Rectangle()
                    .fill(Color.primary.opacity(0.12))
                    .frame(height: 1)
            }

            Rectangle()
                .fill(Color.primary.opacity(0.55))
                .frame(height: 1)

            ChatInputField(text: $text, canSend: canSend, focused: focused, onSend: onSend)
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 10)

            HStack(alignment: .center, spacing: 6) {
                attachButton
                CapabilityChipsBar()
                Spacer(minLength: 0)
                ChatSendButton(isThinking: isThinking, canSend: canSend, onSend: onSend, onStop: onStop)
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
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showURLAlert = true
                }
            })
        }
    }
}
