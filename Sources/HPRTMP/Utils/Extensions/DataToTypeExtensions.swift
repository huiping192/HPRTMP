import Foundation

extension Data {
  var int: Int {
    return withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
      return ptr.load(as: Int.self)
    }
  }
  
  var uint8: UInt8 {
    return withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
      return ptr.load(as: UInt8.self)
    }
  }
  
  var uint16: UInt16 {
    return withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
      return ptr.load(as: UInt16.self)
    }
  }
  
  var int32: Int32 {
    return withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
      return ptr.load(as: Int32.self)
    }
  }
  
  var uint32: UInt32 {
    return withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
      return ptr.load(as: UInt32.self)
    }
  }
  
  var float: Float {
    return withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
      return ptr.load(as: Float.self)
    }
  }
  
  var double: Double {
    return withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
      return ptr.load(as: Double.self)
    }
  }
  
  var string: String {
    return String(data: self, encoding: .utf8) ?? ""
  }
}
