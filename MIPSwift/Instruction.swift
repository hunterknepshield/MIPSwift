//
//  Instruction.swift
//  MIPSwift
//
//  Created by Hunter Knepshield on 12/10/15.
//  Copyright © 2015 Hunter Knepshield. All rights reserved.
//

// All MIPS instructions with descriptions:
// http://www.mrc.uidaho.edu/mrc/people/jff/digital/MIPSir.html

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

        // Essentially, this is the decode phase
        if let operation = Operation(strippedComponents[0]) {
            // Ensure that the operation has the proper number of arguments
            let argCount = operation.numRegisters + operation.numImmediates
            if strippedComponents.count - 1 != argCount {
                print("Operation \(operation.name) expects \(argCount) arguments, got \(strippedComponents.count - 1).")
                self = Instruction.Invalid(string)
                return
            }
            
            switch(operation.type) {
            case .ALUR: // All ALU-R operations of format op, rd, rs, rt
                if let reg1 = Register(strippedComponents[1]), reg2 = Register(strippedComponents[2]), reg3 = Register(strippedComponents[3]) {
                    self = Instruction.rType(operation, reg1, reg2, reg3)
                } else {
                    self = Instruction.Invalid(string)
                }
            case .ALUI: // All ALU-I operations of format op, rt, rs, imm
                if let reg1 = Register(strippedComponents[1]), reg2 = Register(strippedComponents[2]), imm = Immediate(string: strippedComponents[3]) {
                    self = Instruction.iType(operation, reg1, reg2, imm)
                } else {
                    self = Instruction.Invalid(string)
                }
            // TODO memory
            // TODO jump
            // TODO branch
            case .ComplexInstruction:
                // Requires more fine-grained parsing
                switch(operation.name) {
                case "li":
                    // Transform to an addi ($rt = $zero + imm)
                    if let reg1 = Register(strippedComponents[1]), imm = Immediate(string: strippedComponents[2]) {
                        self = Instruction.iType(Operation("addi")!, reg1, zero, imm)
                    } else {
                        self = Instruction.Invalid(string)
                    }
                case "move":
                    // Transform to an add ($rt = $rs + $zero)
                    if let reg1 = Register(strippedComponents[1]), reg2 = Register(strippedComponents[2]) {
                        self = Instruction.rType(Operation("addi")!, reg1, reg2, zero)
                    } else {
                        self = Instruction.Invalid(string)
                    }
                default:
                    self = Instruction.Invalid(string)
                }
            default:
                self = Instruction.Invalid(string)
            }
        } else {
            self = Instruction.Invalid(string)
        }
    }
}

struct Register {
    // Representation of a source/destination register
    var name: String
    
    init?(_ name: String, user: Bool = true) {
        if user && immutableRegisters.contains(name) {
            print("User may not modify register \(name)")
            return nil
        }
        self.name = name
    }
}

struct Immediate {
    // Representation of an immediate value
    var value: Int16 // Limited to 16 bits
    var signExtended: Int32 { get { return Int32(value) } }
    
    // Initialize an immediate value from an integer
    init(value: Int16) {
        self.value = value
    }
    
    // Attempt to initialize an immediate value from a string; may fail
    init?(string: String) {
        let immValue = Int16(string)
        if immValue != nil {
            self.value = immValue!
        } else {
            print("Unable to create immediate value from string: \(string)")
            return nil
        }
    }
}

struct Label {
    // Representation of a label
    var name: String
    var location: Int32
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
        // Memory operations
        
        // More complex instructions
        case "li":
            self.type = .ComplexInstruction
            self.operation = (+)
            self.numRegisters = 1
            self.numImmediates = 1
        case "move":
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

enum OperationType {
    case ALUR
    case ALUI
    case Memory
    case Jump
    case Branch
    case ComplexInstruction
}