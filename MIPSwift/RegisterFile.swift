//
//  RegisterFile.swift
//  MIPSwift
//
//  Created by Hunter Knepshield on 12/10/15.
//  Copyright © 2015 Hunter Knepshield. All rights reserved.
//

import Foundation

struct RegisterFile {
    var zero: Int32 {
        get {
            return 0
        }
    } // $0, immutable
    var at: Int32 // $1
    var v0: Int32 // $2
    var v1: Int32 // $3
    var a0: Int32 // $4
    var a1: Int32 // $5
    var a2: Int32 // $6
    var a3: Int32 // $7
    var t0: Int32 // $8
    var t1: Int32 // $9
    var t2: Int32 // $10
    var t3: Int32 // $11
    var t4: Int32 // $12
    var t5: Int32 // $13
    var t6: Int32 // $14
    var t7: Int32 // $15
    var s0: Int32 // $16
    var s1: Int32 // $17
    var s2: Int32 // $18
    var s3: Int32 // $19
    var s4: Int32 // $20
    var s5: Int32 // $21
    var s6: Int32 // $22
    var s7: Int32 // $23
    var t8: Int32 // $24
    var t9: Int32 // $25
    var k0: Int32 // $26
    var k1: Int32 // $27
    var gp: Int32 // $28
    var sp: Int32 // $29
    var fp: Int32 // $30
    var ra: Int32 // $31
}