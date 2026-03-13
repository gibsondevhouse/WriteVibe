//
//  Message.swift
//  WriteVibe
//

import Foundation
import SwiftData

@Model
final class Message: Identifiable {
    var id: UUID
    var role: Role
    var content: String
    var timestamp: Date

    enum Role: String, Codable { case user, assistant }

    init(role: Role, content: String) {
        self.id        = UUID()
        self.role      = role
        self.content   = content
        self.timestamp = Date()
    }
}
