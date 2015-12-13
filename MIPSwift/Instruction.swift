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

// Representations of each type of MIPS instruction
enum InstructionType {
    case RType(Operation, Register, Register, Register)
    case IType(Operation, Register, Register, Immediate)
    case JType(Operation, Either<Register, String>) // May jump to a label or a register
    // Technically, J-type instructions store an integer value that's the offset from the current PC
    case Syscall // System call; e.g. reading input, printing, etc.
    case Directive(DotDirective) // Dot directive; e.g. .data, .text, etc.
    case NonExecutable // This line only contains labels and/or comments
    case Invalid // Malformed instruction
}

class Instruction: CustomStringConvertible {
    let rawString: String
    var instructionString: String {
        get {
            if self.arguments.count > 0 {
                var string = self.arguments[0].stringByPaddingToLength(8, withString: " ", startingAtIndex: 0)
                var counter = 0
                self.arguments[1..<self.arguments.count].forEach({ string += $0 + (++counter < self.arguments.count - 1 ? ", " : "") })
                return string
            } else {
                return self.rawString
            }
        }
    }// Labels and comments removed; syntax possibly reformatted
    let location: Int32
    let pcIncrement: Int32
    let arguments: [String]
    var labels = [String]()
    let comment: String?
    let type: InstructionType
    var previous: Instruction?
    var next: Instruction?
    var description: String { get { return self.location.toHexWith0x() + ":\t" + self.instructionString } }
    
