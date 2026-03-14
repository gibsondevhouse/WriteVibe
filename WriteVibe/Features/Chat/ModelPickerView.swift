//
//  ModelPickerView.swift
//  WriteVibe
//

import SwiftUI

// MARK: - ModelPickerView

/// Two-pane popover: provider navigation rail on the left, curated model list on the right.
/// Opens from ModelPickerTrigger. Selecting a model updates the binding and closes the popover.
struct ModelPickerView: View {
    @Binding var model: AIModel
    @Binding var modelIdentifier: String?
    let availableOllamaModels: [OllamaModel]
    @Binding var isPresented: Bool

    @State private var selectedProvider: ModelProvider
    @State private var hoveredModel: AIModel? = nil

    init(model: Binding<AIModel>, modelIdentifier: Binding<String?>, availableOllamaModels: [OllamaModel], isPresented: Binding<Bool>) {
        self._model = model
        self._modelIdentifier = modelIdentifier
        self.availableOllamaModels = availableOllamaModels
        self._isPresented = isPresented
        self._selectedProvider = State(initialValue: model.wrappedValue.provider)
    }

    var body: some View {
        HStack(spacing: 0) {
            providerRail
            Divider()
            modelListPane
            Divider()
            detailPane
        }
        .frame(width: 640, height: 380)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Provider Rail

    private var providerRail: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Provider")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .tracking(0.8)
                .padding(.horizontal, 14)
                .padding(.top, 16)
                .padding(.bottom, 6)

            ForEach(ModelProvider.allCases) { provider in
                ProviderRow(
                    provider: provider,
                    isSelected: selectedProvider == provider
                ) {
                    selectedProvider = provider
                }
            }

            Spacer()
        }
        .frame(width: 158)
        .background(.regularMaterial)
    }

    // MARK: - Model List Pane

    private var modelListPane: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text(selectedProvider.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 10)

                modelsForSelectedProvider
                    .padding(.horizontal, 8)
                    .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Instant pane swap — no transition on provider change
        .id(selectedProvider)
    }

    @ViewBuilder
    private var modelsForSelectedProvider: some View {
        if selectedProvider == .local {
            localModelsSection
        } else {
            ForEach(selectedProvider.models, id: \.self) { m in
                ModelRow(
                    model: m,
                    displayName: m.rawValue,
                    tagline: m.tagline,
                    isSelected: model == m,
                    onHover: { hovered in hoveredModel = hovered ? m : nil }
                ) {
                    model = m
                    modelIdentifier = nil
                    isPresented = false
                }
            }
        }
    }

    // MARK: - Local (Ollama) Section

    private var localModelsSection: some View {
        Group {
            if availableOllamaModels.isEmpty {
                emptyOllamaState
            } else {
                ForEach(availableOllamaModels) { ollamaModel in
                    let isSelected = model == .ollama
                        && modelIdentifier == ollamaModel.name
                    ModelRow(
                        model: .ollama,
                        displayName: ollamaModel.displayName,
                        tagline: "Local · private · no API key required",
                        isSelected: isSelected,
                        onHover: { hovered in hoveredModel = hovered ? .ollama : nil }
                    ) {
                        model = .ollama
                        modelIdentifier = ollamaModel.name
                        isPresented = false
                    }
                }
            }
        }
    }

    private var emptyOllamaState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No local models installed")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)

            Text("Download a model from Settings → Models to use Ollama locally, or choose a cloud provider from the rail.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }

    // MARK: - Detail Pane

    private var detailPane: some View {
        ZStack(alignment: .topLeading) {
            // Idle placeholder — fades out once a model is hovered
            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 20))
                    .foregroundStyle(.quaternary)
                Text("Hover a model\nto learn more")
                    .font(.system(size: 11))
                    .foregroundStyle(.quaternary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .opacity(hoveredModel == nil ? 1 : 0)

            // Active model card
            if let m = hoveredModel {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: m.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 26, height: 26)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        Text(m.rawValue)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Text(m.useCaseDescription)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .topLeading)))
            }
        }
        .frame(width: 200)
        .frame(maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.15), value: hoveredModel)
    }
}

// MARK: - ProviderRow

private struct ProviderRow: View {
    let provider: ModelProvider
    let isSelected: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Left accent bar — visible only on selected row
                Rectangle()
                    .fill(isSelected ? Color.accentColor : Color.clear)
                    .frame(width: 2.5, height: 18)
                    .cornerRadius(1.5)
                    .padding(.leading, 6)

                Text(provider.displayName)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .padding(.leading, 8)

                Spacer()
            }
            .frame(height: 36)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(rowBackground)
                    .padding(.horizontal, 4)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.1), value: isHovered)
    }

    private var rowBackground: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(.quaternary)
        } else if isHovered {
            return AnyShapeStyle(.quinary)
        } else {
            return AnyShapeStyle(.clear)
        }
    }
}

// MARK: - ModelRow

private struct ModelRow: View {
    let model: AIModel
    let displayName: String
    let tagline: String
    let isSelected: Bool
    let onHover: (Bool) -> Void
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(tagline)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .opacity(isSelected ? 1 : 0)
                    .frame(width: 14)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(rowBackground)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered in
            isHovered = hovered
            onHover(hovered)
        }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }

    private var rowBackground: some ShapeStyle {
        if isSelected {
            return AnyShapeStyle(Color.accentColor.opacity(0.1))
        } else if isHovered {
            return AnyShapeStyle(.quaternary)
        } else {
            return AnyShapeStyle(.clear)
        }
    }
}
