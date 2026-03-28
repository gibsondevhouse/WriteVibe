//
//  CuratedModelRow.swift
//  WriteVibe
//

import SwiftUI

struct CuratedModel {
    let name: String        // Ollama pull name, e.g. "llama3.2:8b"
    let displayName: String
    let description: String
    let sizeLabel: String
    let tags: [String]
}

let curatedModels: [CuratedModel] = [
    CuratedModel(name: "llama3.2:3b",   displayName: "Llama 3.2 3B",   description: "Fast general chat. Great on any Mac.",              sizeLabel: "~2 GB",  tags: ["Fast", "General"]),
    CuratedModel(name: "llama3.2:8b",   displayName: "Llama 3.2 8B",   description: "Solid all-rounder. Best balance of speed/quality.", sizeLabel: "~5 GB",  tags: ["Balanced", "General"]),
    CuratedModel(name: "mistral:7b",    displayName: "Mistral 7B",     description: "Strong instruction following. Great for writing.",  sizeLabel: "~4 GB",  tags: ["Writing", "Balanced"]),
    CuratedModel(name: "gemma3:4b",     displayName: "Gemma 3 4B",     description: "Fast, clean writing quality. Made by Google.",      sizeLabel: "~3 GB",  tags: ["Fast", "Writing"]),
    CuratedModel(name: "phi4:14b",      displayName: "Phi-4 14B",      description: "High quality. Requires M2 or later.",               sizeLabel: "~9 GB",  tags: ["Quality", "M2+"]),
    CuratedModel(name: "qwen2.5:7b",    displayName: "Qwen 2.5 7B",    description: "Strong writing, editing, and summarization.",       sizeLabel: "~5 GB",  tags: ["Writing", "Balanced"]),
]

struct CuratedModelRow: View {
    let model: CuratedModel
    let isInstalled: Bool
    let progress: Double?
    let status: String?
    let hasActiveTask: Bool
    let ollamaEnabled: Bool
    var onDownload: () -> Void
    var onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(model.displayName)
                        .font(.callout)
                        .fontWeight(.medium)
                    ForEach(model.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.tint.opacity(0.12), in: Capsule())
                            .foregroundStyle(.tint)
                    }
                }
                Text(model.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(model.sizeLabel)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                if let progress, let status {
                    VStack(alignment: .leading, spacing: 3) {
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                            .frame(maxWidth: 200)
                        Text(status)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }
            }
            Spacer()
            actionButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var actionButton: some View {
        if isInstalled {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .help("Installed")
        } else if progress != nil {
            if hasActiveTask {
                Button("Cancel", action: onCancel)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            } else {
                Button("Download", action: onDownload)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(!ollamaEnabled)
            }
        } else {
            Button("Download", action: onDownload)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!ollamaEnabled)
        }
    }
}
