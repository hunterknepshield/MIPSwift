//
//  Register.swift
//  MIPSwift
//
//  Created by Hunter Knepshield on 12/10/15.
//  Copyright © 2015 Hunter Knepshield. All rights reserved.
//

import Foundation

/// Representation of a MIPS register.
struct Register {
	/// The name of the register, e.g. $s0.
    var name: String
	var number: Int32 {
		get {
			switch(self.name) {
			case "$zero", "$0":
				return 0
			case "$at", "$1":
				return 1
			case "$v0", "$2":
				return 2
			case "$v1", "$3":
				return 3
			case "$a0", "$4":
				return 4
			case "$a1", "$5":
				return 5
			case "$a2", "$6":
				return 6
			case "$a3", "$7":
				return 7
			case "$t0", "$8":
				return 8
			case "$t1", "$9":
				return 9
			case "$t2", "$10":
				return 10
			case "$t3", "$11":
				return 11
			case "$t4", "$12":
				return 12
			case "$t5", "$13":
				return 13
			case "$t6", "$14":
				return 14
			case "$t7", "$15":
				return 15
			case "$s0", "$16":
				return 16
			case "$s1", "$17":
				return 17
			case "$s2", "$18":
				return 18
			case "$s3", "$19":
				return 19
			case "$s4", "$20":
				return 20
			case "$s5", "$21":
				return 21
			case "$s6", "$22":
				return 22
			case "$s7", "$23":
				return 23
			case "$t8", "$24":
				return 24
			case "$t9", "$25":
				return 25
			case "$k0", "$26":
				return 26
			case "$k1", "$27":
				return 27
			case "$gp", "$28":
				return 28
			case "$sp", "$29":
				return 29
			case "$fp", "$30":
				return 30
			case "$ra", "$31":
				return 31
			case "hi", "$hi", "lo", "$lo":
				return 0
			default:
				return -1
			}
		}
	}
	
    /// Attempt to initialize a register from a given name. Fails if the user is
	/// attempting to write to a register inaccessible to them.
    init?(_ name: String, writing: Bool, user: Bool = true) {
        if user && writing && immutableRegisters.contains(name) {
            // User is trying to use an immutable register as the destination of an instruction
            print("User may not modify register: \(name)")
            return nil
        }
        if user && uninstantiableRegisters.contains(name) {
            // User is trying to modify this register they can't access themselves (e.g. hi, pc)
            print("User may not access register: \(name)")
            return nil
        }
        if !validRegisters.contains(name) {
            print("Invalid register reference: \(name)")
            return nil
        }
        self.name = name
    }
}