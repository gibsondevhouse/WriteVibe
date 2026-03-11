//
//  Item.swift
//  WriteVibe
//
//  Created by Christopher Gibson on 3/10/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
