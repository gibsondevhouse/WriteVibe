//
//  ModelPickerTrigger.swift
//  WriteVibe
//

import SwiftUI

// MARK: - ModelPickerTrigger

/// Compact toolbar button that shows the active provider + model name
/// and opens the two-pane ModelPickerView as a popover.
/// Accepts bindings so it works both for an active Conversation and for
/// the WelcomeView default model preference.
struct ModelPickerTrigger: View {
    @Binding var model: AIModel
    @Binding var modelIdentifier: String?
    let availableOllamaModels: [OllamaModel]

    @State private var isOpen = false
    @State private var isHovered = false

    var body: some View {
        Button {
            isOpen.toggle()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: model.icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .layoutPriority(1)

                Text(triggerLabel)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .layoutPriority(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            // Fixed width ensures the button never resizes as model/provider changes.
            .frame(width: 200)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear))
            )
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        // Prevents the toolbar ToolbarItem from inflating the button's frame,
        // which would make the hover area visually drift beyond the background.
        .fixedSize()
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.1), value: isHovered)
        .popover(isPresented: $isOpen, arrowEdge: .bottom) {
            ModelPickerView(
                model: $model,
                modelIdentifier: $modelIdentifier,
                availableOllamaModels: availableOllamaModels,
                isPresented: $isOpen
            )
        }
        .help("Select AI model")
    }

    private var triggerLabel: String {
        if model == .ollama, let name = modelIdentifier {
            let baseName = name.split(separator: ":").first.map(String.init) ?? name
            return "Local · \(baseName)"
        }
        let provider = model.provider.displayName
        let modelName = model.rawValue
        return "\(provider) · \(modelName)"
    }
}
