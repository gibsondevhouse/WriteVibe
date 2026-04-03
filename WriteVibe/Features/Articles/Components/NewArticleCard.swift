//
//  NewArticleCard.swift
//  WriteVibe
//

import SwiftUI

// MARK: - NewArticleCard

struct NewArticleCard: View {
    @Binding var title: String
    @Binding var subtitle: String
    @Binding var selectedTone: ArticleTone
    @Binding var selectedLength: ArticleLength

    var isTitleSuggested: Bool = false
    var isSubtitleSuggested: Bool = false
    var isToneSuggested: Bool = false
    var isLengthSuggested: Bool = false
    var onAcceptSuggestion: (DraftSuggestionField) -> Void = { _ in }
    var onRejectSuggestion: (DraftSuggestionField) -> Void = { _ in }

    var onCreate: (String, String, ArticleTone, ArticleLength) -> Void
    var onCancel: () -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { onCancel() }

                cardBody
                    .frame(width: min(geo.size.width * 0.9, 560))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Card Body

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerGroup
            titleInputGroup
                .padding(.top, WVSpace.xxl)
            subtitleInputGroup
                .padding(.top, WVSpace.lg)
            optionsSeparator
                .padding(.top, WVSpace.xxl)
            optionsGroup
                .padding(.top, WVSpace.lg)
            actionSeparator
                .padding(.top, WVSpace.xxl)
            actionRow
                .padding(.top, WVSpace.lg)
        }
        .padding(36)
        .wvPanelCard()
    }

    // MARK: - Header

    private var headerGroup: some View {
        VStack(alignment: .leading, spacing: WVSpace.xs) {
            Text("Start a new article")
                .font(.wvTitle)
            Text("Give it a title and begin writing.")
                .font(.wvFootnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Title Input

    private var titleInputGroup: some View {
        VStack(alignment: .leading, spacing: WVSpace.sm) {
            HStack(alignment: .center, spacing: WVSpace.sm) {
                suggestionControls(for: .title, isSuggested: isTitleSuggested)
                TextField("What are you writing about?", text: $title)
                    .font(.wvHeadline)
                    .textFieldStyle(.plain)
            }
            Color.primary.opacity(0.08)
                .frame(height: 1)
        }
    }

    // MARK: - Subtitle Input

    private var subtitleInputGroup: some View {
        VStack(alignment: .leading, spacing: WVSpace.sm) {
            HStack(alignment: .center, spacing: WVSpace.sm) {
                suggestionControls(for: .subtitle, isSuggested: isSubtitleSuggested)
                TextField("Add a subtitle or brief description...", text: $subtitle)
                    .font(.wvBody)
                    .textFieldStyle(.plain)
            }
            Color.primary.opacity(0.08)
                .frame(height: 1)
        }
    }

    // MARK: - Options Separator

    private var optionsSeparator: some View {
        Color.primary.opacity(0.06)
            .frame(height: 1)
    }

    // MARK: - Options

    private var optionsGroup: some View {
        VStack(alignment: .leading, spacing: WVSpace.lg) {
            VStack(alignment: .leading, spacing: WVSpace.sm) {
                HStack(spacing: WVSpace.sm) {
                    suggestionControls(for: .tone, isSuggested: isToneSuggested)
                    Text("Tone")
                        .font(.wvFootnote)
                        .foregroundStyle(.secondary)
                }
                toneGrid
            }

            VStack(alignment: .leading, spacing: WVSpace.sm) {
                HStack(spacing: WVSpace.sm) {
                    suggestionControls(for: .targetLength, isSuggested: isLengthSuggested)
                    Text("Length")
                        .font(.wvFootnote)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: WVSpace.sm) {
                    ForEach(ArticleLength.allCases, id: \.self) { length in
                        LengthChip(
                            label: length.rawValue,
                            sub: length.wordTarget,
                            isActive: selectedLength == length
                        ) {
                            selectedLength = length
                        }
                    }
                }
            }
        }
    }

    private var toneGrid: some View {
        let tones = ArticleTone.allCases
        let topRow = Array(tones.prefix(3))
        let bottomRow = Array(tones.suffix(3))
        return VStack(spacing: WVSpace.sm) {
            HStack(spacing: WVSpace.sm) {
                ForEach(topRow, id: \.self) { tone in
                    ToneChip(tone: tone, isActive: selectedTone == tone) {
                        selectedTone = tone
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            HStack(spacing: WVSpace.sm) {
                ForEach(bottomRow, id: \.self) { tone in
                    ToneChip(tone: tone, isActive: selectedTone == tone) {
                        selectedTone = tone
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Action Separator

    private var actionSeparator: some View {
        Color.primary.opacity(0.06)
            .frame(height: 1)
    }

    // MARK: - Actions

    private var actionRow: some View {
        HStack {
            Button("Cancel", action: onCancel)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Begin Writing") {
                onCreate(title, subtitle, selectedTone, selectedLength)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private func suggestionControls(for field: DraftSuggestionField, isSuggested: Bool) -> some View {
        Group {
            if isSuggested {
                HStack(spacing: 6) {
                    Button {
                        onRejectSuggestion(field)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .help("Reject AI suggestion")

                    Button {
                        onAcceptSuggestion(field)
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                    .help("Accept AI suggestion")
                }
                .font(.system(size: 12, weight: .semibold))
            }
        }
    }
}

// MARK: - ToneChip

private struct ToneChip: View {
    let tone: ArticleTone
    let isActive: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Label(tone.rawValue, systemImage: tone.icon)
                .font(.wvLabel)
                .frame(maxWidth: .infinity)
                .padding(.vertical, WVSpace.sm)
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
