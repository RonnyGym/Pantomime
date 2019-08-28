//
//  XKey.swift
//  Pantomime
//
//  Created by M Ivaniushchenko on 1/8/19.
//

import Foundation

public class XKey {
  public let method: String
  public let uri: String
  public let iv: Data?
  public let keyFormat: String?
  public let keyFormatVersions: String?
  
  public init(method: String, uri: String, iv: String?, keyFormat: String?, keyFormatVersions: String?) {
    self.method = method
    self.uri = uri
    self.iv = XKey.byteDataFromHexString(iv)
    self.keyFormat = keyFormat
    self.keyFormatVersions = keyFormatVersions
  }
  
  private static func byteDataFromHexString(_ hexString: String?) -> Data? {
    guard let byteArray = byteArrayFromHexString(hexString) else {
      return nil
    }
    
    return Data(byteArray)
  }
  
  private static func byteArrayFromHexString(_ hexString: String?) -> [UInt8]? {
    guard let hexString = hexString, hexString.starts(with: "0X") else {
      return nil
    }
    
    var result = [UInt8]()
    let pureHexString = hexString.replacingOccurrences(of: "0X", with: "")
    
    // Check that string has length of 32 characters, representing 16 bytes
    guard pureHexString.utf16.count == 32 else {
      return nil
    }
    
    for i in 0 ..< pureHexString.utf16.count/2 {
      // Iterate by 2 chars
      let offset = i * 2
      
      let startIndex = pureHexString.index(pureHexString.startIndex, offsetBy: offset)
      let endIndex = pureHexString.index(startIndex, offsetBy: 1)
      let charValue = byteFromHexChar(String(pureHexString[startIndex...endIndex]))
      result.append(charValue)
    }
    
    return result
  }
  
  private static func byteFromHexChar(_ hexChar: String) -> UInt8 {
    // hexChar is String with 2 hex symbols representing one byte,
    // for example "FF" = 255
    
    var value: UInt32 = 0
    let scanner = Scanner(string: hexChar)
    scanner.scanHexInt32(&value)
    return UInt8(value)
  }
}
