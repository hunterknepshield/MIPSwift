//
//  Operation.swift
//  MIPSwift
//
//  Created by Hunter Knepshield on 12/10/15.
//  Copyright © 2015 Hunter Knepshield. All rights reserved.
//

import Foundation

// Representaiton of an opcode/function code
enum OperationType {
    case ALUR
    case ALUI
    case Memory
    case Jump
    case Branch
    case ComplexInstruction
    case Directive
    case Syscall
}

struct Operation {
    let name: String
    let type: OperationType
    let numRegisters: Int
    let numImmediates: Int
    var operation: ((Int32, Int32) -> Int32)?
    var bigOperation: ((Int32, Int32) -> Int64)?
    var pcIncrement: Int32 = 4 // All simple instructions increment pc by 4; some increment by more
    
    // Attempt to initialize an operation from a string; will fail if instruction is invalid or unimplemented
    init?(_ string: String) {
        self.name = string
        if string[0] == directiveBeginning {
            // This is a dot directive; don't parse any further
            self.numImmediates = 0
            self.numRegisters = 0
            self.type = .Directive
            return
        }
        
        switch(string) {
        // ALU-R operations
        case "add":
            self.type = .ALUR
            self.operation = (+)
            self.numRegisters = 3
            self.numImmediates = 0
        case "addu":
            self.type = .ALUR
            self.operation = { return Int32((UInt32($0) + UInt32($1)).value) }
            self.numRegisters = 3
            self.numImmediates = 0
        case "sub":
            self.type = .ALUR
            self.operation = (-)
            self.numRegisters = 3
            self.numImmediates = 0
        case "subu":
            self.type = .ALUR
            self.operation = { return Int32((UInt32($0) - UInt32($1)).value) }
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
        case "sllv":
            self.type = .ALUR
            self.operation = { return $0 << $1 }
            self.numRegisters = 3
            self.numImmediates = 0
        // ALU-I operations
        case "addi":
            self.type = .ALUI
            self.operation = (+)
            self.numRegisters = 2
            self.numImmediates = 1
        case "addiu":
            self.type = .ALUI
            self.operation = { return Int32((UInt32($0) + UInt32($1)).value) }
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
        case "sll":
            self.type = .ALUI
            self.operation = { return $0 << $1 }
            self.numRegisters = 2
            self.numImmediates = 1
        // Memory operations
            
        // Jump instructions
        case "j":
            self.type = .Jump
            self.numRegisters = 0
            self.numImmediates = 1
            let op: (Int32, Int32) -> Int32 = { return $0.0 }
            // Not entirely sure why this is needed, but the compiler won't accept this simpler solution...
            // self.operation = { return $0 }
            self.operation = op // $ra = unchanged
        case "jal":
            self.type = .Jump
            self.numRegisters = 0
            self.numImmediates = 1
            self.operation = { return $1 } // $ra = pc
            self.pcIncrement = 8
        case "jr":
            self.type = .Jump
            self.numRegisters = 1
            self.numImmediates = 0
            let op: (Int32, Int32) -> Int32 = { return $0.0 }
            self.operation = op // $ra = unchanged
        case "jalr":
            self.type = .Jump
            self.numRegisters = 1
            self.numImmediates = 0
            self.operation = { return $1 } // $ra = pc
        // More complex instructions, mostly pseudo-instructions
        case "li":
            self.type = .ComplexInstruction
            self.operation = (+)
            self.numRegisters = 1
            self.numImmediates = 1
            self.pcIncrement = 8
        case "move":
            self.type = .ComplexInstruction
            self.operation = (+)
            self.numRegisters = 2
            self.numImmediates = 0
        case "mfhi", "mflo":
            self.type = .ComplexInstruction
            self.operation = (+)
            self.numRegisters = 1
            self.numImmediates = 0
        case "mult":
            self.type = .ComplexInstruction
            self.bigOperation = { return Int64($0)*Int64($1) }
            self.numRegisters = 2
            self.numImmediates = 0
        case "multu":
            self.type = .ComplexInstruction
            self.bigOperation = { return Int64((UInt64($0)*UInt64($1)).value) }
            self.numRegisters = 2
            self.numImmediates = 0
        case "div":
            self.type = .ComplexInstruction
            self.bigOperation = {
                let quotient = $0 / $1 // To be stored in lo
                let remainder = $0 % $1 // To be stored in hi
                return Int64(remainder) << 32 | Int64(quotient)
            }
            self.numRegisters = 2
            self.numImmediates = 0
        case "divu":
            self.type = .ComplexInstruction
            self.bigOperation = {
                let u1 = UInt32($0)
                let u2 = UInt32($1)
                let quotient = u1 / u2 // To be stored in lo
                let remainder = u1 % u2 // To be stored in hi
                return Int64(remainder) << 32 | Int64(quotient)
            }
            self.numRegisters = 2
            self.numImmediates = 0
        // Special case syscall instruction
        case "syscall":
            self.type = .Syscall
            self.numRegisters = 0
            self.numImmediates = 0
        // Catch-all case for REPL to determine that this is an invalid instruction
        default:
            return nil
        }
    }
}