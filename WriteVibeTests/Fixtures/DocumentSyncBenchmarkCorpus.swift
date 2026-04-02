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

    init(name: String, description: String, blocks: [ArticleBlock]) {
        self.name = name
        self.description = description
        self.blocks = blocks
        self.expectedCharCount = blocks.reduce(0) { $0 + $1.content.count }
        self.expectedBlockCount = blocks.count
    }

    var expectedBlockTypes: [BlockType] {
        blocks.map(\.blockType)
    }

    func validateRoundTrip(
        recoveredBlocks: [ArticleBlockUpdate],
        recoveredCharCount: Int
    ) -> RoundTripValidation {
        let recoveredTypes = recoveredBlocks.map(\.blockType)
        return RoundTripValidation(
            name: name,
            charCountMatch: expectedCharCount == recoveredCharCount,
            blockCountMatch: expectedBlockCount == recoveredBlocks.count,
            blockTypePreservation: expectedBlockTypes == recoveredTypes,
            actualCharCount: recoveredCharCount,
            actualBlockCount: recoveredBlocks.count
        )
    }
}

struct FixtureMetrics {
    let fixtureName: String
    let charCount: Int
    let blockCount: Int
}

struct BaselineMetricsSummary {
    let fixtureCount: Int
    let totalCharCount: Int
    let totalBlockCount: Int
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
    static let plainText = BenchmarkDocument(
        name: "plainText",
        description: "Single-paragraph document representing a typical short draft.",
        blocks: [
            ArticleBlock(type: .paragraph, content: "The quick brown fox jumps over the lazy dog.", position: 0)
        ]
    )

    static let markdownStyled = BenchmarkDocument(
        name: "markdownStyled",
        description: "Heading, body, quote, code, and bullet list block mix.",
        blocks: [
            ArticleBlock(type: .heading(level: 2), content: "Document Sync Baseline", position: 0),
            ArticleBlock(type: .paragraph, content: "Ensure conversion keeps content stable and ordered.", position: 1000),
            ArticleBlock(type: .blockquote, content: "Correctness first. Optimization later.", position: 2000),
            ArticleBlock(type: .code(language: "swift"), content: "let stable = true; print(stable)", position: 3000),
            ArticleBlock(type: .bulletList, content: "- baseline fixture maintained", position: 4000)
        ]
    )

    static let nestedBlocks = BenchmarkDocument(
        name: "nestedBlocks",
        description: "Alternating heading and paragraph blocks to mimic sectioned content.",
        blocks: [
            ArticleBlock(type: .heading(level: 1), content: "Sprint Notes", position: 0),
            ArticleBlock(type: .paragraph, content: "Section one tracks state-machine behavior.", position: 1000),
            ArticleBlock(type: .heading(level: 3), content: "Observations", position: 2000),
            ArticleBlock(type: .paragraph, content: "Round-trip checks should preserve block mapping.", position: 3000),
            ArticleBlock(type: .heading(level: 4), content: "Action", position: 4000),
            ArticleBlock(type: .numberedList, content: "1) Freeze baseline; 2) Verify conversion; 3) Publish evidence", position: 5000)
        ]
    )

    static let edgeCases = BenchmarkDocument(
        name: "edgeCases",
        description: "Whitespace, punctuation, and non-editable block edge cases.",
        blocks: [
            ArticleBlock(type: .paragraph, content: "Trailing spaces are preserved here.   ", position: 0),
            ArticleBlock(type: .divider, content: "---", position: 1000),
            ArticleBlock(type: .code(language: nil), content: "if value == nil { return \"fallback\" }", position: 2000)
        ]
    )

    static let allBlockTypes = BenchmarkDocument(
        name: "allBlockTypes",
        description: "Comprehensive fixture covering every supported block type.",
        blocks: [
            ArticleBlock(type: .heading(level: 1), content: "All Types", position: 0),
            ArticleBlock(type: .heading(level: 2), content: "Heading Two", position: 1000),
            ArticleBlock(type: .heading(level: 3), content: "Heading Three", position: 2000),
            ArticleBlock(type: .heading(level: 4), content: "Heading Four", position: 3000),
            ArticleBlock(type: .paragraph, content: "Paragraph content for fidelity checks.", position: 4000),
            ArticleBlock(type: .blockquote, content: "Quoted content for style metadata.", position: 5000),
            ArticleBlock(type: .code(language: "markdown"), content: "# Header Body", position: 6000),
            ArticleBlock(type: .image(caption: "cover"), content: "[image: cover]", position: 7000),
            ArticleBlock(type: .bulletList, content: "- first; - second", position: 8000),
            ArticleBlock(type: .numberedList, content: "1. alpha; 2. beta", position: 9000),
            ArticleBlock(type: .divider, content: "---", position: 10000)
        ]
    )

    static let allFixtures: [BenchmarkDocument] = [
        plainText,
        markdownStyled,
        nestedBlocks,
        edgeCases,
        allBlockTypes
    ]
}

struct BaselineMetricsSnapshot {
    static let snapshotDate = "2026-04-02"

    static let metrics: [FixtureMetrics] = DocumentSyncBenchmarkCorpus.allFixtures.map {
        FixtureMetrics(
            fixtureName: $0.name,
            charCount: $0.expectedCharCount,
            blockCount: $0.expectedBlockCount
        )
    }

    static let summary = BaselineMetricsSummary(
        fixtureCount: metrics.count,
        totalCharCount: metrics.reduce(0) { $0 + $1.charCount },
        totalBlockCount: metrics.reduce(0) { $0 + $1.blockCount }
    )
}
