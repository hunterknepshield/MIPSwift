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

// MARK: Typealiases
/// 2 operands, 1 result. Most typical operation type.
typealias Operation32 = (Int32, Int32) -> Int32
/// 2 operands, 2 results. Generally used for instructions that store into hi
/// and lo. The value to be stored in hi is the first value in the tuple.
///
/// Technically, the result could be a single Int64, but most instructions just
/// end up splitting that back into 2 32-bit integers anyways; this format
/// reduces the parsing needed at execution time and makes division/remainder
/// instructions considerably simpler.
typealias Operation64 = (Int32, Int32) -> (Int32, Int32)
/// 2 operands, 1 boolean result. Generally used for branch instructions.
typealias OperationBool = (Int32, Int32) -> Bool

// MARK: InstructionType
/// Representations of each type of MIPS instruction. Each instruction type has
/// all appropriate associated values to complete the instruction.
enum InstructionType {
	/// An ALU operation that uses 2 source registers. The destination register
	/// may or may not be used based on which type the operation is.
	///
	/// Associated values:
	/// - `Either<Operation32, (Operation64, Bool)>`: This instruction may
	/// generate either a 32-bit result or a 64-bit result depending on the
	/// wrapped type.
	/// - `Register?`: The destination register of the instruction; guaranteed to
	/// be non-nil if the Either type wraps an Operation32. If the Either type
	/// wraps an Operation64 and Bool and this is non-nil, then the Bool is used
	/// to determine if the result from the 'hi' portion of the result is used.
	/// - `Register`: The first source register for the instruction.
	///	- `Register`: The second source register for the instruction.
    case ALUR(Either<Operation32, (Operation64, Bool)>, Register?, Register, Register)
	/// An ALU instruction that uses a register and an immediate value as its
	/// sources.
	///
	/// Associated values:
	/// - `Either<Operation32, (Operation64, Bool)>`: This instruction may
	/// generate either a 32-bit result or a 64-bit result depending on the
	/// wrapped type.
	/// - `Register`: The destination register of the instruction. If the Either
	/// type wraps an Operation64 and Bool, then the Bool is used to determine
	/// if the result from the 'hi' portion of the result is used.
	///	- `Register`: The first source for the instruction.
	///	- `Immediate`: The second source for the instruction.
    case ALUI(Either<Operation32, (Operation64, Bool)>, Register, Register, Immediate)
	/// A memory instruction that calculates an effective address in memory and
	/// loads or stores data from that address into or from a register.
	///
	/// Associated values:
	/// - `Bool`: Used to determine if this instruction performs a store
	/// operation or not.
	/// - `Int`: Used to determine the number of bytes to load or store. This
	/// value is a power of 2. 0 = byte, 1 = half-word, 2 = word.
	/// - `Register`: The register that will be stored from or loaded into.
	/// - `Immediate`: The offset for calculation of the effective address.
	/// - `Register`: The register for calculation of the effective address.
    case Memory(Bool, Int, Register, Immediate, Register)
	/// An unconditional jump instruction. Technically, J-type instructions
	/// store a 26-bit integer offset from the current program counter.
	///
	/// Associated values:
	/// - `Bool`: Used to determine if this instruction links the current program
	/// counter into $ra or not.
	/// - `Eiher<Register, String>`: The destination for the jump; may be the
	/// value of a register or the location of a label.
    case Jump(Bool, Either<Register, String>)
	/// A conditional branch instruction.
	///
	/// Associated values:
	/// - `OperationBool`: Used to determine if the branch is actually taken or
	/// not.
	/// - `Bool`: Used to determine if this instruction links the current program
	/// counter into $ra or not.
	/// - `Register`: The first source for the instruction.
	/// - `Register`: The second source for the instruction.
	/// - `String`: The destination label to jump to if this branch is taken.
    case Branch(OperationBool, Bool, Register, Register, String)
	/// A system call. This instruction type is used to allow the assembly
	/// program to do system-level things like read input and print.
	///
	/// No associated values.
    case Syscall
	/// An assembler directive. This is technically not an instruction, but it
	/// gives the assembler information on how to arrange things within the
	/// final file, such as global data.
	///
	/// Associated values:
	/// - `DotDirective`: The actual type of directive.
	/// - `[String]`: The arguments for the directive. Guaranteed to be valid.
    case Directive(DotDirective, [String])
	/// A non-executable instruction. This is generated whenever a line contains
	/// only labels and/or comments.
	///
	/// No associated values.
    case NonExecutable
}

