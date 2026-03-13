//
//  CollapsibleSectionHeader.swift
//  WriteVibe
//

import SwiftUI

// MARK: - CollapsibleSectionHeader

struct CollapsibleSectionHeader: View {
    let title: String
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Button(action: onToggle) {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption2)
            }
            .buttonStyle(.plain)
        }
    }
}
