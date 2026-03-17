//
//  Item.swift
//  Monet
//
//  Created by luke on 2025/11/8.
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
