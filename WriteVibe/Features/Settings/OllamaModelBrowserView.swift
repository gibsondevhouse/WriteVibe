//
//  OllamaModelBrowserView.swift
//  WriteVibe
//

import SwiftUI

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
                CuratedModelRow(
                    model: model,
                    isInstalled: installedModels.contains(where: { $0.name == model.name }),
                    progress: downloadProgress[model.name],
                    status: downloadStatus[model.name],
                    hasActiveTask: downloadTasks[model.name] != nil,
                    ollamaEnabled: ollamaRunning == true,
                    onDownload: { downloadModel(model.name) },
                    onCancel: { Task { await cancelDownload(for: model.name) } }
                )
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
