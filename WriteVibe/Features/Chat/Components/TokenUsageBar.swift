//
//  TokenUsageBar.swift
//  WriteVibe
//

import SwiftUI

struct TokenUsageBar: View {
    let tokenUsage: Double

    private var tokenColor: Color {
        if tokenUsage < 0.8 { return .accentColor.opacity(0.5) }
        if tokenUsage < 0.95 { return .orange }
        return .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.1))
                        .frame(height: 3)
                        .cornerRadius(1.5)
                    Rectangle()
                        .fill(tokenColor)
                        .frame(width: geo.size.width * min(tokenUsage, 1.0), height: 3)
                        .cornerRadius(1.5)
                }
            }
            .frame(height: 3)
            if tokenUsage >= 0.98 {
                Text("Context full — please start a new chat")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.red)
            } else if tokenUsage >= 0.95 {
                Text("Context nearly full — start a new chat to continue")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}
