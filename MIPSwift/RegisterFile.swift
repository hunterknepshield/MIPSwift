//
//  RegisterFile.swift
//  MIPSwift
//
//  Created by Hunter Knepshield on 12/10/15.
//  Copyright © 2015 Hunter Knepshield. All rights reserved.
//

import Foundation

/// Representation of a register file inside a CPU.
class RegisterFile: CustomStringConvertible {
    // User-accessible registers
	/// $zero or $0, immutable.
    var zero: Int32 { get { return Int32.allZeros } }
	/// $at or $1, assembler temporary value.
    var at: Int32 = 0
	/// $v0 or $2, function return value.
    var v0: Int32 = 0
	/// $v1 or $3, function return value.
    var v1: Int32 = 0
	/// $a0 or $4, function argument value.
    var a0: Int32 = 0
	/// $a1 or $5, function argument value.
    var a1: Int32 = 0
	/// $a2 or $6, function argument value.
    var a2: Int32 = 0
	/// $a3 or $7, function argument value.
    var a3: Int32 = 0
	/// $t0 or $8, temporary value.
    var t0: Int32 = 0
	/// $t1 or $9, temporary value.
    var t1: Int32 = 0
	/// $t2 or $10, temporary value.
    var t2: Int32 = 0
	/// $t3 or $11, temporary value.
    var t3: Int32 = 0
	/// $t4 or $12, temporary value.
    var t4: Int32 = 0
	/// $t5 or $13, temporary value.
    var t5: Int32 = 0
	/// $t6 or $14, temporary value.
    var t6: Int32 = 0
	/// $t7 or $15, temporary value.
    var t7: Int32 = 0
	/// $s0 or $16, saved value.
    var s0: Int32 = 0
	/// $s1 or $17, saved value.
    var s1: Int32 = 0
	/// $s2 or $18, saved value.
    var s2: Int32 = 0
	/// $s3 or $19, saved value.
    var s3: Int32 = 0
	/// $s4 or $20, saved value.
    var s4: Int32 = 0
	/// $s5 or $21, saved value.
    var s5: Int32 = 0
	/// $s6 or $22, saved value.
    var s6: Int32 = 0
	/// $s7 or $23, saved value.
    var s7: Int32 = 0
	/// $t8 or $24, temporary value.
    var t8: Int32 = 0
	/// $t9 or $25, temporary value.
    var t9: Int32 = 0
	/// $k0 or $26, kernel reserved.
    var k0: Int32 = 0
	/// $k1 or $27, kernel reserved.
    var k1: Int32 = 0
	/// $gp or $28, global memory pointer.
    var gp: Int32 = 0
	/// $sp or $29, stack pointer.
    var sp: Int32 = 0
	/// $fp or $30, stack frame pointer.
    var fp: Int32 = 0
	/// $ra or $31, return address pointer.
    var ra: Int32 = 0
    // User-inaccessible registers
	/// Program counter
    var pc: Int32 = 0
	/// Hi
    var hi: Int32 = 0
	/// Lo
    var lo: Int32 = 0
	
	/// Get the value of a given register.
    func get(name: String) -> Int32 {
        switch(name) {
        case "$zero", "$0":
            return self.zero
        case "$at", "$1":
            return self.at
        case "$v0", "$2":
            return self.v0
        case "$v1", "$3":
            return self.v1
        case "$a0", "$4":
            return self.a0
        case "$a1", "$5":
            return self.a1
        case "$a2", "$6":
            return self.a2
        case "$a3", "$7":
            return self.a3
        case "$t0", "$8":
            return self.t0
        case "$t1", "$9":
            return self.t1
        case "$t2", "$10":
            return self.t2
        case "$t3", "$11":
            return self.t3
        case "$t4", "$12":
            return self.t4
        case "$t5", "$13":
            return self.t5
        case "$t6", "$14":
            return self.t6
        case "$t7", "$15":
            return self.t7
        case "$s0", "$16":
            return self.s0
        case "$s1", "$17":
            return self.s1
        case "$s2", "$18":
            return self.s2
        case "$s3", "$19":
            return self.s3
        case "$s4", "$20":
            return self.s4
        case "$s5", "$21":
            return self.s5
        case "$s6", "$22":
            return self.s6
        case "$s7", "$23":
            return self.s7
        case "$t8", "$24":
            return self.t8
        case "$t9", "$25":
            return self.t9
        case "$k0", "$26":
            return self.k0
        case "$k1", "$27":
            return self.k1
        case "$gp", "$28":
            return self.gp
        case "$sp", "$29":
            return self.sp
        case "$fp", "$30":
            return self.fp
        case "$ra", "$31":
            return self.ra
        case "$pc", "pc":
            return self.pc
        case "$hi", "hi":
            return self.hi
        case "$lo", "lo":
            return self.lo
        default:
            fatalError("Invalid register reference: \(name)")
        }
    }
	
