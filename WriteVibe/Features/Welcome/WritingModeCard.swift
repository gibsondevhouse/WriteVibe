//
//  WritingModeCard.swift
//  WriteVibe
//

import SwiftUI

// MARK: - WritingModeCard

struct WritingModeCard: View {
    let icon:        String
    let label:       String
    let description: String
    let action:      () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.tint)
                    .frame(width: 20, alignment: .center)

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .glassEffect(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .opacity(isHovered ? 1.0 : 0.82)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}
