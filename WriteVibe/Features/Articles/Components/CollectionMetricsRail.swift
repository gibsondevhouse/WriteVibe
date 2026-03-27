//
//  CollectionMetricsRail.swift
//  WriteVibe
//

import SwiftUI

// MARK: - CollectionMetricsRail

struct CollectionMetricsRail: View {
    let articles: [Article]

    private var draftCount: Int {
        articles.filter { $0.publishStatus == .draft }.count
    }

    private var inProgressCount: Int {
        articles.filter { $0.publishStatus == .inProgress }.count
    }

    private var doneCount: Int {
        articles.filter { $0.publishStatus == .done }.count
    }

    private var totalWords: Int {
        articles.reduce(0) { $0 + $1.wordCount }
    }

    private var formattedWords: String {
        if totalWords >= 1_000_000 {
            return String(format: "%.1fM", Double(totalWords) / 1_000_000)
        } else if totalWords >= 1_000 {
            return String(format: "%.1fk", Double(totalWords) / 1_000)
        }
        return "\(totalWords)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel
            metricsStack
            Spacer()
        }
        .frame(width: 220)
        .background(Color(.windowBackgroundColor))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.primary.opacity(0.07))
                .frame(width: 1)
        }
    }

    // MARK: - Section Label

    private var sectionLabel: some View {
        Text("Collection")
            .wvSectionLabel()
            .padding(.horizontal, WVSpace.lg)
            .padding(.top, WVSpace.xxl)
            .padding(.bottom, WVSpace.md)
    }

    // MARK: - Metrics Stack

    private var metricsStack: some View {
        VStack(spacing: WVSpace.xs) {
            metricRow(icon: "doc.text", value: "\(articles.count)", label: "Articles", color: .accentColor)
            metricRow(icon: "circle.dashed", value: "\(draftCount)", label: "Drafts", color: .secondary)
            metricRow(icon: "pencil.circle", value: "\(inProgressCount)", label: "In Progress", color: .orange)
            metricRow(icon: "checkmark.circle.fill", value: "\(doneCount)", label: "Completed", color: .green)
            metricRow(icon: "text.alignleft", value: formattedWords, label: "Total Words", color: .accentColor)
        }
        .padding(.horizontal, WVSpace.md)
    }

    // MARK: - Metric Row

    private func metricRow(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: WVSpace.sm) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
                .frame(width: 20, alignment: .center)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                Text(label)
                    .font(.wvNano)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, WVSpace.sm)
        .padding(.vertical, WVSpace.sm)
        .background(
            RoundedRectangle(cornerRadius: WVRadius.chipLg)
                .fill(Color.primary.opacity(0.03))
        )
    }
}
