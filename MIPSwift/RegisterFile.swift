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
        case "pc":
            return self.pc
        case "hi":
            return self.hi
        case "lo":
            return self.lo
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
    
    let hexFormat = "%08x"
    let decimalFormat = "%010d"
    var printHex = true
    var description: String {
        get {
            let format = self.printHex ? self.hexFormat : self.decimalFormat
            var contents = "Register file contents:\n"
            contents += "$zero: \(zero.format(format))  $at: \(at.format(format))  $v0: \(v0.format(format))  $v1: \(v1.format(format))\n"
            contents += "  $a0: \(a0.format(format))  $a1: \(a1.format(format))  $a2: \(a2.format(format))  $a3: \(a3.format(format))\n"
            contents += "  $t0: \(t0.format(format))  $t1: \(t1.format(format))  $t2: \(t2.format(format))  $t3: \(t3.format(format))\n"
            contents += "  $t4: \(t4.format(format))  $t5: \(t4.format(format))  $t6: \(t6.format(format))  $t7: \(t7.format(format))\n"
            contents += "  $s0: \(s0.format(format))  $s1: \(s1.format(format))  $s2: \(s2.format(format))  $s3: \(s3.format(format))\n"
            contents += "  $s4: \(s4.format(format))  $s5: \(s5.format(format))  $s6: \(s6.format(format))  $s7: \(s7.format(format))\n"
            contents += "  $t8: \(t8.format(format))  $t9: \(t9.format(format))  $k0: \(k0.format(format))  $k1: \(k1.format(format))\n"
            contents += "  $gp: \(gp.format(format))  $sp: \(sp.format(format))  $fp: \(fp.format(format))  $ra: \(ra.format(format))\n"
            contents += "   pc: \(pc.format(format))   hi: \(hi.format(format))   lo: \(lo.format(format))"
            return contents
        }
    }
}