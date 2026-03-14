//
//  ChatScrollContainer.swift
//  WriteVibe
//

import SwiftUI

/// Reusable scrolling container for streaming chat timelines.
struct ChatScrollContainer<RowContent: View>: View {
    let messages: [Message]
    let isThinking: Bool
    let tailID: String
    let tailHeight: CGFloat
    let horizontalPadding: CGFloat
    let verticalPadding: CGFloat
    let pollIntervalMilliseconds: UInt64
    let rowContent: (Int, Message) -> RowContent

    init(
        messages: [Message],
        isThinking: Bool,
        tailID: String,
        tailHeight: CGFloat,
        horizontalPadding: CGFloat,
        verticalPadding: CGFloat,
        pollIntervalMilliseconds: UInt64 = 150,
        @ViewBuilder rowContent: @escaping (Int, Message) -> RowContent
    ) {
        self.messages = messages
        self.isThinking = isThinking
        self.tailID = tailID
        self.tailHeight = tailHeight
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.pollIntervalMilliseconds = pollIntervalMilliseconds
        self.rowContent = rowContent
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        rowContent(index, message)
                    }

                    if isThinking {
                        ThinkingIndicator()
                            .padding(.top, 10)
                    }

                    Color.clear.frame(height: tailHeight).id(tailID)
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .animation(.easeOut(duration: 0.2), value: messages.count)
                .animation(.easeOut(duration: 0.2), value: isThinking)
            }
            .onChange(of: messages.count) {
                withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(tailID) }
            }
            .onChange(of: isThinking) {
                withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(tailID) }
            }
            .task(id: isThinking) {
                guard isThinking else { return }
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(pollIntervalMilliseconds))
                    proxy.scrollTo(tailID)
                }
            }
        }
    }
}
