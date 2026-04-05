import Testing
import Foundation
@testable import WriteVibe

@Suite(.serialized)
struct LegacySeriesNameQuarantineTests {
    @Test func testNoProductionSeriesNameAccessOutsideMigrationBoundary() throws {
        let fileManager = FileManager.default
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceRoot = repoRoot.appendingPathComponent("WriteVibe")

        let allowedPaths: Set<String> = [
            "WriteVibe/Models/Article.swift",
            "WriteVibe/Models/SchemaVersioning.swift"
        ]

        guard let enumerator = fileManager.enumerator(at: sourceRoot, includingPropertiesForKeys: nil) else {
            Issue.record("Failed to enumerate source files")
            return
        }

        var violations: [String] = []

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "swift" else { continue }
            let relativePath = String(fileURL.path.dropFirst(repoRoot.path.count + 1))
            if allowedPaths.contains(relativePath) {
                continue
            }

            guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
                continue
            }

            if content.contains(".seriesName") {
                violations.append(relativePath)
            }
        }

        #expect(violations.isEmpty, "Found disallowed Article.seriesName accesses in: \(violations.joined(separator: ", "))")
    }
}
