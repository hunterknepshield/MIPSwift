//
//  StringExtension.swift
//  MIPSwift
//
//  Created by Hunter Knepshield on 12/10/15.
//  Copyright © 2015 Hunter Knepshield. All rights reserved.
//

import Foundation

enum StringParsingError: ErrorType { case InvalidEscape, InvalidDelimiter }

extension String {
    // Extend String to allow subscripting for easier input parsing
    subscript (i: Int) -> Character {
        return self[self.startIndex.advancedBy(i)]
    }
    
    subscript (i: Int) -> String {
        return String(self[i] as Character)
    }
    
    subscript (r: Range<Int>) -> String {
        return substringWithRange(Range(start: startIndex.advancedBy(r.startIndex), end: startIndex.advancedBy(r.endIndex)))
    }
    
    // Convert a string literal read in from input to use escape sequences
    func toStringWithEscapeSequences() throws -> String {
        var result = ""
        let escapeSequenceBeginning: Character = "\\"
        var isInEscapeSequence = false
        for (index, char) in self.characters.enumerate() {
            if isInEscapeSequence {
                isInEscapeSequence = false
                continue
            }
            if char == escapeSequenceBeginning {
                let next = self.characters[self.characters.startIndex.advancedBy(index + 1)]
                switch(next) {
                case "a":
                    result += "\\a"
                case "b":
                    result += "\\b"
                case "f":
                    result += "\\f"
                case "n":
                    result += "\n"
                case "r":
                    result += "\r"
                case "t":
                    result += "\t"
                case "v":
                    result += "\\v"
                case "\\":
                    result += "\\"
                case "'", "\'":
                    result += "'"
                case "\"":
                    result += "\""
                case "?":
                    result += "\\?"
                default:
                    print("Invalid escape sequence: \\\(next)")
                    throw StringParsingError.InvalidEscape
                }
                isInEscapeSequence = true
            } else {
                if char == "\"" {
                    // This character wasn't escaped, so fail
                    print("Invalid delimiter in string: \(self)")
                    throw StringParsingError.InvalidDelimiter
                }
                result += "\(char)"
            }
        }
        return result
    }
    
    // Convert a string to a string with literal escape sequences
    func toStringWithLiteralEscapes() -> String {
        var result = ""
        for char in self.characters {
            switch(char) {
            case "\n":
                result += "\\n"
            case "\r":
                result += "\\r"
            case "\t":
                result += "\\t"
            case "\\":
                result += "\\\\"
            case "'":
                result += "\\'"
            case "\"":
                result += "\\\""
            default:
                result += "\(char)"
            }
        }
        return result
    }
    
    // Axiom: self == self.toStringWithEscapeSequences().toStringWithLiteralEscapes()
}

extension Int32 {
    // Extend Int32 with the capability to format printing
    func format(f: String) -> String {
        if f == PrintOption.Binary.rawValue {
            // Manually format this string as binary
            let hexString = self.format(PrintOption.Hex.rawValue)
            var binaryString = ""
            for i in 0..<hexString.characters.count {
                let char: Character = hexString[i]
                switch(char) {
                case "0":
                    binaryString += "0000"
                case "1":
                    binaryString += "0001"
                case "2":
                    binaryString += "0010"
                case "3":
                    binaryString += "0011"
                case "4":
                    binaryString += "0100"
                case "5":
                    binaryString += "0101"
                case "6":
                    binaryString += "0110"
                case "7":
                    binaryString += "0111"
                case "8":
                    binaryString += "1000"
                case "9":
                    binaryString += "1001"
                case "a", "A":
                    binaryString += "1010"
                case "b", "B":
                    binaryString += "1011"
                case "c", "C":
                    binaryString += "1100"
                case "d", "D":
                    binaryString += "1101"
                case "e", "E":
                    binaryString += "1110"
                case "f", "F":
                    binaryString += "1111"
                default:
                    assertionFailure("Invalid character in hex string: \(char)")
                }
            }
            return binaryString
        } else {
            return NSString(format: f, self) as String
        }
    }
    
    // Just a convenience function to reduce character counts
    func toHexWith0x() -> String {
        return self.format(PrintOption.HexWith0x.rawValue)
    }
}

extension Int16 {
    // Extend Int16 with the capability to format printing
    func format(f: String) -> String {
        return NSString(format: f, self) as String
    }
}