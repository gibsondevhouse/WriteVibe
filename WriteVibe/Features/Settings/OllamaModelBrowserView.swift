//
//  OllamaModelBrowserView.swift
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

struct OllamaModelBrowserView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var ollamaRunning: Bool? = nil        // nil = checking
    @State private var installedModels: [OllamaModel] = []
    @State private var downloadProgress: [String: Double] = [:]   // modelName → 0.0...1.0
    @State private var downloadStatus: [String: String] = [:]     // modelName → status string
    @State private var downloadTasks: [String: Task<Void, Never>] = [:] // modelName → Task
    @State private var isRefreshing = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                connectionBanner
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        installedSection
                        librarySection
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Local Models")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        // Cancel any ongoing downloads before dismissing
                        Task { await cancelAllDownloads() }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await refreshStatus() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(isRefreshing)
                }
            }
            // Ensure any running downloads are cancelled when the view disappears
            .onDisappear {
                Task { await cancelAllDownloads() }
            }
        }
        .frame(width: 520, height: 620)
        .task { await refreshStatus() }
    }

    private var connectionBanner: some View {
        HStack(spacing: 10) {
            Group {
                if let running = ollamaRunning {
                    Image(systemName: running ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(running ? .green : .orange)
                    Text(running ? "Ollama is running" : "Ollama not detected")
                        .font(.callout)
                        .fontWeight(.medium)
                    if !running {
                        Spacer()
                        Link("Download Ollama", destination: URL(string: "https://ollama.com/download")!)
                            .font(.callout)
                    }
                } else {
                    ProgressView().scaleEffect(0.7)
                    Text("Checking for Ollama…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(ollamaRunning == false ? Color.orange.opacity(0.08) : Color.clear)
    }

    private var installedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Installed")
                .font(.headline)

            if installedModels.isEmpty {
                Text(ollamaRunning == true ? "No models installed yet. Download one below." : "Start Ollama to see installed models.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(installedModels, id: \.id) { model in // Added id: \.id for ForEach
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.displayName)
                                .font(.callout)
                                .fontWeight(.medium)
                            Text(model.sizeFormatted)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            Task {
                                try? await OllamaService.deleteModel(modelName: model.name)
                                await refreshStatus()
                            }
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundStyle(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                        .help("Remove \(model.displayName)")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recommended Models")
                .font(.headline)
            Text("Download once, run forever. No internet required after download.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(curatedModels, id: \.name) { model in
                let isInstalled = installedModels.contains(where: { $0.name == model.name })
                let progress = downloadProgress[model.name]
                let status = downloadStatus[model.name]

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
                    if isInstalled {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .help("Installed")
                    } else if progress != nil { // Downloading or Canceled state
                        if downloadTasks[model.name] != nil { // Task is active, show Cancel
                            Button("Cancel") {
                                Task { await cancelDownload(for: model.name) }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        } else { // Task was cancelled or failed and is no longer tracked, show Download again
                            Button("Download") {
                                downloadModel(model.name)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(ollamaRunning != true)
                        }
                    } else { // Not installed, no active download
                        Button("Download") {
                            downloadModel(model.name)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(ollamaRunning != true)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func refreshStatus() async {
        isRefreshing = true
        ollamaRunning = await OllamaService.isRunning()
        if ollamaRunning == true {
            installedModels = (try? await OllamaService.installedModels()) ?? []
        }
        isRefreshing = false
    }

    private func downloadModel(_ modelName: String) {
        // Ensure no duplicate tasks for the same model
        if downloadTasks[modelName] != nil { return }

        downloadProgress[modelName] = 0.0
        downloadStatus[modelName] = "Starting download…"

        let task = Task {
            do {
                let stream = OllamaService.pullModel(modelName: modelName)
                for try await progress in stream {
                    // Check if the task has been cancelled externally (e.g., by user pressing Cancel)
                    try Task.checkCancellation()

                    downloadProgress[modelName] = progress.fraction
                    downloadStatus[modelName] = progress.status.capitalized
                }
                // Download completed successfully
                downloadProgress.removeValue(forKey: modelName)
                downloadStatus.removeValue(forKey: modelName)
                downloadTasks.removeValue(forKey: modelName) // Clean up task
                await refreshStatus()
            } catch {
                // Handle cancellation or other errors
                downloadProgress.removeValue(forKey: modelName)
                downloadStatus.removeValue(forKey: modelName)
                downloadTasks.removeValue(forKey: modelName) // Clean up task
                // If error is due to cancellation, we don't need to show a failure message
                if !(error is CancellationError) {
                    downloadStatus[modelName] = "Download failed"
                    try? await Task.sleep(nanoseconds: 3_000_000_000) // Show error for a few seconds
                    downloadStatus.removeValue(forKey: modelName)
                }
            }
        }
        downloadTasks[modelName] = task
    }

    // Cancels a specific download task and cleans up its state.
    private func cancelDownload(for modelName: String) async {
        downloadTasks[modelName]?.cancel()
        downloadTasks.removeValue(forKey: modelName)
        downloadProgress.removeValue(forKey: modelName)
        downloadStatus.removeValue(forKey: modelName)
    }

    // Cancels all active download tasks and cleans up their state.
    private func cancelAllDownloads() async {
        for modelName in downloadTasks.keys {
            await cancelDownload(for: modelName)
        }
    }
}
