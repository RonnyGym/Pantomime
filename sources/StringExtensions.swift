//
// Created by Thomas Christensen on 24/08/16.
// Copyright (c) 2016 Nordija A/S. All rights reserved.
//

import Foundation

extension CharacterSet {
  static var whitespacesAndQuotes: CharacterSet {
    let quote = CharacterSet(charactersIn: "\"")

    return quote.union(.whitespaces)
  }
}

// Extend the String object with helpers
extension String {
  // String.replace(); similar to JavaScript's String.replace() and Ruby's String.gsub()
  func replace(_ pattern: String, replacement: String) throws -> String {
    let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])

    return regex.stringByReplacingMatches(
      in: self,
      options: [.withTransparentBounds],
      range: NSRange(location: 0, length: self.count),
      withTemplate: replacement
    )
  }

  func m3u8_parseLine() -> [String: String] {
    let pattern = "([^=\"]+|\"[^\"]+\")"
    guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
      return [:]
    }

    let parameters = self.split(separator: ",")

    let parametersMap = parameters.reduce([String: String]()) { (parametersMap, parameter) -> [String: String] in
      let parameterString = String(parameter)

      let parameterKeyValue =
        regex
          .matches(in: parameterString, options: [], range: NSRange(0..<parameterString.utf16.count))
          .map { (parameterString as NSString).substring(with: $0.range(at: 1)) }

      guard parameterKeyValue.count == 2 else {
        return parametersMap
      }

      let parameterKey = parameterKeyValue[0].unescaped.m3u8_trimmingWhiteSpacesAndQuotes
      let parameterValue = parameterKeyValue[1].unescaped.m3u8_trimmingWhiteSpacesAndQuotes

      var parametersMap = parametersMap
      parametersMap[parameterKey] = parameterValue
      return parametersMap
    }

    return parametersMap
  }

  var unescaped: String {
    let entities = ["\0", "\t", "\n", "\r", "\"", "\'", "\\"]
    var current = self
    for entity in entities {
      let descriptionCharacters = entity.debugDescription.dropFirst().dropLast()
      let description = String(descriptionCharacters)
      current = current.replacingOccurrences(of: description, with: entity)
    }
    return current
  }

  var m3u8_trimmingWhiteSpacesAndQuotes: String {
    return self.trimmingCharacters(in: CharacterSet.whitespacesAndQuotes)
  }
}
