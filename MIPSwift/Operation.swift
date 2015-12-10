//
//  Operation.swift
//  MIPSwift
//
//  Created by Hunter Knepshield on 12/10/15.
//  Copyright © 2015 Hunter Knepshield. All rights reserved.
//

import Foundation

enum OperationType {
    case ALUR
    case ALUI
    case Memory
    case Jump
    case Branch
    case ComplexInstruction
}

struct Operation {
    // Representaiton of an opcode/function code
    var name: String
    var type: OperationType
    var numRegisters: Int
    var numImmediates: Int
    var operation: ((Int32, Int32) -> Int32)?
    
    // Attempt to initialize an operation from a string; may fail
    init?(_ string: String) {
        self.name = string
        switch(string) {
            // ALU-R operations
        case "add":
            self.type = .ALUR
            self.operation = (+)
            self.numRegisters = 3
            self.numImmediates = 0
        case "sub":
            self.type = .ALUR
            self.operation = (-)
            self.numRegisters = 3
            self.numImmediates = 0
        case "and":
            self.type = .ALUR
            self.operation = (&)
            self.numRegisters = 3
            self.numImmediates = 0
        case "or":
            self.type = .ALUR
            self.operation = (|)
            self.numRegisters = 3
            self.numImmediates = 0
        case "xor":
            self.type = .ALUR
            self.operation = (^)
            self.numRegisters = 3
            self.numImmediates = 0
        case "slt":
            self.type = .ALUR
            self.operation = { return $0 < $1 ? 1 : 0 }
            self.numRegisters = 3
            self.numImmediates = 0
        case "sltu":
            self.type = .ALUR
            self.operation = { return UInt32($0) < UInt32($1) ? 1 : 0 }
            self.numRegisters = 3
            self.numImmediates = 0
        // ALU-I operations
        case "addi":
            self.type = .ALUI
            self.operation = (+)
            self.numRegisters = 2
            self.numImmediates = 1
        case "subi":
            self.type = .ALUI
            self.operation = (-)
            self.numRegisters = 2
            self.numImmediates = 1
        case "andi":
            self.type = .ALUI
            self.operation = (&)
            self.numRegisters = 2
            self.numImmediates = 1
        case "ori":
            self.type = .ALUI
            self.operation = (|)
            self.numRegisters = 2
            self.numImmediates = 1
        case "xori":
            self.type = .ALUI
            self.operation = (^)
            self.numRegisters = 2
            self.numImmediates = 1
        case "slti":
            self.type = .ALUI
            self.operation = { return $0 < $1 ? 1 : 0 }
            self.numRegisters = 2
            self.numImmediates = 1
        case "sltiu":
            self.type = .ALUI
            self.operation = { return UInt32($0) < UInt32($1) ? 1 : 0 }
            self.numRegisters = 2
            self.numImmediates = 1
        // Memory operations
            
        // More complex instructions, mostly pseudo-instructions
        case "li":
            self.type = .ComplexInstruction
            self.operation = (+)
            self.numRegisters = 1
            self.numImmediates = 1
        case "move", "mfhi", "mflo":
            self.type = .ComplexInstruction
            self.operation = (+)
            self.numRegisters = 2
            self.numImmediates = 0
        // Catch-all case for REPL to determine that this is an invalid instruction
        default:
            return nil
        }
    }
}