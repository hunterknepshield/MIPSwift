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

// Typealiases for functions stored within InstructionTypes
typealias Operation32 = (Int32, Int32) -> Int32 // 2 operands, 1 result
typealias Operation64 = (Int32, Int32) -> (Int32, Int32) // 2 operands, 2 results; technically 1 Int64 would also suffice, but this reduces parsing (e.g. operations that store results into hi and lo)
typealias OperationBool = (Int32, Int32) -> Bool // 2 operands, 1 boolean result

// Representations of each type of MIPS instruction
enum InstructionType {
    // Typical Instruction types
    case ALUR(Either<Operation32, (Operation64, Bool)>, Register?, Register, Register) // Destination register may or may not be used based on which type the operation is
    case ALUI(Either<Operation32, (Operation64, Bool)>, Register, Register, Immediate)
    case Memory(Bool, Int, Register, Register, Immediate)
    case Jump(Bool, Either<Register, String>) // Technically, J-type instructions store an integer value that's the offset from the current program counter
    case Branch(OperationBool, Register, Register, String)
    // Special Instruction types
    case Syscall // System call; e.g. reading input, printing, etc.
    case Directive(DotDirective, [String]) // Dot directive with arugments; e.g. .data, .text, etc.
    case NonExecutable // This line only contains labels and/or comments    
}

struct Instruction: CustomStringConvertible {
    let rawString: String
    let location: Int32
    let pcIncrement: Int32
    var arguments = [String]()
    var labels = [String]()
    var comment: String?
    let type: InstructionType
    var instructionString: String {
        // Labels and comments removed; syntax possibly reformatted
        get {
            if self.arguments.count > 0 {
                var string = self.arguments[0].stringByPaddingToLength(8, withString: " ", startingAtIndex: 0)
                if case let .Directive(directive, _) = self.type where [.Ascii, .Asciiz].contains(directive) {
                    // Add string literal delimiters before and after arguments; only for .ascii/.asciiz
                    string += stringLiteralDelimiter + self.arguments[1].toStringWithLiteralEscapes() + stringLiteralDelimiter
                } else if case .Memory(_, _, _, _, _) = self.type {
                    // Special formatting of memory operation, e.g. lw  $s0, 0($sp)
                    string += "\(self.arguments[1]), \(self.arguments[2])(\(self.arguments[3]))"
                } else {
                    var counter = 0
                    self.arguments[1..<self.arguments.count].forEach({ string += $0 + (++counter < self.arguments.count - 1 ? ", " : "") })
                }
                return string
            } else {
                return ""
            }
        }
    }
    var completeString: String {
        // Labels and comments added back in around the instruction string
        get {
            var string = ""
            // Labels come first
            var counter = 0
            self.labels.forEach({ string += "\($0):" + (++counter < self.labels.count ? "" : "\t") })
            string += self.instructionString
            if self.comment != nil && self.comment != "" {
                string += " " + self.comment!
            }
            return string
        }
    }
    var description: String { get { return "\(self.location.toHexWith0x()):\t\(self.completeString)" } }
    
