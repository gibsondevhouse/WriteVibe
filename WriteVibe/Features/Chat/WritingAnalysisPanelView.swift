//
//  WritingAnalysisPanelView.swift
//  WriteVibe
//

import SwiftUI

struct WritingAnalysisPanelView: View {
    @Environment(AppState.self) private var appState
    @Binding var isPanelOpen: Bool // Binding to control the panel's visibility

    var body: some View {
        if let analysis = appState.analysisResult {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Writing Analysis")
                        .font(.headline)
                    Spacer()
                    Button {
                        isPanelOpen = false // Close the panel
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 5)

                Divider()

                HStack {
                    Text("Tone:")
                        .fontWeight(.medium)
                    Spacer()
                    Text(analysis.tone)
                }

                HStack {
                    Text("Reading Level:")
                        .fontWeight(.medium)
                    Spacer()
                    Text(analysis.readingLevel)
                }

                HStack {
                    Text("Word Count:")
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(analysis.wordCount)")
                }

                Divider()

                Text("Suggestions:")
                    .font(.headline)
                    .padding(.bottom, 2)

                if analysis.suggestions.isEmpty {
                    Text("No specific suggestions at this time.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(analysis.suggestions, id: \.self) { suggestion in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "sparkles") // Bullet point icon
                                    .font(.caption)
                                    .foregroundColor(.accentColor)
                                    .padding(.top, 2)
                                Text(suggestion)
                                    .font(.callout)
                            }
                        }
                    }
                }

                Spacer() // Push content to the top
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: 300, alignment: .topLeading) // Max height for the panel
            .background(.thinMaterial) // Use a frosted glass effect
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 6)
            .padding(.horizontal, 24) // Match ChatView's horizontal padding
            .padding(.bottom, 8) // Space between panel and input bar
        }
    }
}
