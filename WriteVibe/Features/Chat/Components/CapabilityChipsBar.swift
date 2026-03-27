//
//  CapabilityChipsBar.swift
//  WriteVibe
//

import SwiftUI

struct CapabilityChipsBar: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                searchChip
                toneMenu
                lengthMenu
                formatMenu
                memoryChip
            }
            .padding(.horizontal, 2)
        }
        .frame(maxHeight: 28)
    }

    // MARK: - Search

    private var searchChip: some View {
        CapabilityChip(
            icon: appState.isSearchFetching ? "" : "globe",
            label: appState.isSearchFetching ? "" : "Search",
            isActive: appState.isSearchEnabled && !appState.isSearchFetching
        ) {
            if !appState.isSearchFetching {
                appState.isSearchEnabled.toggle()
            }
        }
        .overlay {
            if appState.isSearchFetching {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.7)
                    .frame(width: 32, height: 32)
                    .padding(.horizontal, 2)
            }
        }
    }

    // MARK: - Tone

    private var toneMenu: some View {
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
    }

    // MARK: - Length

    private var lengthMenu: some View {
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
    }

    // MARK: - Format

    private var formatMenu: some View {
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
    }

    // MARK: - Memory

    private var memoryChip: some View {
        CapabilityChip(
            icon: "memories",
            label: "Memory",
            hasChevron: false,
            isActive: appState.isMemoryEnabled
        ) {
            appState.isMemoryEnabled.toggle()
        }
    }
}
