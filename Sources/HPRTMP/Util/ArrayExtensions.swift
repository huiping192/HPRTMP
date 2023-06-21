//
//  File.swift
//  
//
//  Created by Huiping Guo on 2023/02/04.
//

import Foundation

public extension Array {
    subscript (safe range: CountableRange<Int>) -> ArraySlice<Element>? {

        if range.lowerBound < 0 || range.count > self.count {
            return nil
        }
        return self[range]
    }

    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
