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
    var zero: Int32 {
        get {
            return 0
        }
    } // $0, immutable
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
    
    let regFormat: String = "%08x"
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