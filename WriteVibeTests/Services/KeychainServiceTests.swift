import XCTest
@testable import WriteVibe

@MainActor
final class KeychainServiceTests: XCTestCase {

    func testSaveThrowsForEmptyKey() {
        XCTAssertPersistenceFailure(contains: "key must not be empty") {
            try KeychainService.save(key: "", value: "secret")
        }
    }

    func testSaveThrowsForEmptyValue() {
        XCTAssertPersistenceFailure(contains: "value must not be empty") {
            try KeychainService.save(key: "key", value: "")
        }
    }

    func testSaveThrowsForOversizedValue() {
        XCTAssertPersistenceFailure(contains: "value exceeds 4096 characters") {
            try KeychainService.save(key: "key", value: String(repeating: "a", count: 4097))
        }
    }

    func testLoadReturnsNilForEmptyKey() {
        XCTAssertNil(KeychainService.load(key: ""))
    }

    func testDeleteIgnoresEmptyKey() {
        KeychainService.delete(key: "")
    }

    func testSaveLoadAndDeleteRoundTripWhenKeychainIsAvailable() throws {
        let key = "writevibe.tests.\(UUID().uuidString)"
        defer { KeychainService.delete(key: key) }

        do {
            try KeychainService.save(key: key, value: "secret-value")
        } catch {
            throw XCTSkip("Keychain unavailable in this test environment: \(error.localizedDescription)")
        }

        XCTAssertEqual(KeychainService.load(key: key), "secret-value")

        KeychainService.delete(key: key)

        XCTAssertNil(KeychainService.load(key: key))
    }

    private func XCTAssertPersistenceFailure(
        contains expectedSubstring: String,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ expression: () throws -> Void
    ) {
        do {
            try expression()
            XCTFail("Expected persistence failure", file: file, line: line)
        } catch let error as WriteVibeError {
            guard case .persistenceFailed(let operation) = error else {
                return XCTFail("Expected persistenceFailed, got \(error)", file: file, line: line)
            }
            XCTAssertTrue(operation.contains(expectedSubstring), file: file, line: line)
        } catch {
            XCTFail("Unexpected error: \(error)", file: file, line: line)
        }
    }
}