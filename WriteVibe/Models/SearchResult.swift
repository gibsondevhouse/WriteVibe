//
//  SearchResult.swift
//  WriteVibe
//

import Foundation

struct SearchResult: Codable, Identifiable {
    let id = UUID() // Use UUID for identification in SwiftUI lists, not part of the data itself.
    let title: String
    let url: URL
    let snippet: String

    // Custom CodingKeys to map JSON keys to struct properties if they differ,
    // or if they need specific handling. Assuming JSON keys match property names here.
    enum CodingKeys: String, CodingKey {
        case title
        case url
        case snippet
    }
}
