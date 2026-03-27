//
//  CapabilityChip.swift
//  WriteVibe
//

import SwiftUI

struct CapabilityChip: View {
    let icon: String
    let label: String
    var hasChevron: Bool = false
    var isActive: Bool = false
    var action: (() -> Void)? = nil

    @Environment(AppState.self) private var appState

    var body: some View {
        Button {
            action?()
        } label: {
            if appState.isSearchFetching && icon == "globe" {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.7)
                    .frame(width: 32, height: 32)
                    .padding(.horizontal, 2)
            } else {
                HStack(spacing: 4) {
                    if !icon.isEmpty {
                        Image(systemName: icon)
                            .font(.system(size: 10, weight: .medium))
                    }
                    if !label.isEmpty {
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
        .disabled(appState.isSearchFetching && icon == "globe")
    }
}
