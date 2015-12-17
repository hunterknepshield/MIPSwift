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
	/// The 32-bit value with which operations can be performed.
    var signExtended: Int32 { get { return Int32(self.value) } }
	/// The unsigned 32-bit value that represents this immediate, used for
	/// determining the encoded value of an instruction.
	var unsignedExtended: UInt32 { get { return UInt32(UInt16(bitPattern: self.value)) } }
    
    /// Initialize an immediate value from an integer.
    init(value: Int16) {
        self.value = value
    }
    
    /// Attempt to initialize an immediate value from a string. May fail if the
	/// string is not a valid number that fits in a signed 16-bit
	/// representation.
    init?(_ string: String) {
		if let immValue = Int16(string) {
			// This was a regular decimal number
			self.value = immValue
		} else if valid16BitHexRegex.test(string) {
			// Attempt to read a hex value
			let scanner = NSScanner(string: args[0])
			let pointer = UnsafeMutablePointer<UInt32>.alloc(1)
			defer { pointer.dealloc(1) } // Called when execution leaves the current scope
			if scanner.scanHexInt(pointer) {
				// Safe to make an Int16 from this value; bit length already checked
				self.value = Int16(truncatingBitPattern: pointer.memory)
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