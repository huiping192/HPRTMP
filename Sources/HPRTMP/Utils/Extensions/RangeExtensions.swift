//
//  File.swift
//  
//
//  Created by Huiping Guo on 2023/02/04.
//

import Foundation
extension CountableClosedRange where Bound == Int {
    func shift(index: Int) -> CountableClosedRange<Int> {
        return self.lowerBound+index...self.upperBound+index
    }
}
extension CountableRange where Bound == Int {
    func shift(index: Int) -> CountableRange<Int> {
        return self.lowerBound+index..<self.upperBound+index
    }
}
