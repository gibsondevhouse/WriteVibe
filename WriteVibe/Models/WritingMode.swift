//
//  WritingMode.swift
//  WriteVibe
//

import SwiftUI

// MARK: - WritingMode

/// Quick-start templates displayed on the welcome screen.
struct WritingMode: Identifiable {
    let icon: String
    let label: String
    let description: String
    let prompt: String

    var id: String { label }

    static let all: [WritingMode] = [
        WritingMode(icon: "doc.text",       label: "Essay",   description: "Write a well-structured essay",     prompt: "Write a well-structured essay about "),
        WritingMode(icon: "book.closed",    label: "Story",   description: "Write a compelling short story",    prompt: "Write a compelling short story about "),
        WritingMode(icon: "newspaper",      label: "Article", description: "Write an engaging article",         prompt: "Write an engaging article about "),
        WritingMode(icon: "envelope",       label: "Email",   description: "Write a professional email",        prompt: "Write a professional email that "),
        WritingMode(icon: "wand.and.stars", label: "Edit",    description: "Polish or reshape existing text",   prompt: "Please review and improve the following text: "),
        WritingMode(icon: "list.bullet",    label: "Outline", description: "Structure your thinking",           prompt: "Create a detailed outline for "),
    ]
}

// MARK: - WritingAction

/// Follow-up actions shown below the last assistant message.
struct WritingAction: Identifiable {
    let icon: String
    let label: String
    let prompt: String

    var id: String { label }

    static let all: [WritingAction] = [
        WritingAction(icon: "wand.and.stars",                     label: "Improve",  prompt: "Improve and polish that. Show only the improved version."),
        WritingAction(icon: "arrow.up.left.and.arrow.down.right", label: "Expand",   prompt: "Expand on that with more detail and depth."),
        WritingAction(icon: "arrow.down.right.and.arrow.up.left", label: "Shorten",  prompt: "Make that more concise while keeping every key point."),
        WritingAction(icon: "theatermasks.fill",                   label: "Rephrase", prompt: "Rephrase that with a fresh angle and different wording."),
        WritingAction(icon: "text.append",                         label: "Continue", prompt: "Continue writing from where you left off."),
    ]
}

// MARK: - Conversation Mode Icon Inference

extension WritingMode {
    /// Infers a mode icon and color from a conversation title.
    /// Used in ConversationRow to show a contextual icon.
    static func inferIcon(from title: String) -> (name: String, color: Color)? {
        let lower = title.lowercased()
        if lower.contains("essay") {
            return ("doc.text", .blue)
        } else if lower.contains("story") || lower.contains("fiction") {
            return ("book.closed", .purple)
        } else if lower.contains("article") || lower.contains("blog") {
            return ("newspaper", .orange)
        } else if lower.contains("email") || lower.contains("mail") {
            return ("envelope", .green)
        } else if lower.contains("brainstorm") || lower.contains("idea") {
            return ("lightbulb", .yellow)
        } else if lower.contains("edit") || lower.contains("improve") || lower.contains("rewrite") {
            return ("wand.and.stars", .pink)
        }
        return nil
    }
}
