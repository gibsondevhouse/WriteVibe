//
//  SettingsView.swift
//  WriteVibe
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var openRouterKey: String = ""
    @State private var ollamaRunning: Bool = false
    @State private var showOllamaModelBrowser = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Local Models") {
                    HStack {
                        Image(systemName: ollamaRunning ? "checkmark.circle.fill" : "circle.dotted")
                            .foregroundStyle(ollamaRunning ? .green : .secondary)
                        Text(ollamaRunning ? "Ollama is running" : "Ollama not detected")
                            .font(.callout)
                        Spacer()
                        Button("Manage Models…") { showOllamaModelBrowser = true }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                    .task { ollamaRunning = await OllamaService.isRunning() }
                }

                Section {
                    apiKeyField(label: "OpenRouter API Key", text: $openRouterKey, keychainKey: "openrouter_api_key")
                    Text("One key unlocks Claude, GPT-4o, Gemini, DeepSeek, and more. Get yours free at openrouter.ai")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Cloud API Keys")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                openRouterKey = KeychainService.load(key: "openrouter_api_key") ?? ""
            }
            .sheet(isPresented: $showOllamaModelBrowser) {
                OllamaModelBrowserView()
            }
        }
        .frame(width: 450, height: 350)
    }

    @ViewBuilder
    private func apiKeyField(label: String, text: Binding<String>, keychainKey: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            SecureField("Paste key here", text: text)
                .textFieldStyle(.roundedBorder)
                .onChange(of: text.wrappedValue) {
                    KeychainService.save(key: keychainKey, value: text.wrappedValue)
                }
        }
    }
}

#Preview {
    SettingsView()
}
