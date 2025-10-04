import Foundation

/// Unified AMF value type supporting both AMF0 and AMF3 protocols
public enum AMFValue: Sendable {
  case double(Double)
  case int(Int)              // AMF3 only
  case bool(Bool)
  case string(String)
  case null
  case undefined             // AMF3 only
  case date(Date)
  case object([String: AMFValue])
  case array([AMFValue])
  case byteArray(Data)       // AMF3 only
  case vectorInt([Int32])    // AMF3 only
  case vectorUInt([UInt32])  // AMF3 only
  case vectorDouble([Double]) // AMF3 only
  case vectorObject([AMFValue]) // AMF3 only
}

extension AMFValue: Equatable {
  public static func == (lhs: AMFValue, rhs: AMFValue) -> Bool {
    switch (lhs, rhs) {
    case (.double(let a), .double(let b)): return a == b
    case (.int(let a), .int(let b)): return a == b
    case (.bool(let a), .bool(let b)): return a == b
    case (.string(let a), .string(let b)): return a == b
    case (.null, .null): return true
    case (.undefined, .undefined): return true
    case (.date(let a), .date(let b)): return a == b
    case (.object(let a), .object(let b)): return a == b
    case (.array(let a), .array(let b)): return a == b
    case (.byteArray(let a), .byteArray(let b)): return a == b
    case (.vectorInt(let a), .vectorInt(let b)): return a == b
    case (.vectorUInt(let a), .vectorUInt(let b)): return a == b
    case (.vectorDouble(let a), .vectorDouble(let b)): return a == b
    case (.vectorObject(let a), .vectorObject(let b)): return a == b
    default: return false
    }
  }
}

// MARK: - Value extraction helpers for backward compatibility with tests
extension AMFValue {
  /// Extract as Double (for AMF0 number type)
  public var doubleValue: Double? {
    if case .double(let value) = self { return value }
    return nil
  }

  /// Extract as Int (for AMF3 int type)
  public var intValue: Int? {
    if case .int(let value) = self { return value }
    return nil
  }

  /// Extract as Bool
  public var boolValue: Bool? {
    if case .bool(let value) = self { return value }
    return nil
  }

  /// Extract as String
  public var stringValue: String? {
    if case .string(let value) = self { return value }
    if case .null = self { return "null" }  // For backward compatibility with AMF0 null
    return nil
  }

  /// Extract as Date
  public var dateValue: Date? {
    if case .date(let value) = self { return value }
    return nil
  }

  /// Extract as Object
  public var objectValue: [String: AMFValue]? {
    if case .object(let value) = self { return value }
    return nil
  }

  /// Extract as Array
  public var arrayValue: [AMFValue]? {
    if case .array(let value) = self { return value }
    return nil
  }

  /// Extract as Data
  public var dataValue: Data? {
    if case .byteArray(let value) = self { return value }
    return nil
  }

  /// Convert AMFValue to Any for backward compatibility
  public func toAny() -> Any {
    switch self {
    case .double(let value): return value
    case .int(let value): return value
    case .bool(let value): return value
    case .string(let value): return value
    case .null: return "null"
    case .undefined: return "undefined"
    case .date(let value): return value
    case .object(let dict): return dict.mapValues { $0.toAny() }
    case .array(let arr): return arr.map { $0.toAny() }
    case .byteArray(let value): return value
    case .vectorInt(let value): return value
    case .vectorUInt(let value): return value
    case .vectorDouble(let value): return value
    case .vectorObject(let arr): return arr.map { $0.toAny() }
    }
  }
}
