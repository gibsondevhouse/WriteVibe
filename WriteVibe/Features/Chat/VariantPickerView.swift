//
//  VariantPickerView.swift
//  WriteVibe
//
//  Presents three on-device rewrites of a passage and lets the user copy any one to the clipboard.
//

import SwiftUI

// MARK: - VariantPickerView

@available(macOS 26, *)
struct VariantPickerView: View {
    let originalText: String
    let onDismiss: () -> Void

    @State private var variants: [String] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var copiedIndex: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 560, minHeight: 400)
        .task { await loadVariants() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Variants")
                    .font(.headline)
                Text("Three on-device rewrites — tap any card to copy.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isLoading {
            HStack {
                Spacer()
                VStack(spacing: 10) {
                    ProgressView()
                    Text("Generating variants…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(40)
        } else if let error = errorMessage {
            HStack {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                Spacer()
            }
            .padding(40)
        } else {
            ScrollView {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(Array(variants.prefix(3).enumerated()), id: \.offset) { index, variant in
                        variantCard(index: index, text: variant)
                    }
                }
                .padding(16)
            }
        }
    }

    // MARK: - Variant Card

    private func variantCard(index: Int, text: String) -> some View {
        let isCopied = copiedIndex == index
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Variant \(index + 1)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    copiedIndex = index
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedIndex = nil }
                } label: {
                    Label(isCopied ? "Copied!" : "Copy", systemImage: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .animation(.easeOut(duration: 0.15), value: isCopied)
            }

            Text(text)
                .font(.body)
                .lineSpacing(4)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Loading

    private func loadVariants() async {
        isLoading = true
        errorMessage = nil
        do {
            let result = try await AppleIntelligenceService.generateVariants(
                for: originalText,
                tone: "Balanced"
            )
            variants = Array(result.variants.prefix(3))
        } catch {
            errorMessage = "Could not generate variants. Apple Intelligence may be unavailable."
        }
        isLoading = false
    }
}
