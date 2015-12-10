//
//  Instruction.swift
//  MIPSwift
//
//  Created by Hunter Knepshield on 12/10/15.
//  Copyright © 2015 Hunter Knepshield. All rights reserved.
//

import Foundation

enum Instruction {
    // Representations of each type of MIPS instruction
    case rType(Operation, Register, Register, Register) // op, rd, rs, rt
    case iType(Operation, Register, Register, Immediate) // op, rt, rs, imm
    case jType(Operation, Label) // op, target
    case Invalid(String) // Invalid instruction
}

struct Register {
    // Representation of a source/destination register
    var name: String
}

struct Immediate {
    // Representation of an immediate value
    var value: Int16 // Limited to 16 bits
}

struct Label {
    // Representation of a label
    var name: String
    var location: Int32 // Limited to 26 bits
}

enum Operation: String {
    // Representaiton of an opcode/function code
    
    // ALU-R operations
    case Add = "add"
    
    // ALU-I operations
    
    // Memory operations
    
    // Pseudo-instructions
    
    // Catch-all case
    case Invalid = ""
}