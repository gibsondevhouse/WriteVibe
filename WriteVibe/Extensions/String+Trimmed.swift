//
//  String+Trimmed.swift
//  WriteVibe
//

import Foundation

extension String {
    /// Trims leading and trailing whitespace and newlines.
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
