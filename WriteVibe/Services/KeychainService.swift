//
//  KeychainService.swift
//  WriteVibe
//

import Foundation
import Security

enum KeychainService {
    static let service = "com.writevibe.app"

    private static let maxValueLength = 4096

    static func save(key: String, value: String) throws {
        guard !key.isEmpty else {
            throw WriteVibeError.persistenceFailed(operation: "keychain save — key must not be empty")
        }
        guard !value.isEmpty else {
            throw WriteVibeError.persistenceFailed(operation: "keychain save — value must not be empty")
        }
        guard value.count <= maxValueLength else {
            throw WriteVibeError.persistenceFailed(operation: "keychain save — value exceeds \(maxValueLength) characters")
        }

        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        let deleteStatus = SecItemDelete(query as CFDictionary)
        if deleteStatus != errSecSuccess, deleteStatus != errSecItemNotFound {
            throw WriteVibeError.persistenceFailed(operation: "keychain delete for \(key) (OSStatus \(deleteStatus))")
        }

        let addStatus = SecItemAdd(query as CFDictionary, nil)
        if addStatus != errSecSuccess {
            throw WriteVibeError.persistenceFailed(operation: "keychain save for \(key) (OSStatus \(addStatus))")
        }
    }

    static func load(key: String) -> String? {
        guard !key.isEmpty else { return nil }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)

        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    static func delete(key: String) {
        guard !key.isEmpty else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
