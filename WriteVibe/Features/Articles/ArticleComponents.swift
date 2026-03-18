//
//  ArticleComponents.swift
//  WriteVibe
//
//  Shared reusable UI components for the Articles feature.
//

import SwiftUI

// MARK: - ArticleCard

struct ArticleCard: View {
    let article: Article
    let onOpen: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 0) {
                Rectangle()
                    .fill(bandColor.gradient)
                    .frame(height: 6)
                    .clipShape(.rect(topLeadingRadius: WVRadius.card, topTrailingRadius: WVRadius.card))

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label(article.publishStatus.rawValue, systemImage: article.publishStatus.icon)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(bandColor)
                        Spacer()
                        Text(article.updatedAt, style: .relative)
                            .font(.system(size: 10))
                            .foregroundStyle(.quaternary)
                    }

                    Text(article.title)
                        .font(.wvSubhead)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if !article.subtitle.isEmpty {
                        Text(article.subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)

                    HStack {
                        if let series = article.seriesName {
                            Label(series, systemImage: "rectangle.stack")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            Spacer()
                        } else {
                            Spacer()
                        }
                        Text("\(article.wordCount) words")
                            .font(.system(size: 10))
                            .foregroundStyle(.quaternary)
                    }
                }
                .padding(14)
                .frame(minHeight: 120, alignment: .topLeading)
            }
            .background(
                RoundedRectangle(cornerRadius: WVRadius.card)
                    .fill(.background)
                    .shadow(color: .black.opacity(isHovered ? 0.14 : 0.07), radius: isHovered ? 10 : 5, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: WVRadius.card)
                    .strokeBorder(Color.primary.opacity(isHovered ? 0.12 : 0.07), lineWidth: 1)
            )
            .scaleEffect(isHovered ? 1.015 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(WVAnim.card, value: isHovered)
        .contextMenu {
            Button(role: .destructive) { onDelete() } label: {
                Label("Delete Article", systemImage: "trash")
            }
        }
    }

    private var bandColor: Color {
        switch article.publishStatus {
        case .draft:      return .secondary
        case .inProgress: return .orange
        case .done:       return .green
        }
    }
}

// MARK: - NewItemCard

struct NewItemCard: View {
    let title: String
    let icon: String
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.accentColor.opacity(0.3).gradient)
                    .frame(height: 6)
                    .clipShape(.rect(topLeadingRadius: WVRadius.card, topTrailingRadius: WVRadius.card))

                VStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(Color.accentColor.opacity(0.7))
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
                .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
                .padding(14)
            }
            .background(
                RoundedRectangle(cornerRadius: WVRadius.card)
                    .fill(Color.accentColor.opacity(isHovered ? 0.09 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: WVRadius.card)
                    .strokeBorder(
                        Color.accentColor.opacity(isHovered ? 0.35 : 0.15),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                    )
            )
            .scaleEffect(isHovered ? 1.015 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(WVAnim.card, value: isHovered)
    }
}

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

// MARK: - LibraryStatPill

struct LibraryStatPill: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 13, weight: .bold))
                    .monospacedDigit()
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: WVRadius.chipLg)
                .fill(.background.opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: WVRadius.chipLg)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        )
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

// MARK: - WorkspaceCard

struct WorkspaceCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: WVSpace.xs) {
                Text(title)
                    .font(.wvSubhead)
                Text(subtitle)
                    .font(.wvFootnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, WVSpace.base)
            .padding(.top, WVSpace.md)
            .padding(.bottom, WVSpace.sm)

            Divider()

            content()
                .padding(WVSpace.base)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(minHeight: 178, alignment: .topLeading)
        .wvCardLg()
    }
}

// MARK: - WorkspacePill

struct WorkspacePill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: WVSpace.xs) {
            Image(systemName: icon)
                .font(.wvNano)
            Text(text)
                .font(.wvLabel)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, WVSpace.sm + WVSpace.xs)
        .padding(.vertical, WVSpace.xs)
        .background(Color.secondary.opacity(0.09), in: Capsule())
    }
}

// MARK: - WorkspaceLengthChip

struct WorkspaceLengthChip: View {
    let label: String
    let sub: String
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.wvLabel)
                Text(sub)
                    .font(.wvNano)
                    .foregroundStyle(isActive ? Color.accentColor.opacity(0.8) : .secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, WVSpace.sm)
            .padding(.vertical, WVSpace.xs + 2)
            .background(
                RoundedRectangle(cornerRadius: WVRadius.chipLg)
                    .fill(isActive ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: WVRadius.chipLg)
                    .strokeBorder(isActive ? Color.accentColor.opacity(0.32) : .clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
