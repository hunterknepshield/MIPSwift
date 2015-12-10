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