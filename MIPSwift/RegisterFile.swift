//
//  RegisterFile.swift
//  MIPSwift
//
//  Created by Hunter Knepshield on 12/10/15.
//  Copyright © 2015 Hunter Knepshield. All rights reserved.
//

import Foundation

struct RegisterFile: CustomStringConvertible {
    // User-accessible registers
    var zero: Int32 { get { return 0 } } // $0, immutable
    var at: Int32 = 0 // $1
    var v0: Int32 = 0 // $2
    var v1: Int32 = 0 // $3
    var a0: Int32 = 0 // $4
    var a1: Int32 = 0 // $5
    var a2: Int32 = 0 // $6
    var a3: Int32 = 0 // $7
    var t0: Int32 = 0 // $8
    var t1: Int32 = 0 // $9
    var t2: Int32 = 0 // $10
    var t3: Int32 = 0 // $11
    var t4: Int32 = 0 // $12
    var t5: Int32 = 0 // $13
    var t6: Int32 = 0 // $14
    var t7: Int32 = 0 // $15
    var s0: Int32 = 0 // $16
    var s1: Int32 = 0 // $17
    var s2: Int32 = 0 // $18
    var s3: Int32 = 0 // $19
    var s4: Int32 = 0 // $20
    var s5: Int32 = 0 // $21
    var s6: Int32 = 0 // $22
    var s7: Int32 = 0 // $23
    var t8: Int32 = 0 // $24
    var t9: Int32 = 0 // $25
    var k0: Int32 = 0 // $26
    var k1: Int32 = 0 // $27
    var gp: Int32 = 0 // $28
    var sp: Int32 = 0 // $29
    var fp: Int32 = 0 // $30
    var ra: Int32 = 0 // $31
    // User-inaccessible registers
    var pc: Int32 = 0
    var hi: Int32 = 0
    var lo: Int32 = 0
    
    func get(name: String) -> Int32 {
        // Get a register's value by its name or alias
        switch(name) {
        case "$zero", "$0":
            return zero
        case "$at", "$1":
            return at
        case "$v0", "$2":
            return v0
        case "$v1", "$3":
            return v1
        case "$a0", "$4":
            return a0
        case "$a1", "$5":
            return a1
        case "$a2", "$6":
            return a2
        case "$a3", "$7":
            return a3
        case "$t0", "$8":
            return t0
        case "$t1", "$9":
            return t1
        case "$t2", "$10":
            return t2
        case "$t3", "$11":
            return t3
        case "$t4", "$12":
            return t4
        case "$t5", "$13":
            return t5
        case "$t6", "$14":
            return t6
        case "$t7", "$15":
            return t7
        case "$s0", "$16":
            return s0
        case "$s1", "$17":
            return s1
        case "$s2", "$18":
            return s2
        case "$s3", "$19":
            return s3
        case "$s4", "$20":
            return s4
        case "$s5", "$21":
            return s5
        case "$s6", "$22":
            return s6
        case "$s7", "$23":
            return s7
        case "$t8", "$24":
            return t8
        case "$t9", "$25":
            return t9
        case "$k0", "$26":
            return k0
        case "$k1", "$27":
            return k1
        case "$gp", "$28":
            return gp
        case "$sp", "$29":
            return sp
        case "$fp", "$30":
            return fp
        case "$ra", "$31":
            return ra
        case "pc":
            return pc
        case "hi":
            return hi
        case "lo":
            return lo
        default:
            assertionFailure("Invalid register reference: \(name)")
            return INT32_MAX
        }
    }
    
    mutating func set(name: String, _ value: Int32) {
        // Set a register's value by its name or alias
        switch(name) {
        case "$zero", "$0":
            assertionFailure("Cannot change immutable register $zero")
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
        case "pc":
            self.pc = value
        case "hi":
            self.hi = value
        case "lo":
            self.lo = value
        default:
            assertionFailure("Invalid register reference: \(name)")
        }
    }
    
    let regFormat = "%08x"
    var description: String {
        get {
            var contents = "Register file contents:\n"
            contents += "$zero: \(zero.format(regFormat))  $at: \(at.format(regFormat))  $v0: \(v0.format(regFormat))  $v1: \(v1.format(regFormat))\n"
            contents += "  $a0: \(a0.format(regFormat))  $a1: \(a1.format(regFormat))  $a2: \(a2.format(regFormat))  $a3: \(a3.format(regFormat))\n"
            contents += "  $t0: \(t0.format(regFormat))  $t1: \(t1.format(regFormat))  $t2: \(t2.format(regFormat))  $t3: \(t3.format(regFormat))\n"
            contents += "  $t4: \(t4.format(regFormat))  $t5: \(t4.format(regFormat))  $t6: \(t6.format(regFormat))  $t7: \(t7.format(regFormat))\n"
            contents += "  $s0: \(s0.format(regFormat))  $s1: \(s1.format(regFormat))  $s2: \(s2.format(regFormat))  $s3: \(s3.format(regFormat))\n"
            contents += "  $s4: \(s4.format(regFormat))  $s5: \(s5.format(regFormat))  $s6: \(s6.format(regFormat))  $s7: \(s7.format(regFormat))\n"
            contents += "  $t8: \(t8.format(regFormat))  $t9: \(t9.format(regFormat))  $k0: \(k0.format(regFormat))  $k1: \(k1.format(regFormat))\n"
            contents += "  $gp: \(gp.format(regFormat))  $sp: \(sp.format(regFormat))  $fp: \(fp.format(regFormat))  $ra: \(ra.format(regFormat))\n"
            contents += "   pc: \(pc.format(regFormat))   hi: \(hi.format(regFormat))   lo: \(lo.format(regFormat))"
            return contents
        }
    }
}