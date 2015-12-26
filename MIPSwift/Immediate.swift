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
	/// determining the encoded value of an instruction. This will always have
	/// 0s in the upper 2 bytes.
	var unsignedExtended: UInt32 { get { return UInt32(self.value.unsigned) } }
    
    /// Initialize an immediate value from an integer.
    init(_ value: Int16) {
        self.value = value
    }
	
	/// Attempt to initialize an immediate value from a string. May fail if the
	/// string is not a valid number, but will return two distinct values if the
	/// value supplied fits in a 32-bit integer and not a 16-bit integer.
	static func parseString(string: String, canReturnTwo: Bool) -> (lower: Immediate, upper: Immediate?)? {
		if let immValue = Int16(string) {
			// Preferentially generate a 16-bit value if possible before attempting to generate two values
			return (Immediate(immValue), nil)
		} else if let immValue = Int16(string.stringByReplacingOccurrencesOfString("0x", withString: ""), radix: 16) {
			// Was able to generate a number from hex
			return (Immediate(immValue), nil)
		} else if canReturnTwo, let twoImms = Int32(string) {
			// This value is a normal decimal number and fits within a 32-bit integer and we're allowed to make 2, split it up
			return (Immediate(Int16(truncatingBitPattern: twoImms & 0xFFFF)), Immediate(Int16(truncatingBitPattern: twoImms >> 16)))
		} else if canReturnTwo, let twoImms = Int32(string.stringByReplacingOccurrencesOfString("0x", withString: ""), radix: 16) {
			// Was able to generate a number from hex
			return (Immediate(Int16(truncatingBitPattern: twoImms & 0xFFFF)), Immediate(Int16(truncatingBitPattern: twoImms >> 16)))
		}
		// TODO implement basic math operations in immediate parsing, e.g. li	$t0, 4<<8
		// Unable to generate a decimal or hex value, 16 or 32 bits, time to just fail
		print("Invalid immediate value: \(string)")
		return nil
	}
}