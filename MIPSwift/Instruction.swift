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
    
    init(_ string: String) {
        let splitString = string.componentsSeparatedByCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        let strippedComponents = splitString.map({ $0.stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: validInstructionSeparators)) }) // Remove any punctuation specified in the valid separators string
        print(strippedComponents)
        let operation = Operation(rawValue: strippedComponents[0]) ?? Operation.Invalid
        
        switch(operation) {
        case .add: // All ALU-R operations
            let rd = Register(name: strippedComponents[1])
            let rs = Register(name: strippedComponents[2])
            let rt = Register(name: strippedComponents[3])
            self = Instruction.rType(operation, rd, rs, rt)
        case .addi: // All ALU-I operations
            let rt = Register(name: strippedComponents[1])
            let rs = Register(name: strippedComponents[2])
            let imm = Immediate(string: strippedComponents[3])
            self = Instruction.iType(operation, rt, rs, imm)
        case .li:
            let reg = Register(name: strippedComponents[1])
            let imm = Immediate(string: strippedComponents[2])
            self = Instruction.iType(Operation.addi, reg, zero, imm) // Transform to an addi
            // TODO memory
            // TODO jump
            // TODO branch
        case .Invalid:
            self = Instruction.Invalid(string)
        }
    }
}

struct Register {
    // Representation of a source/destination register
    var name: String
}

struct Immediate {
    // Representation of an immediate value
    var value: Int16 // Limited to 16 bits
    var signExtended: Int32 { get { return Int32(value) } }
    
    init(value: Int16) {
        self.value = value
    }
    
    init(string: String) {
        let immValue = Int16(string)
        if immValue == nil {
            assertionFailure("Unable to generate immediate value from string: \(string)")
        }
        self.value = immValue!
    }
}

struct Label {
    // Representation of a label
    var name: String
    var location: Int32 // Limited to 26 bits
}

enum Operation: String {
    // Representaiton of an opcode/function code
    
    // ALU-R operations
    case add = "add"
    
    // ALU-I operations
    case addi = "addi"
    
    // Memory operations
    
    // Pseudo-instructions
    case li = "li"
    
    // Catch-all case
    case Invalid = ""
}