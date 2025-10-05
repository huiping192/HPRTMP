//
//  TypeSafeIdentifiers.swift
//  HPRTMP
//
//  Type-safe wrappers for identifiers and timestamps
//

import Foundation

/// Message Stream ID
public struct MessageStreamId: Hashable, Sendable, CustomStringConvertible {
  public let value: Int

  public init(_ value: Int) {
    self.value = value
  }

  public var description: String {
    "MessageStreamId(\(value))"
  }
}

/// Chunk Stream ID
public struct ChunkStreamId: Hashable, Sendable, CustomStringConvertible {
  public let value: UInt16

  public init(_ value: UInt16) {
    self.value = value
  }

  public var description: String {
    "ChunkStreamId(\(value))"
  }
}

/// Timestamp
public struct Timestamp: Comparable, Sendable, CustomStringConvertible {
  public let value: UInt32

  public init(_ value: UInt32) {
    self.value = value
  }

  public static func + (lhs: Self, rhs: Self) -> Self {
    Self(lhs.value + rhs.value)
  }

  public static func - (lhs: Self, rhs: Self) -> Self {
    Self(lhs.value - rhs.value)
  }

  public static func += (lhs: inout Self, rhs: Self) {
    lhs = lhs + rhs
  }

  public static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.value < rhs.value
  }

  public var description: String {
    "\(value)ms"
  }
}

extension MessageStreamId {
  public static let zero = MessageStreamId(0)
}

extension ChunkStreamId {
  public static let zero = ChunkStreamId(0)
}

extension Timestamp {
  public static let zero = Timestamp(0)
  public static let max = Timestamp(16777215) // 0xFFFFFF
}
