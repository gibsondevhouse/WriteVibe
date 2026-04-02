//
//  DocumentSyncBaselineTests.swift
//  WriteVibeTests
//

import AppKit
import Testing
@testable import WriteVibe

@MainActor
struct DocumentSyncBaselineTests {

    @Test func benchmarkCorpus_isFinalizedWithRepresentativeFixtures() {
        #expect(DocumentSyncBenchmarkCorpus.allFixtures.count == 5)
        #expect(DocumentSyncBenchmarkCorpus.plainText.expectedBlockCount == 1)
        #expect(DocumentSyncBenchmarkCorpus.edgeCases.expectedBlockCount == 3)
        #expect(DocumentSyncBenchmarkCorpus.allBlockTypes.expectedBlockCount == 11)

        let hasTypicalFixture = DocumentSyncBenchmarkCorpus.allFixtures.contains { $0.expectedBlockCount <= 3 }
        let hasLargeFixture = DocumentSyncBenchmarkCorpus.allFixtures.contains { $0.expectedBlockCount >= 10 }
        #expect(hasTypicalFixture)
        #expect(hasLargeFixture)
    }

    @Test func conversionRoundTrip_preservesCorpusBaselineMetrics() {
        for fixture in DocumentSyncBenchmarkCorpus.allFixtures {
            let attributed = DocumentSyncEngine.blocksToAttributedString(fixture.blocks)
            let storage = NSTextStorage(attributedString: attributed)
            let recovered = DocumentSyncEngine.attributedStringToBlocks(
                from: storage,
                existingBlocks: fixture.blocks
            )

            let recoveredCharCount = recovered.reduce(0) { $0 + $1.content.count }
            let validation = fixture.validateRoundTrip(
                recoveredBlocks: recovered,
                recoveredCharCount: recoveredCharCount
            )

            #expect(validation.allMetricsPass)
        }
    }

    @Test func baselineMetricsSnapshot_isReproducibleAndConsistent() {
        #expect(BaselineMetricsSnapshot.snapshotDate == "2026-04-02")
        #expect(BaselineMetricsSnapshot.metrics.count == DocumentSyncBenchmarkCorpus.allFixtures.count)

        for fixture in DocumentSyncBenchmarkCorpus.allFixtures {
            let metric = BaselineMetricsSnapshot.metrics.first { $0.fixtureName == fixture.name }
            #expect(metric != nil)
            #expect(metric?.charCount == fixture.expectedCharCount)
            #expect(metric?.blockCount == fixture.expectedBlockCount)
        }

        let totalChars = BaselineMetricsSnapshot.metrics.reduce(0) { $0 + $1.charCount }
        let totalBlocks = BaselineMetricsSnapshot.metrics.reduce(0) { $0 + $1.blockCount }
        #expect(BaselineMetricsSnapshot.summary.fixtureCount == 5)
        #expect(BaselineMetricsSnapshot.summary.totalBlockCount == totalBlocks)
        #expect(BaselineMetricsSnapshot.summary.totalCharCount == totalChars)
        #expect(BaselineMetricsSnapshot.summary.totalBlockCount == 26)
    }
}
