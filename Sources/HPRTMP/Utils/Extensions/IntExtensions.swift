//
//  File.swift
//  
//
//  Created by Huiping Guo on 2022/10/24.
//

import Foundation

extension ExpressibleByIntegerLiteral {
  var data: Data {
         var value: Self = self
         return Data(bytes: &value, count: MemoryLayout<Self>.size)
     }
}
