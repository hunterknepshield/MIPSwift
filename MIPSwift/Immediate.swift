//
//  Immediate.swift
//  MIPSwift
//
//  Created by Hunter Knepshield on 12/10/15.
//  Copyright © 2015 Hunter Knepshield. All rights reserved.
//

import Foundation

/// Representation of an immediate value.
struct Immediate {
	/// Limited to 16 bits by the structure of MIPS instructions themselves.
    var value: Int16
	/// The unsigned representation of this immediate
	var unsignedValue: UInt16 { get { return UInt16(bitPattern: self.value) } }
	/// The 32-bit value with which operations can be performed.
	var signExtended: Int32 { get { return Int32(self.value) } }
	/// The unsigned 32-bit value that represents this immediate, used for
	/// determining the encoded value of an instruction. This will always have
	/// 0s in the upper 2 bytes.
	var unsignedExtended: UInt32 { get { return UInt32(self.unsignedValue) } }
    
    /// Initialize an immediate value from an integer.
    init(_ value: Int16) {
        self.value = value
    }
	
	/// Attempt to initialize an immediate value from a string. May fail if the
	/// string is not a valid number, but will return two distinct values if the
	/// value supplied fits in a 32-bit representation, but not a 16-bit
	/// representation.
	static func parseString(string: String, canReturnTwo: Bool) -> (lower: Immediate, upper: Immediate?)? {
		if canReturnTwo, let twoImms = Int32(string) {
			// This value is a normal decimal number and fits within a 32-bit integer and we're allowed to make 2, split it up
			return (Immediate(Int16(truncatingBitPattern: twoImms & 0xFFFF)), Immediate(Int16(truncatingBitPattern: twoImms >> 16)))
		} else if let immValue = Int16(string) {
			// This value is a normal decimal number and fits within a 16-bit integer
			return (Immediate(immValue), nil)
		} else {
			// Attempt to parse hexadecimal if possible, otherwise fail
			if valid16BitHexRegex.test(string) {
				// This should fit within a 16-bit integer
				let scanner = NSScanner(string: string)
				let pointer = UnsafeMutablePointer<UInt32>.alloc(1)
				defer { pointer.dealloc(1) } // Called when execution leaves the current scope
				if scanner.scanHexInt(pointer) {
					// Safe to make an Int16 from this value; bit length already checked
					return (Immediate(Int16(truncatingBitPattern: pointer.memory)), nil)
				} else {
					print("Unable to create immediate value from string: \(string)")
					return nil
				}
			} else if canReturnTwo && valid32BitHexRegex.test(string) {
				// This should fit within a 32-bit integer, and we're allowed to make 2
				let scanner = NSScanner(string: string)
				let pointer = UnsafeMutablePointer<UInt32>.alloc(1)
				defer { pointer.dealloc(1) } // Called when execution leaves the current scope
				if scanner.scanHexInt(pointer) {
					// Safe to make an Int32 from this value; bit length already checked
					let twoImms = Int32(bitPattern: pointer.memory)
					return (Immediate(Int16(truncatingBitPattern: twoImms & 0xFFFF)), Immediate(Int16(truncatingBitPattern: twoImms >> 16)))
				} else {
					print("Unable to create immediate value from string: \(string)")
					return nil
				}
			} else {
				print("Unable to create immediate value from string: \(string)")
				return nil
			}
		}
	}
}