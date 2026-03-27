//
//  ArticleComponents.swift
//  WriteVibe
//
//  Shared reusable UI components for the Articles feature.
//

import SwiftUI

// MARK: - LengthChip

struct LengthChip: View {
    let label: String
    let sub: String
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                Text(sub)
                    .font(.system(size: 9))
                    .foregroundStyle(isActive ? Color.accentColor.opacity(0.8) : .secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: WVRadius.chip)
                    .fill(isActive ? AnyShapeStyle(Color.accentColor.opacity(0.12)) : AnyShapeStyle(.quaternary))
            )
            .overlay(
                RoundedRectangle(cornerRadius: WVRadius.chip)
                    .strokeBorder(isActive ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
            )
            .foregroundStyle(isActive ? Color.accentColor : .secondary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - FilterChip

struct FilterChip: View {
    let label: String
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill(isActive ? AnyShapeStyle(Color.accentColor.opacity(0.15)) : AnyShapeStyle(.quaternary))
                )
                .foregroundStyle(isActive ? Color.accentColor : .secondary)
        }
        .buttonStyle(.plain)
    }
}