	/// Set the value of a given register.
    func set(name: String, _ value: Int32) {
        switch(name) {
        case "$zero", "$0":
            fatalError("Cannot change immutable register $zero")
        case "$at", "$1":
            self.at = value
        case "$v0", "$2":
            self.v0 = value
        case "$v1", "$3":
            self.v1 = value
        case "$a0", "$4":
            self.a0 = value
        case "$a1", "$5":
            self.a1 = value
        case "$a2", "$6":
            self.a2 = value
        case "$a3", "$7":
            self.a3 = value
        case "$t0", "$8":
            self.t0 = value
        case "$t1", "$9":
            self.t1 = value
        case "$t2", "$10":
            self.t2 = value
        case "$t3", "$11":
            self.t3 = value
        case "$t4", "$12":
            self.t4 = value
        case "$t5", "$13":
            self.t5 = value
        case "$t6", "$14":
            self.t6 = value
        case "$t7", "$15":
            self.t7 = value
        case "$s0", "$16":
            self.s0 = value
        case "$s1", "$17":
            self.s1 = value
        case "$s2", "$18":
            self.s2 = value
        case "$s3", "$19":
            self.s3 = value
        case "$s4", "$20":
            self.s4 = value
        case "$s5", "$21":
            self.s5 = value
        case "$s6", "$22":
            self.s6 = value
        case "$s7", "$23":
            self.s7 = value
        case "$t8", "$24":
            self.t8 = value
        case "$t9", "$25":
            self.t9 = value
        case "$k0", "$26":
            self.k0 = value
        case "$k1", "$27":
            self.k1 = value
        case "$gp", "$28":
            self.gp = value
        case "$sp", "$29":
            self.sp = value
        case "$fp", "$30":
            self.fp = value
        case "$ra", "$31":
            self.ra = value
        case "$pc", "pc":
            self.pc = value
        case "$hi", "hi":
            self.hi = value
        case "$lo", "lo":
            self.lo = value
        default:
            fatalError("Invalid register reference: \(name)")
        }
    }
	
	/// The current formatting setting used in self.description.
    var printOption: PrintOption = .Hex
    var description: String {
        get {
            let format = printOption.rawValue
            var contents = "Register file contents:\n"
            contents += "$zero: \(zero.format(format))  $at: \(at.format(format))  $v0: \(v0.format(format))  $v1: \(v1.format(format))\n"
            contents += "  $a0: \(a0.format(format))  $a1: \(a1.format(format))  $a2: \(a2.format(format))  $a3: \(a3.format(format))\n"
            contents += "  $t0: \(t0.format(format))  $t1: \(t1.format(format))  $t2: \(t2.format(format))  $t3: \(t3.format(format))\n"
            contents += "  $t4: \(t4.format(format))  $t5: \(t5.format(format))  $t6: \(t6.format(format))  $t7: \(t7.format(format))\n"
            contents += "  $s0: \(s0.format(format))  $s1: \(s1.format(format))  $s2: \(s2.format(format))  $s3: \(s3.format(format))\n"
            contents += "  $s4: \(s4.format(format))  $s5: \(s5.format(format))  $s6: \(s6.format(format))  $s7: \(s7.format(format))\n"
            contents += "  $t8: \(t8.format(format))  $t9: \(t9.format(format))  $k0: \(k0.format(format))  $k1: \(k1.format(format))\n"
            contents += "  $gp: \(gp.format(format))  $sp: \(sp.format(format))  $fp: \(fp.format(format))  $ra: \(ra.format(format))\n"
            contents += "   pc: \(pc.format(format))   hi: \(hi.format(format))   lo: \(lo.format(format))"
            return contents
        }
    }
}