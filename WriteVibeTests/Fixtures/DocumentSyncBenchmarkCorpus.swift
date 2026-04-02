//
//  DocumentSyncBenchmarkCorpus.swift
//  WriteVibeTests
//

import Foundation
@testable import WriteVibe

struct BenchmarkDocument {
    let name: String
    let description: String
    let blocks: [ArticleBlock]
    let expectedCharCount: Int
    let expectedBlockCount: Int
}

struct RoundTripValidation {
    let name: String
    let charCountMatch: Bool
    let blockCountMatch: Bool
    let blockTypePreservation: Bool
    let actualCharCount: Int
    let actualBlockCount: Int
    
    var allMetricsPass: Bool {
        charCountMatch && blockCountMatch && blockTypePreservation
    }
}

enum DocumentSyncBenchmarkCorpus {
    static let allFixtures: [BenchmarkDocument] = []
}

struct BaselineMetricsSnapshot {
    static let snapshotDate = "2026-04-02"
}
