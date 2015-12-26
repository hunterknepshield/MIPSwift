//
//  Register.swift
//  MIPSwift
//
//  Created by Hunter Knepshield on 12/10/15.
//  Copyright © 2015 Hunter Knepshield. All rights reserved.
//

import Foundation

/// Representation of a MIPS register. Raw values are the numeric representation
/// of the register. If the register cannot be represented numerically, its raw
/// value will be negative.
enum Register: Int32 {
	case zero = 0
	case at
	case v0
	case v1
	case a0
	case a1
	case a2
	case a3
	case t0
	case t1
	case t2
	case t3
	case t4
	case t5
	case t6
	case t7
	case s0
	case s1
	case s2
	case s3
	case s4
	case s5
	case s6
	case s7
	case t8
	case t9
	case k0
	case k1
	case gp
	case sp
	case fp
	case ra
	case hi = -1
	case lo = -2
	case pc = -3
	
	/// The name of the register, e.g. $s0.
	var name: String {
		get {
			if self.rawValue >= 0 {
				// This is one of the user-accessible registers
				return validRegisters[Int(self.rawValue)*2]
			} else {
				// This is one of the uninstantiable registers: hi, lo, pc
				switch(self.rawValue) {
				case -1:
					return "hi"
				case -2:
					return "lo"
				case -3:
					return "pc"
				default:
					fatalError("Invalid register: \(self)")
				}
			}
		}
	}
	
	/// Attempt to initialize a register from a given name. Fails if the user is
	/// attempting to write to a register inaccessible to them, or the supplied
	/// register name is invalid.
	init?(_ name: String, writing: Bool, user: Bool = true) {
		switch(name) {
		case "$zero", "$0":
			if user && writing {
				// User is trying to use $zero as the destination of an instruction
				print("User may not modify register: \(name)")
				return nil
			}
			self = .zero
		case "$at", "$1":
			self = .at
		case "$v0", "$2":
			self = .v0
		case "$v1", "$3":
			self = .v1
		case "$a0", "$4":
			self = .a0
		case "$a1", "$5":
			self = .a1
		case "$a2", "$6":
			self = .a2
		case "$a3", "$7":
			self = .a3
		case "$t0", "$8":
			self = .t0
		case "$t1", "$9":
			self = .t1
		case "$t2", "$10":
			self = .t2
		case "$t3", "$11":
			self = .t3
		case "$t4", "$12":
			self = .t4
		case "$t5", "$13":
			self = .t5
		case "$t6", "$14":
			self = .t6
		case "$t7", "$15":
			self = .t7
		case "$s0", "$16":
			self = .s0
		case "$s1", "$17":
			self = .s1
		case "$s2", "$18":
			self = .s2
		case "$s3", "$19":
			self = .s3
		case "$s4", "$20":
			self = .s4
		case "$s5", "$21":
			self = .s5
		case "$s6", "$22":
			self = .s6
		case "$s7", "$23":
			self = .s7
		case "$t8", "$24":
			self = .t8
		case "$t9", "$25":
			self = .t9
		case "$k0", "$26":
			self = .k0
		case "$k1", "$27":
			self = .k1
		case "$gp", "$28":
			self = .gp
		case "$sp", "$29":
			self = .sp
		case "$fp", "$30":
			self = .fp
		case "$ra", "$31":
			self = .ra
		case "hi", "$hi":
			if user {
				print("User may not access register: \(name)")
				return nil
			}
			self = .hi
		case "lo", "$lo":
			if user {
				print("User may not access register: \(name)")
				return nil
			}
			self = .lo
		case "pc", "$pc":
			if user {
				print("User may not access register: \(name)")
				return nil
			}
			self = .pc
		default:
			print("Invalid register reference: \(name)")
			return nil
		}
	}
}