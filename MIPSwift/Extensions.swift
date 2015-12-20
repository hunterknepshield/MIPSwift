//
//  StringExtension.swift
//  MIPSwift
//
//  Created by Hunter Knepshield on 12/10/15.
//  Copyright © 2015 Hunter Knepshield. All rights reserved.
//

import Foundation

// MARK: String subscripting

extension String {
	/// Get the ith element of self as a Character.
    subscript(i: Int) -> Character {
        return self[self.startIndex.advancedBy(i)]
    }
	
	/// Get the ith element of self as a String.
    subscript(i: Int) -> String {
        return String(self[i] as Character)
    }
	
	/// Get a range of elements of self as a string.
    subscript(r: Range<Int>) -> String {
        return substringWithRange(Range(start: startIndex.advancedBy(r.startIndex), end: startIndex.advancedBy(r.endIndex)))
    }
}

extension String {
    /// Convert a string literal read in from input to one that contains escape
	/// sequences for storing. E.g. "This is\\ a literal\twith escapes.\n"
	/// becomes "This is\ a literal	with escapes.
	///
	/// " Fails if the literal contains any invalid delimiters or contains an
	/// escape that is not completed.
	///
	/// Axiom: self == self.compressedEscapes.expandedEscapes
	var compressedEscapes: String? {
		get {
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
					case "0":
						result += "\0"
					default:
						// Invalid/incomplete escape sequence, e.g. "\ ", "\1", or "\Q"
						return nil
					}
					isInEscapeSequence = true
				} else if char == "\"" {
					// This character wasn't escaped, so fail
					return nil
				} else {
					result += "\(char)"
				}
			}
			return result
		}
	}
	
	/// Convert a string to a literal with escape sequences expanded. E.g.
	/// "This is\\ a literal with
	///
	/// escapes." becomes "This is\\\\ a literal with\nescapes."
	///
	/// Axiom: self == self.compressedEscapes.expandedEscapes
	var expandedEscapes: String {
		get { return self.unicodeScalars.map({ return $0.escape(asASCII: true) }).joinWithSeparator("") }
	}
}

// MARK: Convenience print formatting for integer types

extension Int32 {
    /// Format self as specified by a given format string.
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
    
    /// Convenience variable of self formatted as hexadecimal with a leading 0x.
	var hexWith0x: String {
		get {
			if self == 0 { return "0x00000000" }
			return self.format(PrintOption.HexWith0x.rawValue)
		}
	}
}

extension Int16 {
	/// Format self as specified by a given format string.
    func format(f: String) -> String {
        return NSString(format: f, self) as String
    }
}

// MARK: Convenience method to convert unsigned 8-bit integer to printable characters

extension UInt8 {
	/// Convert self to a printable character, or '•' if an ASCII character with
	/// a numeric value of self wouldn't be printable in a single space.
	var printableCharacter: Character {
		get {
			switch(self) {
			case 0...31, 127:
				return "•" // Mostly things that need escaping; can't print
			case 32...126:
				return Character(UnicodeScalar(self))
			default:
				return "•" // Extended ASCII junk
			}
		}
	}
}

// MARK: Convenience conversion between integer types

extension Int16 {
	// Quick way to convert to an unsigned 16-bit representation of self.
	var unsigned: UInt16 { get { return UInt16(bitPattern: self) } }
	
	/// Quick accessor for the lower byte of self as an unsigned 8-bit integer.
	var lowerByte: UInt8 { get { return UInt8(truncatingBitPattern: self.unsigned) } }
	
	/// Quick accessor for the upper byte of self as an unsigned 8-bit integer.
	var upperByte: UInt8 { get { return UInt8(truncatingBitPattern: self.unsigned >> 8) } }
}

extension Int32 {
    /// Quick way to convert to an unsigned 32-bit representation of self.
	var unsigned: UInt32 { get { return UInt32(bitPattern: self) } }
	
    /// Quick way to convert to a signed 64-bit representation of self.
	var signed64: Int64 { get { return Int64(self) } }
	
    /// Quick way to convert to an unsigned 64-bit representation of self.
	var unsigned64: UInt64 { get { return UInt64(bitPattern: self.signed64) } }
	
    /// Quick accessor for the lowest byte of self as unsigned an 8-bit integer.
	var lowestByte: UInt8 { get {return UInt8(truncatingBitPattern: self.unsigned) } }
	
	/// Quick accessor for the lower byte of self as unsigned an 8-bit integer.
	var lowerByte: UInt8 { get { return UInt8(truncatingBitPattern: self.unsigned >> 8)} }

	/// Quick accessor for the higher byte of self as unsigned an 8-bit integer.
	var higherByte: UInt8 { get { return UInt8(truncatingBitPattern: self.unsigned >> 16) } }
	
	/// Quick accessor for the highest byte of self as unsigned an 8-bit
	/// integer.
	var highestByte: UInt8 { get { return UInt8(truncatingBitPattern: self.unsigned >> 24) } }
	
    /// Create a 32-bit signed integer from 4 unsigned 8-bit integers.
    init(highest: UInt8, higher: UInt8, lower: UInt8, lowest: UInt8) {
        self = (Int32(highest) << 24) | (Int32(higher) << 16) | (Int32(lower) << 8) | Int32(lowest)
    }
}

extension UInt32 {
    /// Quick way to convert to a signed 32-bit representation of self.
	var signed: Int32 { get { return Int32(bitPattern: self) } }
}

extension Int64 {
    /// Quick way to convert to an unsigned 64-bit representation of self.
	var unsigned: UInt64 { get { return UInt64(bitPattern: self) } }

    /// Quick way to convert lower 32 bits of self to an unsigned 32-bit
	/// representation.
	var unsignedLower32: UInt32 { get { return UInt32(truncatingBitPattern: self.unsigned) } }
    
    /// Quick way to convert lower 32 bits of self to a signed 32-bit
	/// representation.
	var signedLower32: Int32 { get { return self.unsignedLower32.signed } }
    
    /// Quick way to convert upper 32 bits of self to an unsigned 32-bit
	/// representation.
	var unsignedUpper32: UInt32 { get { return UInt32(truncatingBitPattern: self.unsigned >> 32) } }
    
    /// Quick way to convert upper 32 bits of self to a signed 32-bit
	/// representation.
	var signedUpper32: Int32 { get { return self.unsignedUpper32.signed } }
}

extension UInt64 {
    /// Quick way to convert to a signed 64-bit representation of self.
	var signed: Int64 { get { return Int64(bitPattern: self) } }
}