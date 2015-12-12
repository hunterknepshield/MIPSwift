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
    case jType(Operation, String)
    case NonExecutable // This line only contains labels and/or comments
    case Invalid // Malformed instruction
}

class Instruction: CustomStringConvertible {
    // Representations of each type of MIPS instruction
    let rawString: String
    let location: Int32
    var labels = [String]()
    let type: InstructionType
    var previous: Instruction?
    var next: Instruction?
    var description: String { get { return self.location.format(PrintOption.HexWith0x.rawValue) + " " + self.rawString } }
    
    init(string: String, location: Int32, previous: Instruction?, verbose: Bool) {
        self.rawString = string
        self.location = location
        self.previous = previous // Set self.previous?.next = self at the end of init
        
        if (verbose) {
            print("Previous instruction: \((self.previous == nil ? "(none)" : self.previous?.description)!)")
        }
        
        // Split this instruction on any whitespace or valid separator punctuation (not including newlines), ignoring empty strings
        var arguments = string.componentsSeparatedByCharactersInSet(validInstructionSeparatorsCharacterSet).filter({ !$0.isEmpty })
        if verbose {
            print("All parsed arguments: \(arguments)")
        }
        
        while arguments.count > 0 && arguments[0][arguments[0].characters.count - 1] == labelEnd {
            // Loop for all labels before the actual instruction arguments
            let fullString = arguments.removeFirst()
            let potentialLabel = fullString.substringToIndex(fullString.endIndex.predecessor()) // Remove the colon
            if potentialLabel.containsString(labelEnd) {
                // This label is actually a series of labels clumped together, i.e. label1:label2:label3 (last colon is already removed)
                let multiLabels = potentialLabel.componentsSeparatedByString(labelEnd)
                for singleLabel in multiLabels {
                    if !validLabelRegex.test(singleLabel) {
                        // This label contains one or more invalid characters
                        print("Invalid label: \(singleLabel)")
                        self.type = .Invalid
                        return
                    }
                    self.labels.append(singleLabel)
                    if verbose {
                        print("Label: \(singleLabel)")
                    }
                }
            } else {
                // This is just a single label
                if !validLabelRegex.test(potentialLabel) {
                    // This label contains one or more invalid characters
                    print("Invalid label: \(potentialLabel)")
                    self.type = .Invalid
                    return
                }
                self.labels.append(potentialLabel)
                if verbose {
                    print("Label: \(potentialLabel)")
                }
            }
        }
        
        // TODO implement comments
        // Check if arguments[i] begins with a hashtag (wow, I did just call it a hashtag instead of a pound sign),
        // then remove it and any subsequent elements from the array and continue parsing

        if arguments.count == 0 {
            self.type = .NonExecutable
            return
        }
        
        // Essentially, this is the decode phase
        if let operation = Operation(arguments[0]) {
            // Ensure that the operation has the proper number of arguments
            let argCount = operation.numRegisters + operation.numImmediates
            if arguments.count - 1 != argCount {
                print("Operation \(operation.name) expects \(argCount) arguments, got \(arguments.count - 1).")
                self.type = .Invalid
                return
            }
            
            switch(operation.type) {
            case .ALUR: // All ALU-R operations of format op, rd, rs, rt
                if let reg1 = Register(arguments[1]), reg2 = Register(arguments[2]), reg3 = Register(arguments[3]) {
                    self.type = InstructionType.rType(operation, reg1, reg2, reg3)
                } else {
                    self.type = .Invalid
                }
            case .ALUI: // All ALU-I operations of format op, rt, rs, imm
                if let reg1 = Register(arguments[1]), reg2 = Register(arguments[2]), imm = Immediate(string: arguments[3]) {
                    self.type = InstructionType.iType(operation, reg1, reg2, imm)
                } else {
                    self.type = .Invalid
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
                        self.type = .Invalid
                    }
                case "move":
                    // Transform to an add ($rt = $rs + $zero)
                    if let reg1 = Register(arguments[1]), reg2 = Register(arguments[2]) {
                        self.type = InstructionType.rType(Operation("addi")!, reg1, reg2, zero)
                    } else {
                        self.type = .Invalid
                    }
                case "mfhi":
                    // Transform to an add ($rt = $hi + $zero)
                    if let reg1 = Register(arguments[1]) {
                        self.type = InstructionType.rType(Operation("add")!, reg1, hi, zero)
                    } else {
                        self.type = .Invalid
                    }
                case "mflo":
                    // Transform to an add ($rt = $lo + $zero)
                    if let reg1 = Register(arguments[1]) {
                        self.type = InstructionType.rType(Operation("add")!, reg1, lo, zero)
                    } else {
                        self.type = .Invalid
                    }
                case "mult", "multu", "div", "divu":
                    if let reg1 = Register(arguments[1]), reg2 = Register(arguments[2]) {
                        self.type = InstructionType.rType(operation, zero, reg1, reg2)
                    } else {
                        self.type = .Invalid
                    }
                default:
                    self.type = .Invalid
                }
            default:
                self.type = .Invalid
            }
        } else {
            // Unable to construct an Operation
            self.type = .Invalid
        }
        self.previous?.next = self // Has to be done down here after all other fields are initialized
    }
}