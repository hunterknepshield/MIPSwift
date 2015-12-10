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
    
    init(_ string: String, _ verbose: Bool) {
        let splitString = string.componentsSeparatedByCharactersInSet(NSCharacterSet.whitespaceCharacterSet()) // Split this instruction on any whitespace (not including newlines)
        let strippedComponents = splitString.map({ $0.stringByTrimmingCharactersInSet(validInstructionSeparatorsCharacterSet) }) // Remove any punctuation specified in the valid separators string
        
        if verbose {
            print(strippedComponents)
        }
        
        // TODO implement labels
        // Check if strippedComponents[0] has a colon at the end here,
        // then remove it from the array and continue parsing
        
        // TODO implement comments
        // Check if strippedComponents[i] begins with a hashtag (wow, I did just call it a hashtag instead of a pound sign),
        // then remove it and any subsequent elements from the array and continue parsing
        
        let operation = Operation(rawValue: strippedComponents[0]) ?? Operation.Invalid

        // Essentially, this is the decode phase
        switch(operation) {
        case .add: // All ALU-R operations of format op, rd, rs, rt
            let rd = Register(name: strippedComponents[1])
            let rs = Register(name: strippedComponents[2])
            let rt = Register(name: strippedComponents[3])
            self = Instruction.rType(operation, rd, rs, rt)
        case .addi: // All ALU-I operations of format op, rt, rs, imm
            let rt = Register(name: strippedComponents[1])
            let rs = Register(name: strippedComponents[2])
            let imm = Immediate(string: strippedComponents[3])
            self = Instruction.iType(operation, rt, rs, imm)
        case .li:
            let rt = Register(name: strippedComponents[1])
            let imm = Immediate(string: strippedComponents[2])
            self = Instruction.iType(Operation.addi, rt, zero, imm) // Transform to an addi ($rt = $zero + imm)
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
    
    // Initialize an immediate value from an integer
    init(value: Int16) {
        self.value = value
    }
    
    // Attempt to initialize an immediate value from a string; may assert fail
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
    var location: Int32
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
    
    // Catch-all case for the REPL to determine that this is an invalid
    case Invalid = ""
}