    init(string: String, location: Int32, previous: Instruction?, verbose: Bool) {
        self.rawString = string
        self.location = location
        self.previous = previous // Set self.previous?.next = self at the end of init
        
        if (verbose) {
            print("Previous instruction: \((self.previous == nil ? "(none)" : self.previous?.description)!)")
        }
        
        // Split this instruction on any whitespace or valid separator punctuation (not including newlines), ignoring empty strings
        var args = string.componentsSeparatedByCharactersInSet(validInstructionSeparatorsCharacterSet).filter({ !$0.isEmpty })
        if verbose {
            print("All parsed arguments: \(args)")
        }
        
        // Comment removal: if anything in arguments contains a hashtag (wow, I did just call it a hashtag instead of a pound sign),
        // then remove it and any subsequent elements from the array and continue parsing
        let argumentContainsComment = args.map({ $0.containsString(commentBeginning) })
        if let commentBeginningIndex = argumentContainsComment.indexOf(true) {
            let commentBeginningString = args[commentBeginningIndex]
            if commentBeginningString[0] == commentBeginning {
                // The comment is the start of this argument, just remove this argument and all that follow
                self.comment = args[commentBeginningIndex..<args.count].joinWithSeparator(" ")
                args.removeRange(commentBeginningIndex..<args.count)
            } else {
                // The comment begins somewhere else in the argument, e.g. something:#like_this, or $t1, $t1, $t2#this
                let separatedComponents = commentBeginningString.componentsSeparatedByString(commentBeginning)
                let nonCommentPart = separatedComponents[0]
                // nonCommentPart is guaranteed to not be the empty string
                args[commentBeginningIndex] = nonCommentPart // Put the non-comment part back in the arguments
                let commentParts = separatedComponents[1..<separatedComponents.count] + args[(commentBeginningIndex + 1)..<args.count]
                self.comment = commentParts.joinWithSeparator(" ")
                args.removeRange((commentBeginningIndex + 1)..<args.count) // Remove everything past the comment beginning
            }
            if verbose {
                print("Comment: \(self.comment!)")
            }
        } else {
            self.comment = nil
        }
        
        // Label identification: if anything at the beginning of arguments ends with a colon,
        // then remove it from arguments to be parsed and add it to this instruction's labels array
        while args.count > 0 && args[0][args[0].characters.count - 1] == labelEnd {
            // Loop for all labels before the actual instruction arguments
            let fullString = args.removeFirst()
            let splitLabels = fullString.componentsSeparatedByString(labelEnd).filter({ return !$0.isEmpty })
            // splitLabels may be one label or many; a single argument may actually be something like label1:label2:label3:
            for label in splitLabels {
                if !validLabelRegex.test(label) {
                    // This label contains one or more invalid characters
                    print("Invalid label: \(label)")
                    self.type = .Invalid
                    self.arguments = []
                    self.pcIncrement = 0
                    return
                }
                self.labels.append(label)
                if verbose {
                    print("Label: \(label)")
                }
            }
        }
        
        // Done removing things from arguments
        self.arguments = args
        if args.count == 0 {
            // This instruction only contained comments and/or labels
            self.type = .NonExecutable
            self.pcIncrement = 0
            return
        }
        
        // Essentially, this is the decode phase
        if let operation = Operation(args[0]) {
            if operation.type == .Directive {
                // Requires a significant amount of additional parsing to make sure arguments are in order
                if let directive = DotDirective(rawValue: args[0]) {
                    switch(directive) {
                    case .Align:
                        // Align current address to be on a 2^n-byte boundary; 1 argument, must be 0, 1, or 2
                        self.pcIncrement = 0
                        if args.count != 2 {
                            print("Directive \(directive.rawValue) expects 1 argument, got \(args.count - 1).")
                            self.type = .Invalid
                            return
                        } else if !["0", "1", "2"].contains(args[1]) {
                            print("Invalid alignment factor: \(args[1])")
                            self.type = .Invalid
                            return
                        }
                    case .Data, .Text:
                        // Change to data segment (address may be supplied; unimplemented as of now)
                        self.pcIncrement = 0
                        if args.count != 1 {
                            print("Directive \(directive.rawValue) expects 0 arguments, got \(args.count - 1).")
                            self.type = .Invalid
                            return
                        }
                    case .Global:
                        // Declare a global label; 1 argument
                        self.pcIncrement = 0
                        if args.count != 2 {
                            print("Directive \(directive.rawValue) expects 1 argument, got \(args.count - 1).")
                            self.type = .Invalid
                            return
                        } else if !validLabelRegex.test(args[1]) {
                            print("Invalid label: \(args[1])")
                            self.type = .Invalid
                            return
                        }
                    case .Ascii:
                        // Allocate space for a string (without null terminator); 1 argument
                        if args.count == 2 {
                            self.pcIncrement = Int32(args[1].lengthOfBytesUsingEncoding(NSASCIIStringEncoding)) // No null terminator
                        } else {
                            print("Directive \(directive.rawValue) expects 1 argument, got \(args.count - 1).")
                            self.type = .Invalid
                            self.pcIncrement = 0
                            return
                        }
                    case .Asciiz:
                        // Allocate space for a string (with null terminator); 1 argument
                        if args.count == 2 {
                            self.pcIncrement = Int32(args[1].lengthOfBytesUsingEncoding(NSASCIIStringEncoding) + 1) // Null terminator
                        } else {
                            print("Directive \(directive.rawValue) expects 1 argument, got \(args.count - 1).")
                            self.type = .Invalid
                            self.pcIncrement = 0
                            return
                        }
                    case .Space:
                        // Allocate n bytes
                        if args.count != 2 {
                            print("Directive \(directive.rawValue) expects 1 argument, got \(args.count - 1).")
                            self.type = .Invalid
                            self.pcIncrement = 0
                            return
                        }
                        if let n = Int32(args[1]) where n >= 0 {
                            self.pcIncrement = n
                        } else {
                            print("Invalid number of bytes to allocate: \(args[1])")
                            self.type = .Invalid
                            self.pcIncrement = 0
                            return
                        }
                    case .Byte:
                        // Allocate space for n bytes with initial values
                        if args.count == 1 {
                            print("Directive \(directive.rawValue) expects more than 0 arguments, got \(args.count - 1).")
                            self.type = .Invalid
                            self.pcIncrement = 0
                            return
                        }
                        // Ensure every argument can be transformed to an 8-bit integer
                        var validArgs = true
                        args.forEach({ if Int8($0) == nil { print("Invalid argument: \($0)"); validArgs = false } })
                        if !validArgs {
                            self.type = .Invalid
                            self.pcIncrement = 0
                            return
                        }
                        self.pcIncrement = Int32(args.count - 1)
                    case .Half:
                        // Allocate space for n half-words with initial values
                        if args.count == 1 {
                            print("Directive \(directive.rawValue) expects more than 0 arguments, got \(args.count - 1).")
                            self.type = .Invalid
                            self.pcIncrement = 0
                            return
                        }
                        // Ensure every argument can be transformed to a 16-bit integer
                        var validArgs = true
                        args.forEach({ if Int16($0) == nil { print("Invalid argument: \($0)"); validArgs = false } })
                        if !validArgs {
                            self.type = .Invalid
                            self.pcIncrement = 0
                            return
                        }
                        self.pcIncrement = Int32((args.count - 1)*2)
                    case .Word:
                        // Allocate space for n words with initial values
                        if args.count == 1 {
                            print("Directive \(directive.rawValue) expects more than 0 arguments, got \(args.count - 1).")
                            self.type = .Invalid
                            self.pcIncrement = 0
                            return
                        }
                        // Ensure every argument can be transformed to a 32-bit integer
                        var validArgs = true
                        args.forEach({ if Int32($0) == nil { print("Invalid argument: \($0)"); validArgs = false } })
                        if !validArgs {
                            self.type = .Invalid
                            self.pcIncrement = 0
                            return
                        }
                        self.pcIncrement = Int32((args.count - 1)*4)
                    }
                    self.type = .Directive(directive)
                } else {
                    print("Invalid directive: \(args[0])")
                    self.type = .Invalid
                    self.pcIncrement = 0
                }
                return
            }
            
            // Ensure that the operation has the proper number of arguments
            let expectedArgCount = operation.numRegisters + operation.numImmediates
            if args.count - 1 != expectedArgCount {
                print("Operation \(operation.name) expects \(expectedArgCount) arguments, got \(args.count - 1).")
                self.type = .Invalid
                self.pcIncrement = 0
                return
            }
            
            // Keep note of how much this instruction should increment the program counter by
            self.pcIncrement = operation.pcIncrement
            
            switch(operation.type) {
            case .ALUR: // All ALU-R operations of format op, rd, rs, rt
                if let reg1 = Register(args[1], writing: true), reg2 = Register(args[2], writing: false), reg3 = Register(args[3], writing: false) {
                    self.type = InstructionType.RType(operation, reg1, reg2, reg3)
                } else {
                    self.type = .Invalid
                }
            case .ALUI: // All ALU-I operations of format op, rt, rs, imm
                if let reg1 = Register(args[1], writing: true), reg2 = Register(args[2], writing: false), imm = Immediate(string: args[3]) {
                    self.type = InstructionType.IType(operation, reg1, reg2, imm)
                } else {
                    self.type = .Invalid
                }
            // TODO memory
            case .Jump: // All J-type operations of format op, dest
                if validRegisters.contains(args[1]), // Prevents printing of the "invalid register reference" message
                    let reg1 = Register(args[1], writing: false) {
                    // Jumping to a register
                    self.type = .JType(operation, .Left(reg1))
                } else if validLabelRegex.test(args[1]) {
                    // Jumping to a label
                    self.type = .JType(operation, .Right(args[1]))
                } else {
                    // Unable to determine a valid location to jump to
                    self.type = .Invalid
                }
            // TODO branch
            case .ComplexInstruction:
                // Requires more fine-grained parsing
                switch(operation.name) {
                case "li":
                    // Transform to an addi ($reg1 = $zero + imm)
                    if let reg1 = Register(args[1], writing: true), imm = Immediate(string: args[2]) {
                        self.type = InstructionType.IType(Operation("addi")!, reg1, zero, imm)
                    } else {
                        self.type = .Invalid
                    }
                case "move":
                    // Transform to an add ($reg1 = $reg2 + $zero)
                    // This is also the actual pseudo instruction transformation
                    if let reg1 = Register(args[1], writing: true), reg2 = Register(args[2], writing: false) {
                        self.type = InstructionType.RType(Operation("add")!, reg1, reg2, zero)
                    } else {
                        self.type = .Invalid
                    }
                case "mfhi":
                    // Transform to an add ($reg1 = $hi + $zero)
                    if let reg1 = Register(args[1], writing: true) {
                        self.type = InstructionType.RType(Operation("add")!, reg1, hi, zero)
                    } else {
                        self.type = .Invalid
                    }
                case "mflo":
                    // Transform to an add ($reg1 = $lo + $zero)
                    if let reg1 = Register(args[1], writing: true) {
                        self.type = InstructionType.RType(Operation("add")!, reg1, lo, zero)
                    } else {
                        self.type = .Invalid
                    }
                case "mult", "multu", "div", "divu":
                    if let reg1 = Register(args[1], writing: false), reg2 = Register(args[2], writing: false) {
                        self.type = InstructionType.RType(operation, zero, reg1, reg2)
                    } else {
                        self.type = .Invalid
                    }
                default:
                    self.type = .Invalid
                }
            case .Syscall:
                self.type = .Syscall
            default:
                self.type = .Invalid
            }
        } else {
            // Unable to construct an Operation
            self.type = .Invalid
            self.pcIncrement = 0
        }
        self.previous?.next = self // Has to be done down here after all other fields are initialized
    }
    
    
}