    init?(string: String, location: Int32, verbose: Bool) {
        self.rawString = string
        self.location = location
        
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
                    return nil
                }
                self.labels.append(label)
                if verbose {
                    print("Label: \(label)")
                }
            }
        }
        
        // Done removing things from arguments, but directives may modify further
        self.arguments = args
        if args.count == 0 {
            // This instruction only contained comments and/or labels
            self.type = .NonExecutable
            self.pcIncrement = 0
            return
        }
        
        let argCount = args.count - 1 // Don't count the actual instruction
        if args[0][0] == directiveBeginning {
            // Requires a significant amount of additional parsing to make sure arguments are in order
            if let directive = DotDirective(rawValue: args[0]) {
                switch(directive) {
                case .Align:
                    // Align current address to be on a 2^n-byte boundary; 1 argument, must be 0, 1, or 2
                    self.pcIncrement = 0
                    if argCount != 1 {
                        print("Directive \(directive.rawValue) expects 1 argument, got \(argCount).")
                        return nil
                    } else if !["0", "1", "2"].contains(args[1]) {
                        print("Invalid alignment factor: \(args[1])")
                        return nil
                    }
                case .Data, .Text:
                    // Change to data segment (address may be supplied; unimplemented as of now)
                    self.pcIncrement = 0
                    if argCount != 0 {
                        print("Directive \(directive.rawValue) expects 0 arguments, got \(argCount).")
                        return nil
                    }
                case .Global:
                    // Declare a global label; 1 argument
                    self.pcIncrement = 0
                    if argCount != 1 {
                        print("Directive \(directive.rawValue) expects 1 argument, got \(argCount).")
                        return nil
                    } else if !validLabelRegex.test(args[1]) {
                        print("Invalid label: \(args[1])")
                        return nil
                    }
                case .Ascii:
                    // Allocate space for a string (without null terminator); 1 argument, though it may have been split by paring above
                    if argCount == 0 {
                        print("Directive \(directive.rawValue) expects 1 argument, got 0.")
                        return nil
                    } else {
                        // Need to ensure that the whitespace from the original instruction's argument isn't lost
                        if let stringBeginningRange = self.rawString.rangeOfString(stringLiteralDelimiter) {
                            if let stringEndRange = self.rawString.rangeOfString(stringLiteralDelimiter, options: [.BackwardsSearch]) where stringBeginningRange.endIndex <= stringEndRange.startIndex {
                                let rawArgument = self.rawString.substringWithRange(stringBeginningRange.endIndex..<stringEndRange.startIndex)
                                let directivePart = self.rawString[self.rawString.startIndex..<stringBeginningRange.endIndex]
                                if directivePart.characters.count + rawArgument.characters.count + 1 != self.rawString.characters.count {
                                    // There is trailing stuff after the string literal is closed, don't allow this
                                    print("Invalid data after string literal: \(self.rawString[stringEndRange.endIndex..<self.rawString.endIndex])")
                                    return nil
                                }
                                do {
                                    let escapedArgument = try rawArgument.toStringWithEscapeSequences()
                                    self.pcIncrement = Int32(escapedArgument.lengthOfBytesUsingEncoding(NSASCIIStringEncoding)) // No null terminator
                                    self.arguments = [args[0], escapedArgument]
                                } catch _ {
                                    // Unable to convert escape sequences
                                    return nil
                                }
                            } else {
                                print("String literal expects closing delimiter.")
                                return nil
                            }
                        } else {
                            print("Directive \(directive.rawValue) expects string literal.")
                            return nil
                        }
                    }
                case .Asciiz:
                    // Allocate space for a string (with null terminator); 1 argument
                    if argCount == 0 {
                        print("Directive \(directive.rawValue) expects 1 argument, got 0.")
                        return nil
                    } else {
                        // Need to ensure that the whitespace from the original instruction's argument isn't lost
                        if let stringBeginningRange = self.rawString.rangeOfString(stringLiteralDelimiter) {
                            if let stringEndRange = self.rawString.rangeOfString(stringLiteralDelimiter, options: [.BackwardsSearch]) where stringBeginningRange.endIndex <= stringEndRange.startIndex {
                                let rawArgument = self.rawString.substringWithRange(stringBeginningRange.endIndex..<stringEndRange.startIndex)
                                let directivePart = self.rawString[self.rawString.startIndex..<stringBeginningRange.endIndex]
                                if directivePart.characters.count + rawArgument.characters.count + 1 != self.rawString.characters.count {
                                    // There is trailing stuff after the string literal is closed, don't allow this
                                    print("Invalid data after string literal: \(self.rawString[stringEndRange.endIndex..<self.rawString.endIndex])")
                                    return nil
                                }
                                do {
                                    let escapedArgument = try rawArgument.toStringWithEscapeSequences()
                                    self.pcIncrement = Int32(escapedArgument.lengthOfBytesUsingEncoding(NSASCIIStringEncoding) + 1) // No null terminator
                                    self.arguments = [args[0], escapedArgument]
                                } catch _ {
                                    // Unable to convert escape sequences (printed in method)
                                    return nil
                                }
                            } else {
                                print("String literal expects closing delimiter.")
                                return nil
                            }
                        } else {
                            print("Directive \(directive.rawValue) expects string literal.")
                            return nil
                        }
                    }
                case .Space:
                    // Allocate n bytes
                    if argCount != 1 {
                        print("Directive \(directive.rawValue) expects 1 argument, got \(argCount).")
                        return nil
                    }
                    if let n = Int32(args[1]) where n >= 0 {
                        self.pcIncrement = n
                    } else {
                        print("Invalid number of bytes to allocate: \(args[1])")
                        return nil
                    }
                case .Byte:
                    // Allocate space for n bytes with initial values
                    if argCount == 0 {
                        print("Directive \(directive.rawValue) expects arguments, got none.")
                        return nil
                    }
                    // Ensure every argument can be transformed to an 8-bit integer
                    var validArgs = true
                    args[1..<args.count].forEach({ if Int8($0) == nil { print("Invalid argument: \($0)"); validArgs = false } })
                    if !validArgs {
                        return nil
                    }
                    self.pcIncrement = Int32(argCount)
                case .Half:
                    // Allocate space for n half-words with initial values
                    if argCount == 0 {
                        print("Directive \(directive.rawValue) expects arguments, got none.")
                        return nil
                    }
                    // Ensure every argument can be transformed to a 16-bit integer
                    var validArgs = true
                    args[1..<args.count].forEach({ if Int16($0) == nil { print("Invalid argument: \($0)"); validArgs = false } })
                    if !validArgs {
                        return nil
                    }
                    self.pcIncrement = Int32((argCount)*2)
                case .Word:
                    // Allocate space for n words with initial values
                    if argCount == 0 {
                        print("Directive \(directive.rawValue) expects arguments, got none.")
                        return nil
                    }
                    // Ensure every argument can be transformed to a 32-bit integer
                    var validArgs = true
                    args[1..<args.count].forEach({ if Int32($0) == nil { print("Invalid argument: \($0)"); validArgs = false } })
                    if !validArgs {
                        return nil
                    }
                    self.pcIncrement = Int32((argCount)*4)
                }
                self.type = .Directive(directive, Array(self.arguments[1..<self.arguments.count]))
            } else {
                print("Invalid directive: \(args[0])")
                return nil
            }
            return
        }
        
        switch(args[0]) {
        case "syscall":
            self.type = .Syscall
            self.pcIncrement = 4
        // ALU-R operations
        case "add":
            if argCount != 3 {
                print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
                return nil
            }
            if let dest = Register(args[1], writing: true), src1 = Register(args[2], writing: false), src2 = Register(args[3], writing: false) {
                self.type = .ALUR(.Left(+), dest, src1, src2)
                self.pcIncrement = 4
            } else {
                return nil
            }
        case "addu":
            if argCount != 3 {
                print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
                return nil
            }
            if let dest = Register(args[1], writing: true), src1 = Register(args[2], writing: false), src2 = Register(args[3], writing: false) {
                self.type = .ALUR(.Left({ return Int32((UInt32($0) + UInt32($1)).value) }), dest, src1, src2)
                self.pcIncrement = 4
            } else {
                return nil
            }
        case "sub":
            if argCount != 3 {
                print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
                return nil
            }
            if let dest = Register(args[1], writing: true), src1 = Register(args[2], writing: false), src2 = Register(args[3], writing: false) {
                self.type = .ALUR(.Left(-), dest, src1, src2)
                self.pcIncrement = 4
            } else {
                return nil
            }
        case "subu":
            if argCount != 3 {
                print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
                return nil
            }
            if let dest = Register(args[1], writing: true), src1 = Register(args[2], writing: false), src2 = Register(args[3], writing: false) {
                self.type = .ALUR(.Left({ return Int32((UInt32($0) - UInt32($1)).value) }), dest, src1, src2)
                self.pcIncrement = 4
            } else {
                return nil
            }
        case "and":
            if argCount != 3 {
                print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
                return nil
            }
            if let dest = Register(args[1], writing: true), src1 = Register(args[2], writing: false), src2 = Register(args[3], writing: false) {
                self.type = .ALUR(.Left(&), dest, src1, src2)
                self.pcIncrement = 4
            } else {
                return nil
            }
        case "or":
            if argCount != 3 {
                print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
                return nil
            }
            if let dest = Register(args[1], writing: true), src1 = Register(args[2], writing: false), src2 = Register(args[3], writing: false) {
                self.type = .ALUR(.Left(|), dest, src1, src2)
                self.pcIncrement = 4
            } else {
                return nil
            }
        case "xor":
            if argCount != 3 {
                print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
                return nil
            }
            if let dest = Register(args[1], writing: true), src1 = Register(args[2], writing: false), src2 = Register(args[3], writing: false) {
                self.type = .ALUR(.Left(^), dest, src1, src2)
                self.pcIncrement = 4
            } else {
                return nil
            }
        case "slt":
            if argCount != 3 {
                print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
                return nil
            }
            if let dest = Register(args[1], writing: true), src1 = Register(args[2], writing: false), src2 = Register(args[3], writing: false) {
                self.type = .ALUR(.Left({ return $0 < $1 ? 1 : 0 }), dest, src1, src2)
                self.pcIncrement = 4
            } else {
                return nil
            }
        case "sltu":
            if argCount != 3 {
                print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
                return nil
            }
            if let dest = Register(args[1], writing: true), src1 = Register(args[2], writing: false), src2 = Register(args[3], writing: false) {
                self.type = .ALUR(.Left({ return UInt32($0) < UInt32($1) ? 1 : 0 }), dest, src1, src2)
                self.pcIncrement = 4
            } else {
                return nil
            }
        case "sllv":
            if argCount != 3 {
                print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
                return nil
            }
            if let dest = Register(args[1], writing: true), src1 = Register(args[2], writing: false), src2 = Register(args[3], writing: false) {
                self.type = .ALUR(.Left({ return $0 << $1 }), dest, src1, src2)
                self.pcIncrement = 4
            } else {
                return nil
            }
        // ALU-I operations
        case "addi":
            if argCount != 3 {
                print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
                return nil
            }
            if let dest = Register(args[1], writing: true), src1 = Register(args[2], writing: false), src2 = Immediate(args[3]) {
                self.type = .ALUI(.Left(+), dest, src1, src2)
                self.pcIncrement = 4
            } else {
                return nil
            }
        case "addiu":
            if argCount != 3 {
                print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
                return nil
            }
            if let dest = Register(args[1], writing: true), src1 = Register(args[2], writing: false), src2 = Immediate(args[3]) {
                self.type = .ALUI(.Left({ return Int32((UInt32($0) + UInt32($1)).value) }), dest, src1, src2)
                self.pcIncrement = 4
            } else {
                return nil
            }
        case "andi":
            if argCount != 3 {
                print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
                return nil
            }
            if let dest = Register(args[1], writing: true), src1 = Register(args[2], writing: false), src2 = Immediate(args[3]) {
                self.type = .ALUI(.Left(&), dest, src1, src2)
                self.pcIncrement = 4
            } else {
                return nil
            }
        case "ori":
            if argCount != 3 {
                print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
                return nil
            }
            if let dest = Register(args[1], writing: true), src1 = Register(args[2], writing: false), src2 = Immediate(args[3]) {
                self.type = .ALUI(.Left(|), dest, src1, src2)
                self.pcIncrement = 4
            } else {
                return nil
            }
        case "xori":
            if argCount != 3 {
                print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
                return nil
            }
            if let dest = Register(args[1], writing: true), src1 = Register(args[2], writing: false), src2 = Immediate(args[3]) {
                self.type = .ALUI(.Left(^), dest, src1, src2)
                self.pcIncrement = 4
            } else {
                return nil
            }
        case "slti":
            if argCount != 3 {
                print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
                return nil
            }
            if let dest = Register(args[1], writing: true), src1 = Register(args[2], writing: false), src2 = Immediate(args[3]) {
                self.type = .ALUI(.Left({ return $0 < $1 ? 1 : 0 }), dest, src1, src2)
                self.pcIncrement = 4
            } else {
                return nil
            }
        case "sltiu":
            if argCount != 3 {
                print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
                return nil
            }
            if let dest = Register(args[1], writing: true), src1 = Register(args[2], writing: false), src2 = Immediate(args[3]) {
                self.type = .ALUI(.Left({ return UInt32($0) < UInt32($1) ? 1 : 0 }), dest, src1, src2)
                self.pcIncrement = 4
            } else {
                return nil
            }
        case "sll":
            if argCount != 3 {
                print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
                return nil
            }
            if let dest = Register(args[1], writing: true), src1 = Register(args[2], writing: false), src2 = Immediate(args[3]) {
                self.type = .ALUI(.Left({ return $0 << $1 }), dest, src1, src2)
                self.pcIncrement = 4
            } else {
                return nil
            }
        // TODO Memory operations
        // Jump instructions
        case "j":
            if argCount != 1 {
                print("Instruction \(args[0]) expects 1 argument, got \(argCount).")
                return nil
            }
            self.type = .Jump(false, .Right(args[1]))
            self.pcIncrement = 4
        case "jal":
            if argCount != 1 {
                print("Instruction \(args[0]) expects 1 argument, got \(argCount).")
                return nil
            }
            self.type = .Jump(true, .Right(args[1]))
            self.pcIncrement = 4
        case "jr":
            if argCount != 1 {
                print("Instruction \(args[0]) expects 1 argument, got \(argCount).")
                return nil
            }
            if let dest = Register(args[1], writing: false) {
                self.type = .Jump(false, .Left(dest))
                self.pcIncrement = 4
            } else {
                return nil
            }
        case "jalr":
            if argCount != 1 {
                print("Instruction \(args[0]) expects 1 argument, got \(argCount).")
                return nil
            }
            if let dest = Register(args[1], writing: false) {
                self.type = .Jump(true, .Left(dest))
                self.pcIncrement = 4
            } else {
                return nil
            }
        // More complex instructions, mostly pseudo-instructions
        case "li":
            if argCount != 2 {
                print("Instruction \(args[0]) expects 2 arguments, got \(argCount).")
                return nil
            }
            if let dest = Register(args[1], writing: true), src = Immediate(args[2]) {
                self.type = .ALUI(.Left(+), dest, zero, src)
                self.pcIncrement = 8
            } else {
                return nil
            }
        case "move":
            if argCount != 2 {
                print("Instruction \(args[0]) expects 2 arguments, got \(argCount).")
                return nil
            }
            if let dest = Register(args[1], writing: true), src = Register(args[2], writing: false) {
                self.type = .ALUR(.Left(+), dest, src, zero) // This is the actual transformation in real MIPS
                self.pcIncrement = 4
            } else {
                return nil
            }
        case "mfhi", "mflo":
            if argCount != 1 {
                print("Instruction \(args[0]) expects 2 arguments, got \(argCount).")
                return nil
            }
            if let dest = Register(args[1], writing: true) {
                self.type = .ALUR(.Left(+), dest, args[0] == "mfhi" ? hi : lo, zero)
                self.pcIncrement = 4
            } else {
                return nil
            }
            /*
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
        */
        default:
            return nil
        }
    }
}