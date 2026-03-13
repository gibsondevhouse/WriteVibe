//
//  ThinkingIndicator.swift
//  WriteVibe
//

import SwiftUI
import Combine

// MARK: - ThinkingIndicator

struct ThinkingIndicator: View {
    @State private var phase = 0
    private let ticker = Timer.publish(every: 0.42, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.caption2)
                    .fontWeight(.medium)
                Text("WriteVibe")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.tint)

            dotsRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 20)
        .onReceive(ticker) { _ in phase = (phase + 1) % 3 }
    }

    private var dotsRow: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(phase == i ? Color.accentColor : Color.secondary.opacity(0.35))
                    .frame(width: 5, height: 5)
                    .scaleEffect(phase == i ? 1.25 : 0.85)
                    .animation(
                        .spring(response: 0.32, dampingFraction: 0.55).delay(Double(i) * 0.07),
                        value: phase
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
