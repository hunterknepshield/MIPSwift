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

enum InstructionType {
    case rType(Operation, Register, Register, Register)
    case iType(Operation, Register, Register, Immediate)
    case jType(Operation, Label)
    case Invalid(String)
}

class Instruction {
    // Representations of each type of MIPS instruction
    let location: Int32
    let label: String?
    let type: InstructionType
    
    init(_ string: String, _ location: Int32, _ verbose: Bool) {
        self.location = location
        // Split this instruction on any whitespace or valid separator punctuation (not including newlines), ignoring empty strings
        let arguments = string.componentsSeparatedByCharactersInSet(validInstructionSeparatorsCharacterSet).filter({ !$0.isEmpty })
        
        if verbose {
            print(arguments)
        }
        
        // TODO implement labels
        // Check if splitString[0] has a colon at the end here,
        // then remove it from the array and continue parsing
        self.label = nil
        
        // TODO implement comments
        // Check if splitString[i] begins with a hashtag (wow, I did just call it a hashtag instead of a pound sign),
        // then remove it and any subsequent elements from the array and continue parsing

        // Essentially, this is the decode phase
        if let operation = Operation(arguments[0]) {
            // Ensure that the operation has the proper number of arguments
            let argCount = operation.numRegisters + operation.numImmediates
            if arguments.count - 1 != argCount {
                print("Operation \(operation.name) expects \(argCount) arguments, got \(arguments.count - 1).")
                self.type = InstructionType.Invalid(string)
                return
            }
            
            switch(operation.type) {
            case .ALUR: // All ALU-R operations of format op, rd, rs, rt
                if let reg1 = Register(arguments[1]), reg2 = Register(arguments[2]), reg3 = Register(arguments[3]) {
                    self.type = InstructionType.rType(operation, reg1, reg2, reg3)
                } else {
                    self.type = InstructionType.Invalid(string)
                }
            case .ALUI: // All ALU-I operations of format op, rt, rs, imm
                if let reg1 = Register(arguments[1]), reg2 = Register(arguments[2]), imm = Immediate(string: arguments[3]) {
                    self.type = InstructionType.iType(operation, reg1, reg2, imm)
                } else {
                    self.type = InstructionType.Invalid(string)
                }
            // TODO memory
            // TODO jump
            // TODO branch
            case .ComplexInstruction:
                // Requires more fine-grained parsing
                switch(operation.name) {
                case "li":
                    // Transform to an addi ($rt = $zero + imm)
                    if let reg1 = Register(arguments[1]), imm = Immediate(string: arguments[2]) {
                        self.type = InstructionType.iType(Operation("addi")!, reg1, zero, imm)
                    } else {
                        self.type = InstructionType.Invalid(string)
                    }
                case "move":
                    // Transform to an add ($rt = $rs + $zero)
                    if let reg1 = Register(arguments[1]), reg2 = Register(arguments[2]) {
                        self.type = InstructionType.rType(Operation("addi")!, reg1, reg2, zero)
                    } else {
                        self.type = InstructionType.Invalid(string)
                    }
                case "mfhi":
                    // Transform to an add ($rt = $hi + $zero)
                    if let reg1 = Register(arguments[1]) {
                        self.type = InstructionType.rType(Operation("add")!, reg1, hi, zero)
                    } else {
                        self.type = InstructionType.Invalid(string)
                    }
                case "mflo":
                    // Transform to an add ($rt = $lo + $zero)
                    if let reg1 = Register(arguments[1]) {
                        self.type = InstructionType.rType(Operation("add")!, reg1, lo, zero)
                    } else {
                        self.type = InstructionType.Invalid(string)
                    }
                case "mult", "multu", "div", "divu":
                    if let reg1 = Register(arguments[1]), reg2 = Register(arguments[2]) {
                        self.type = InstructionType.rType(operation, zero, reg1, reg2)
                    } else {
                        self.type = InstructionType.Invalid(string)
                    }
                default:
                    self.type = InstructionType.Invalid(string)
                }
            default:
                self.type = InstructionType.Invalid(string)
            }
        } else {
            self.type = InstructionType.Invalid(string)
        }
    }
}