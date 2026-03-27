//
//  ArticleFilterBar.swift
//  WriteVibe
//

import SwiftUI

struct ArticleFilterBar: View {
    @Binding var filterStatus: PublishStatus?

    var body: some View {
        HStack(spacing: 6) {
            FilterChip(label: "All", isActive: filterStatus == nil) {
                filterStatus = nil
            }
            ForEach(PublishStatus.allCases, id: \.self) { status in
                FilterChip(label: status.rawValue, isActive: filterStatus == status) {
                    filterStatus = filterStatus == status ? nil : status
                }
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
    }
}
