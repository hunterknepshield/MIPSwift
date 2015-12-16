//
//  StringExtension.swift
//  MIPSwift
//
//  Created by Hunter Knepshield on 12/10/15.
//  Copyright © 2015 Hunter Knepshield. All rights reserved.
//

import Foundation

enum StringParsingError: ErrorType { case InvalidEscape, InvalidDelimiter }

// MARK: String subscripting

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

// MARK: Convenience print formatting for integer types

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
                    fatalError("Invalid character in hex string: \(char)")
                }
            }
            return binaryString
        } else {
            return NSString(format: f, self) as String
        }
    }
    
    // Just a convenience function to reduce character counts
    func toHexWith0x() -> String {
        if self == 0 {
            return "0x00000000"
        }
        return self.format(PrintOption.HexWith0x.rawValue)
    }
}

extension Int16 {
    // Extend Int16 with the capability to format printing
    func format(f: String) -> String {
        return NSString(format: f, self) as String
    }
}

// MARK: Convenience method to convert unsigned 8-bit integers to printable characters

extension UInt8 {
	func toPrintableCharacter() -> Character {
		switch(self) {
		case 0...31, 127:
			return "." // Mostly things that need escaping; can't print
		case 32...126:
			return Character(UnicodeScalar(self))
		default:
			return "." // Extended ASCII junk
		}
	}
}

// MARK: Convenience conversions between signed/unsigned/different bitlength integer types

extension Int32 {
    // Quick way to convert to an unsigned 32-bit representation
    func unsigned() -> UInt32 {
        return UInt32(bitPattern: self)
    }
    
    // Quick way to convert to a signed 64-bit representation
    func signed64() -> Int64 {
        return Int64(self)
    }
    
    // Quick way to convert to an unsigned 64-bit representation
    func unsigned64() -> UInt64 {
        return UInt64(bitPattern: self.signed64())
    }
    
    // Quick accessors for any byte of self as unsigned an 8-bit integer
    func unsignedLowest8() -> UInt8 {
        return UInt8(truncatingBitPattern: self.unsigned())
    }
    
    func unsignedLower8() -> UInt8 {
        return UInt8(truncatingBitPattern: self.unsigned() >> 8)
    }
    
    func unsignedHigher8() -> UInt8 {
        return UInt8(truncatingBitPattern: self.unsigned() >> 16)
    }
    
    func unsignedHighest8() -> UInt8 {
        return UInt8(truncatingBitPattern: self.unsigned() >> 24)
    }
    
    // Quick accessor for all bytes of self as unsigned 8-bit integers
    func toBytes() -> (highest: UInt8, higher: UInt8, lower: UInt8, lowest: UInt8) {
        return (self.unsignedHighest8(), self.unsignedHigher8(), self.unsignedLower8(), self.unsignedLowest8())
    }
    
    // New constructor to create a 32-bit signed integer from 4 unsigned 8-bit integers
    init(highest: UInt8, higher: UInt8, lower: UInt8, lowest: UInt8) {
        self = (Int32(highest) << 24) | (Int32(higher) << 16) | (Int32(lower) << 8) | Int32(lowest)
    }
}

extension UInt32 {
    // Quick way to convert to a signed 32-bit representation
    func signed() -> Int32 {
        return Int32(bitPattern: self)
    }
    
    // Other methods can be accessed through UInt32.signed().[signed64(), unsigned64()]
}

extension Int64 {
    // Quick way to convert to an unsigned 64-bit representation
    func unsigned() -> UInt64 {
        return UInt64(bitPattern: self)
    }

    // Quick way to convert lower 32 bits to an unsigned 32-bit representation
    func unsignedLower32() -> UInt32 {
        return UInt32(truncatingBitPattern: self.unsigned())
    }
    
    // Quick way to convert lower 32 bits to a signed 32-bit representation
    func signedLower32() -> Int32 {
        return self.unsignedLower32().signed()
    }
    
    // Quick way to convert upper 32 bits to an unsigned 32-bit representation
    func unsignedUpper32() -> UInt32 {
        return UInt32(truncatingBitPattern: self.unsigned() >> 32)
    }
    
    // Quick way to convert upper 32 bits to a signed 32-bit representation
    func signedUpper32() -> Int32 {
        return self.unsignedUpper32().signed()
    }
}

extension UInt64 {
    // Quick way to convert to a signed 64-bit representation
    func signed() -> Int64 {
        return Int64(bitPattern: self)
    }
    
    // Other methods can be accessed through UInt64.signed().[unsignedLower32(), signedLower32(), unsignedUpper32(), signedUpper32()]
}