// MARK: Instruction
/// Representation of a MIPS instruction.
struct Instruction: CustomStringConvertible {
	/// The exact string that was passed in during initialization, unmodified.
    let rawString: String
	/// The location of this instruction in memory.
    let location: Int32
	/// The amount that this instruction increments the program counter. All
	/// simple instructions increment the program counter by just 4; pseudo
	/// instructions may increment by more than that.
    let pcIncrement: Int32
	/// The parsed arguments of this instruction, omitting labels and comments.
    var arguments = [String]()
	/// The parsed labels of this instruction.
    var labels = [String]()
	/// The parsed comment of this instruction, if there was one.
    var comment: String?
	/// The final parsed representation of the instruction.
    let type: InstructionType
	/// The 'pretty' formatting of this instruction's arguments.
    var instructionString: String {
        get {
            if self.arguments.count > 0 {
                var string = self.arguments[0].stringByPaddingToLength(8, withString: " ", startingAtIndex: 0)
                if case let .Directive(directive, _) = self.type where [.Ascii, .Asciiz].contains(directive) {
                    // Add string literal delimiters before and after arguments; only for .ascii/.asciiz
                    string += stringLiteralDelimiter + self.arguments[1].toStringWithLiteralEscapes() + stringLiteralDelimiter
                } else if case .Memory(_) = self.type {
                    // Special formatting of memory instruction, e.g. lw  $s0, 0($sp)
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
	/// The 'pretty' formatting of this instruction's arguments, with any labels
	/// preceeding it, and any comments following it.
    var completeString: String {
        get {
            var string = ""
            var counter = 0
            self.labels.forEach({ string += "\($0):" + (++counter < self.labels.count ? "" : "\t") })
            string += self.instructionString
            if self.comment != nil && self.comment != "" {
                string += " " + self.comment!
            }
            return string
        }
    }
    var description: String { get { return "\(self.location.toHexWith0x()):\t\(self.instructionString)" } }
	
	/// Initialize an instruction from a raw input string. Will fail if the
	/// string would generate an invalid instruction.
	///
	/// - Parameters:
	///		- string: The raw string to be parsed.
	///		- location: The location that this instruction will be stored at in
	///			memory.
	///		- verbose: Determines if argument parsing will print extra
	///			information or not.
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
        let argumentContainsComment = args.map({ $0.containsString(commentDelimiter) })
        if let commentBeginningIndex = argumentContainsComment.indexOf(true) {
            let commentBeginningString = args[commentBeginningIndex]
            if commentBeginningString[0] == commentDelimiter {
                // The comment is the start of this argument, just remove this argument and all that follow
                self.comment = args[commentBeginningIndex..<args.count].joinWithSeparator(" ")
                args.removeRange(commentBeginningIndex..<args.count)
            } else {
                // The comment begins somewhere else in the argument, e.g. something:#like_this, or $t1, $t1, $t2#this
                let separatedComponents = commentBeginningString.componentsSeparatedByString(commentDelimiter)
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
        while args.count > 0 && args[0][args[0].characters.count - 1] == labelDelimiter {
            // Loop for all labels before the actual instruction arguments
            let fullString = args.removeFirst()
            let splitLabels = fullString.componentsSeparatedByString(labelDelimiter).filter({ return !$0.isEmpty })
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
        if args[0][0] == directiveDelimiter {
			// MARK: Directive parsing
            // Requires a significant amount of additional parsing to make sure arguments are in order
            guard let directive = DotDirective(rawValue: args[0]) else {
                print("Invalid directive: \(args[0])")
                return nil
            }
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
                    guard let stringBeginningRange = self.rawString.rangeOfString(stringLiteralDelimiter) else {
                        print("Directive \(directive.rawValue) expects string literal.")
                        return nil
                    }
                    guard let stringEndRange = self.rawString.rangeOfString(stringLiteralDelimiter, options: [.BackwardsSearch]) where stringBeginningRange.endIndex <= stringEndRange.startIndex else {
                        print("String literal expects closing delimiter.")
                        return nil
                    }
                    let rawArgument = self.rawString.substringWithRange(stringBeginningRange.endIndex..<stringEndRange.startIndex)
                    let directivePart = self.rawString[self.rawString.startIndex..<stringBeginningRange.endIndex]
                    if directivePart.characters.count + rawArgument.characters.count + 1 != self.rawString.characters.count {
                        // There is trailing stuff after the string literal is closed, don't allow this
                        print("Invalid data after string literal: \(self.rawString[stringEndRange.endIndex..<self.rawString.endIndex])")
                        return nil
                    }
                    guard let escapedArgument = try? rawArgument.toEscapedString() else {
                        return nil // Couldn't escape this string
                    }
                    self.pcIncrement = Int32(escapedArgument.lengthOfBytesUsingEncoding(NSASCIIStringEncoding)) // No null terminator
                    self.arguments = [args[0], escapedArgument]
                }
            case .Asciiz:
                // Allocate space for a string (with null terminator); 1 argument
                if argCount == 0 {
                    print("Directive \(directive.rawValue) expects 1 argument, got 0.")
                    return nil
                } else {
                    // Need to ensure that the whitespace from the original instruction's argument isn't lost
                    guard let stringBeginningRange = self.rawString.rangeOfString(stringLiteralDelimiter) else {
                        print("Directive \(directive.rawValue) expects string literal.")
                        return nil
                    }
                    guard let stringEndRange = self.rawString.rangeOfString(stringLiteralDelimiter, options: [.BackwardsSearch]) where stringBeginningRange.endIndex <= stringEndRange.startIndex else {
                        print("String literal expects closing delimiter.")
                        return nil
                    }
                    let rawArgument = self.rawString.substringWithRange(stringBeginningRange.endIndex..<stringEndRange.startIndex)
                    let directivePart = self.rawString[self.rawString.startIndex..<stringBeginningRange.endIndex]
                    if directivePart.characters.count + rawArgument.characters.count + 1 != self.rawString.characters.count {
                        // There is trailing stuff after the string literal is closed, don't allow this
                        print("Invalid data after string literal: \(self.rawString[stringEndRange.endIndex..<self.rawString.endIndex])")
                        return nil
                    }
                    guard let escapedArgument = try? rawArgument.toEscapedString() else {
                        return nil // Couldn't escape this string
                    }
                    self.pcIncrement = Int32(escapedArgument.lengthOfBytesUsingEncoding(NSASCIIStringEncoding) + 1) // Include null terminator
                    self.arguments = [args[0], escapedArgument]
                }
            case .Space:
                // Allocate n bytes
                if argCount != 1 {
                    print("Directive \(directive.rawValue) expects 1 argument, got \(argCount).")
                    return nil
                }
                guard let n = Int32(args[1]) where n >= 0 else {
                    print("Invalid number of bytes to allocate: \(args[1])")
                    return nil
                }
                self.pcIncrement = n
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
            return
        }
        
        switch(args[0]) {
        case "syscall":
            self.type = .Syscall
            self.pcIncrement = 4
        // MARK: ALU-R instructions
        case "add", "addu":
            if argCount != 3 {
                print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
                return nil
            }
            guard let dest = Register(args[1], writing: true), src1 = Register(args[2], writing: false), src2 = Register(args[3], writing: false) else {
                return nil
            }
            self.type = .ALUR(.Left(args[0] == "add" ? (&+) : { return ($0.unsigned() &+ $1.unsigned()).signed() }), dest, src1, src2)
            self.pcIncrement = 4
        case "sub", "subu":
            if argCount != 3 {
                print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
                return nil
            }
            guard let dest = Register(args[1], writing: true), src1 = Register(args[2], writing: false), src2 = Register(args[3], writing: false) else {
                return nil
            }
            self.type = .ALUR(.Left(args[0] == "sub" ? (&-) : { return ($0.unsigned() &- $1.unsigned()).signed() }), dest, src1, src2)
            self.pcIncrement = 4
        case "and", "or", "xor", "nor":
            if argCount != 3 {
                print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
                return nil
            }
            guard let dest = Register(args[1], writing: true), src1 = Register(args[2], writing: false), src2 = Register(args[3], writing: false) else {
                return nil
            }
			self.type = .ALUR(.Left(args[0] == "and" ? (&) : (args[0] == "or" ? (|) : (args[0] == "xor" ? (^) : ({ return ~($0 | $1) })))), dest, src1, src2)
            self.pcIncrement = 4
        case "slt", "sltu":
            if argCount != 3 {
                print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
                return nil
            }
            guard let dest = Register(args[1], writing: true), src1 = Register(args[2], writing: false), src2 = Register(args[3], writing: false) else {
                return nil
            }
            self.type = .ALUR(.Left(args[0] == "slt" ? { return $0 < $1 ? 1 : 0 } : { return $0.unsigned() < $1.unsigned() ? 1 : 0 }), dest, src1, src2)
            self.pcIncrement = 4
        case "sllv", "srav", "srlv":
            // SRL is essentially unsigned right shift
            if argCount != 3 {
                print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
                return nil
            }
            guard let dest = Register(args[1], writing: true), src1 = Register(args[2], writing: false), src2 = Register(args[3], writing: false) else {
                return nil
            }
			// The register's value is truncated down to the lowest 5 bits to ensure a valid shift range (in real MIPS too)
			self.type = .ALUR(.Left(args[0] == "sllv" ? { return $0 << ($1 & 0x1F) } : (args[0] == "srav" ? { return $0 >> ($1 & 0x1F)} : { return ($0.unsigned() >> ($1 & 0x1F).unsigned()).signed() })), dest, src1, src2)
            self.pcIncrement = 4
        // MARK: ALU-I instructions
        case "addi", "addiu":
            if argCount != 3 {
                print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
                return nil
            }
            guard let dest = Register(args[1], writing: true), src1 = Register(args[2], writing: false), src2 = Immediate(args[3]) else {
                return nil
            }
            self.type = .ALUI(.Left(args[0] == "addi" ? (&+) : { return ($0.unsigned() &+ $1.unsigned()).signed() }), dest, src1, src2)
            self.pcIncrement = 4
        case "andi", "ori", "xori":
            if argCount != 3 {
                print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
                return nil
            }
            guard let dest = Register(args[1], writing: true), src1 = Register(args[2], writing: false), src2 = Immediate(args[3]) else {
                return nil
            }
            self.type = .ALUI(.Left(args[0] == "andi" ? (&) : (args[0] == "ori" ? (|) : (^))), dest, src1, src2)
            self.pcIncrement = 4
        case "slti", "sltiu":
            if argCount != 3 {
                print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
                return nil
            }
            guard let dest = Register(args[1], writing: true), src1 = Register(args[2], writing: false), src2 = Immediate(args[3]) else {
                return nil
            }
            self.type = .ALUI(.Left(args[0] == "slti" ? { return $0 < $1 ? 1 : 0} : { return $0.unsigned() < $1.unsigned() ? 1 : 0 }), dest, src1, src2)
            self.pcIncrement = 4
        case "sll", "sra", "srl":
            // SLL and SRA are default implementations for signed Int types, SRL is basically unsigned right shift
            if argCount != 3 {
                print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
                return nil
            }
            guard let dest = Register(args[1], writing: true), src1 = Register(args[2], writing: false), src2 = Immediate(args[3]) else {
                return nil
            }
            if !(0..<32 ~= src2.value) {
				// REPL will terminate if it were to attempt executing a bitshift of more than 32 bits
                print("Invalid shift factor: \(src2.value)")
                return nil
            }
            self.type = .ALUI(.Left(args[0] == "sll" ? (<<) : (args[0] == "sra" ? (>>) : { return ($0.unsigned() >> $1.unsigned()).signed() })), dest, src1, src2)
            self.pcIncrement = 4
        // MARK: Memory instructions
        case "lw", "lh", "lb", "sw", "sh", "sb":
            if argCount != 3 {
                print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
                return nil
            }
            let storing = args[0][0] == "s"
            let size = args[0][1] == "b" ? 0 : args[0][1] == "h" ? 1 : 2
            guard let memReg = Register(args[1], writing: !storing), offset = Immediate(args[2]), addrReg = Register(args[3], writing: false) else {
                return nil
            }
            self.type = .Memory(storing, size, memReg, offset, addrReg)
            self.pcIncrement = 4
        // MARK: Jump instructions
        case "j", "jal":
            if argCount != 1 {
                print("Instruction \(args[0]) expects 1 argument, got \(argCount).")
                return nil
            }
            self.type = .Jump(args[0] == "jal", .Right(args[1]))
            self.pcIncrement = 4
        case "jr", "jalr":
            if argCount != 1 {
                print("Instruction \(args[0]) expects 1 argument, got \(argCount).")
                return nil
            }
            guard let dest = Register(args[1], writing: false) else {
                return nil
            }
            self.type = .Jump(args[0] == "jalr", .Left(dest))
            self.pcIncrement = 4
        // MARK: Branch instructions
        case "beq", "bne":
            if argCount != 3 {
                print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
                return nil
            }
            guard let src1 = Register(args[1], writing: false), src2 = Register(args[2], writing: false) else {
                return nil
            }
            self.type = .Branch({ return args[0] == "beq" ? ($0 == $1) : ($0 != $1) }, false, src1, src2, args[3])
            self.pcIncrement = 4
        case "bgez", "bgezal", "blz", "blzal", "bgtz", "bltez":
            if argCount != 2 {
                print("Instruction \(args[0]) expects 2 arguments, got \(argCount).")
                return nil
            }
            guard let src1 = Register(args[1], writing: false) else {
                return nil
            }
            let link = args[0] == "bgezal" || args[0] == "blzal"
            // All comparisons are with zero as the second argument
            let op: OperationBool
            switch(args[0]) {
            case "bgez", "bgezal":
                op = (>=)
            case "blz", "blzal":
                op = (<)
            case "bgtz":
                op = (>)
            case "bltez":
                op = (<=)
            default:
                fatalError("Invalid branch instruction \(args[0])")
            }
            self.type = .Branch(op, link, src1, zero, args[2])
            self.pcIncrement = 4
        // MARK: More complex instructions
        case "li":
			// Pseudo instruction that gets converted to lui $at [imm&0xFFFF0000] and ori [dest] $at [imm&0xFFFF]
            if argCount != 2 {
                print("Instruction \(args[0]) expects 2 arguments, got \(argCount).")
                return nil
            }
            guard let dest = Register(args[1], writing: true), src = Immediate(args[2]) else {
                return nil
            }
            self.type = .ALUI(.Left(+), dest, zero, src)
            self.pcIncrement = 8
        case "lui":
            if argCount != 2 {
                print("Instruction \(args[0]) expects 2 arguments, got \(argCount).")
                return nil
            }
            guard let dest = Register(args[1], writing: true), src = Immediate(args[2]) else {
                return nil
            }
            self.type = .ALUI(.Left({ return $1 << 16 }), dest, zero, src)
            self.pcIncrement = 4
        case "move":
            if argCount != 2 {
                print("Instruction \(args[0]) expects 2 arguments, got \(argCount).")
                return nil
            }
            guard let dest = Register(args[1], writing: true), src = Register(args[2], writing: false) else {
                return nil
            }
            self.type = .ALUR(.Left(+), dest, src, zero) // This is the actual transformation in real MIPS
            self.pcIncrement = 4
        case "mfhi", "mflo":
            if argCount != 1 {
                print("Instruction \(args[0]) expects 2 arguments, got \(argCount).")
                return nil
            }
            guard let dest = Register(args[1], writing: true) else {
                return nil
            }
            self.type = .ALUR(.Left(+), dest, args[0] == "mfhi" ? hi : lo, zero)
            self.pcIncrement = 4
        case "mult", "multu":
            if argCount != 2 {
                print("Instruction \(args[0]) expects 2 arguments, got \(argCount).")
                return nil
            }
            guard let src1 = Register(args[1], writing: false), src2 = Register(args[2], writing: false) else {
                return nil
            }
            self.type = .ALUR(.Right({ let fullValue = (args[0] == "mult" ? $0.signed64()*$1.signed64() : ($0.unsigned64()&*$1.unsigned64()).signed()); return (fullValue.signedUpper32(), fullValue.signedLower32()) }, false), nil, src1, src2)
            self.pcIncrement = 4
        case "mul":
            // Multiplication pseudoinstruction, which stores the lower 32 bits of src1*src2 in the destination
            if argCount != 3 {
                print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
                return nil
            }
            if args[3].rangeOfString(registerDelimiter) != nil {
                // Second source is a register
                guard let dest = Register(args[1], writing: true), src1 = Register(args[2], writing: false), src2 = Register(args[3], writing: false) else {
                    return nil
                }
                self.type = .ALUR(.Right({ let fullValue = $0.signed64()&*$1.signed64(); return (fullValue.signedUpper32(), fullValue.signedLower32()) }, false), dest, src1, src2) // Want the boolean (moveFromHi) to be false; want the lower 32 bits of the result
                self.pcIncrement = 8
            } else {
                // Second source is an immediate
                guard let dest = Register(args[1], writing: true), src1 = Register(args[2], writing: false), src2 = Immediate(args[3]) else {
                    return nil
                }
                self.type = .ALUI(.Right({ let fullValue = $0.signed64()&*$1.signed64(); return (fullValue.signedUpper32(), fullValue.signedLower32()) }, false), dest, src1, src2) // Want the boolean (moveFromHi) to be false; want the lower 32 bits of the result
                self.pcIncrement = 12
            }
        case "div" where argCount != 3, "divu":
            if argCount != 2 {
                print("Instruction \(args[0]) expects 2 arguments, got \(argCount).")
                return nil
            }
            // This is the real instruction, which just sticks $0 / $1 in lo, $0 % $1 in hi
            guard let src1 = Register(args[1], writing: false), src2 = Register(args[2], writing: false) else {
                return nil
            }
            self.type = .ALUR(.Right({ return args[0] == "div" ? (Int32.remainderWithOverflow($0, $1).0, Int32.divideWithOverflow($0, $1).0) : (UInt32.remainderWithOverflow($0.unsigned(), $1.unsigned()).0.signed(), UInt32.divideWithOverflow($0.unsigned(), $1.unsigned()).0.signed()) }, false), nil, src1, src2) // Boolean value doesn't matter because destination is nil
            self.pcIncrement = 4
        case "rem", "div":
            // Pseudoinstructions that store the remainder or quotient of src1/src2 in the destination
            if argCount != 3 {
                print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
                return nil
            }
            if args[3].rangeOfString(registerDelimiter) != nil {
                // Second source is a register
                guard let dest = Register(args[1], writing: true), src1 = Register(args[2], writing: false), src2 = Register(args[3], writing: false) else {
                    return nil
                }
                self.type = .ALUR(.Right({ return (Int32.remainderWithOverflow($0, $1).0, Int32.divideWithOverflow($0, $1).0) }, args[0] == "rem"), dest, src1, src2) // Want the boolean (moveFromHi) to be true if we want the remainder result
                self.pcIncrement = 8
            } else {
                // Second source is an immediate
                guard let dest = Register(args[1], writing: true), src1 = Register(args[2], writing: false), src2 = Immediate(args[3]) else {
                    return nil
                }
                self.type = .ALUI(.Right({ return (Int32.remainderWithOverflow($0, $1).0, Int32.divideWithOverflow($0, $1).0) }, args[0] == "rem"), dest, src1, src2) // Want the boolean (moveFromHi) to be true if we want the remainder result
                self.pcIncrement = 12
            }
        default:
            return nil
        }
    }
}