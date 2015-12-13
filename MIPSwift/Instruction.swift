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
    let instructionString: String? // Labels and comments removed; syntax possibly reformatted
    let location: Int32
    var labels = [String]()
    let comment: String?
    let type: InstructionType
    var previous: Instruction?
    var next: Instruction?
    var description: String { get { return self.location.format(PrintOption.HexWith0x.rawValue) + " " + (self.instructionString ?? self.rawString) } }
    
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
        
        // Comment removal: if anything in arguments contains a hashtag (wow, I did just call it a hashtag instead of a pound sign),
        // then remove it and any subsequent elements from the array and continue parsing
        let containsComment = arguments.map({ $0.containsString(commentBeginning) })
        if let commentBeginningIndex = containsComment.indexOf(true) {
            let commentBeginningString = arguments[commentBeginningIndex]
            if commentBeginningString[0] == commentBeginning {
                // The comment is the start of this argument, just remove this argument and all that follow
                self.comment = arguments[commentBeginningIndex..<arguments.count].joinWithSeparator(" ")
                arguments.removeRange(commentBeginningIndex..<arguments.count)
            } else {
                // The comment begins somewhere else in the argument, i.e. something:#like_this, or $t1, $t1, $t2#this
                let separatedComponents = commentBeginningString.componentsSeparatedByString(commentBeginning)
                let nonCommentPart = separatedComponents[0]
                // nonCommentPart is guaranteed to not be the empty string
                arguments[commentBeginningIndex] = nonCommentPart // Put the non-comment part back in the arguments
                let commentParts = separatedComponents[1..<separatedComponents.count] + arguments[(commentBeginningIndex + 1)..<arguments.count]
                self.comment = commentParts.joinWithSeparator(" ")
                arguments.removeRange((commentBeginningIndex + 1)..<arguments.count) // Remove everything past the comment beginning
            }
            if verbose {
                print("Comment: \(self.comment!)")
            }
        } else {
            self.comment = nil
        }
        
        // Label identification: if anything at the beginning of arguments ends with a colon,
        // then remove it from arguments to be parsed and add it to this instruction's labels array
        while arguments.count > 0 && arguments[0][arguments[0].characters.count - 1] == labelEnd {
            // Loop for all labels before the actual instruction arguments
            let fullString = arguments.removeFirst()
            let potentialLabel = fullString.substringToIndex(fullString.endIndex.predecessor()) // Remove the colon
            let splitLabels = potentialLabel.componentsSeparatedByString(labelEnd)
            // splitLabels may be one label or many; a single argument may actually be something like label1:label2:label3 (last colon is already removed)
            for label in splitLabels {
                if !validLabelRegex.test(label) {
                    // This label contains one or more invalid characters
                    print("Invalid label: \(label)")
                    self.type = .Invalid
                    self.instructionString = nil
                    return
                }
                self.labels.append(label)
                if verbose {
                    print("Label: \(label)")
                }
            }
        }
        
        if arguments.count == 0 {
            // This instruction only contained comments and/or labels
            self.type = .NonExecutable
            self.instructionString = nil
            return
        }
        
        // Essentially, this is the decode phase
        if let operation = Operation(arguments[0]) {
            // Ensure that the operation has the proper number of arguments
            let argCount = operation.numRegisters + operation.numImmediates
            if arguments.count - 1 != argCount {
                print("Operation \(operation.name) expects \(argCount) arguments, got \(arguments.count - 1).")
                self.type = .Invalid
                self.instructionString = nil
                return
            }
            
            switch(operation.type) {
            case .ALUR: // All ALU-R operations of format op, rd, rs, rt
                if let reg1 = Register(arguments[1]), reg2 = Register(arguments[2]), reg3 = Register(arguments[3]) {
                    self.type = InstructionType.rType(operation, reg1, reg2, reg3)
                    self.instructionString = arguments[0] + "\t" + arguments[1] + ", " + arguments[2] + ", " + arguments[3]
                } else {
                    self.type = .Invalid
                    self.instructionString = nil
                }
            case .ALUI: // All ALU-I operations of format op, rt, rs, imm
                if let reg1 = Register(arguments[1]), reg2 = Register(arguments[2]), imm = Immediate(string: arguments[3]) {
                    self.type = InstructionType.iType(operation, reg1, reg2, imm)
                    self.instructionString = arguments[0] + "\t" + arguments[1] + ", " + arguments[2] + ", " + arguments[3]
                } else {
                    self.type = .Invalid
                    self.instructionString = nil
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
                        self.instructionString = arguments[0] + "\t" + arguments[1] + ", " + arguments[2]
                    } else {
                        self.type = .Invalid
                        self.instructionString = nil
                    }
                case "move":
                    // Transform to an add ($rt = $rs + $zero)
                    if let reg1 = Register(arguments[1]), reg2 = Register(arguments[2]) {
                        self.type = InstructionType.rType(Operation("addi")!, reg1, reg2, zero)
                        self.instructionString = arguments[0] + "\t" + arguments[1] + ", " + arguments[2]
                    } else {
                        self.type = .Invalid
                        self.instructionString = nil
                    }
                case "mfhi":
                    // Transform to an add ($rt = $hi + $zero)
                    if let reg1 = Register(arguments[1]) {
                        self.type = InstructionType.rType(Operation("add")!, reg1, hi, zero)
                        self.instructionString = arguments[0] + "\t" + arguments[1]
                    } else {
                        self.type = .Invalid
                        self.instructionString = nil
                    }
                case "mflo":
                    // Transform to an add ($rt = $lo + $zero)
                    if let reg1 = Register(arguments[1]) {
                        self.type = InstructionType.rType(Operation("add")!, reg1, lo, zero)
                        self.instructionString = arguments[0] + "\t" + arguments[1]
                    } else {
                        self.type = .Invalid
                        self.instructionString = nil
                    }
                case "mult", "multu", "div", "divu":
                    if let reg1 = Register(arguments[1]), reg2 = Register(arguments[2]) {
                        self.type = InstructionType.rType(operation, zero, reg1, reg2)
                        self.instructionString = arguments[0] + "\t" + arguments[1] + ", " + arguments[2]
                    } else {
                        self.type = .Invalid
                        self.instructionString = nil
                    }
                default:
                    self.type = .Invalid
                    self.instructionString = nil
                }
            default:
                self.type = .Invalid
                self.instructionString = nil
            }
        } else {
            // Unable to construct an Operation
            self.type = .Invalid
            self.instructionString = nil
        }
        self.previous?.next = self // Has to be done down here after all other fields are initialized
    }
}