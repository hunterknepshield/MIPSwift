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
typealias Operation64 = (Int32, Int32) -> (hi: Int32, lo: Int32)
/// 2 operands, 1 boolean result. Generally used for branch instructions.
typealias OperationBool = (Int32, Int32) -> Bool

// MARK: InstructionType
/// Representations of each type of MIPS instruction. Each instruction type has
/// all appropriate associated values to complete the instruction.
enum InstructionType {
	/// An ALU operation that uses 2 source registers. The destination register
	/// may or may not be used based on which type the operation is.
	///
	/// - Parameters:
	///		- op: This instruction may generate either a 32-bit result or a
	///		64-bit result depending on the wrapped type.
	///		- dest: The destination register of the instruction. If the Either
	///		type wraps an Operation64, hi and lo are used as destinations
	///		instead.
	///		- src1: The first source register for the instruction.
	///		- src2: The second source register or a shift amount for the
	///		instruction.
	case ALUR(op: Either<Operation32, Operation64>, dest: Register, src1: Register, src2: Either<Register, Int32>)
	/// An ALU instruction that uses a register and an immediate value as its
	/// sources.
	///
	/// - Parameters:
	///		- op: This instruction wraps a function that always generates
	///		a 32-bit result.
	///		- dest: The destination register of the instruction.
	///		- src1: The first source for the instruction, a register.
	///		- src2: The second source for the instruction, an immediate value.
	case ALUI(op: Operation32, dest: Register, src1: Register, src2: Immediate)
	/// A memory instruction that calculates an effective address in memory and
	/// loads or stores data from that address into or from a register.
	///
	/// - Parameters:
	///		- storing: Used to determine if this instruction performs a store
	///		operation or not.
	///		- size: Used to determine the number of bytes to load or store. This
	///		value is a power of 2. 0 = byte, 1 = half-word, 2 = word.
	///		- memReg: The register that the value will be stored from or loaded
	///		into.
	///		- offset: The offset for calculation of the effective address.
	///		- addr: The register for calculation of the effective address.
	case Memory(storing: Bool, size: Int, memReg: Register, offset: Immediate, addr: Register)
	/// An unconditional jump instruction.
	///
	/// - Parameters:
	///		- link: Used to determine if this instruction links the current
	///		program counter into $ra or not.
	///		- dest: The destination register or address for the jump (must be
	///		right-shifted by 2 to be valid).
	case Jump(link: Bool, dest: Either<Register, Int32>)
	/// A conditional branch instruction.
	///
	/// - Parameters:
	///		- op: Used to determine if the branch is actually taken or not.
	///		- link: Used to determine if this instruction links the current
	///		program counter into $ra or not.
	///		- src1: The first source for the instruction.
	///		- src2: The second source for the instruction, nil if comparing with
	///		zero.
	///		- dest: The offset from the current address to jump to if this
	///		branch is taken.
	case Branch(op: OperationBool, link: Bool, src1: Register, src2: Register?, dest: Immediate)
	/// A system call. This instruction type is used to allow the assembly
	/// program to do system-level things like read input and print.
	///
	/// No parameters.
    case Syscall
	/// An assembler directive. This is technically not an instruction, but it
	/// gives the assembler information on how to arrange things within the
	/// final file, such as global data.
	///
	/// - Parameters:
	///		- directive: The actual type of directive.
	///		- args: The arguments for the directive. Guaranteed to be valid.
	case Directive(directive: DotDirective, args: [String])
	/// A non-executable instruction. This is generated whenever a line contains
	/// only labels and/or comments.
	///
	/// No parameters.
    case NonExecutable
}

// MARK: Instruction
/// Representation of a MIPS instruction.
class Instruction: CustomStringConvertible {
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
	/// Any potentially unresolved dependencies, like labels, that need more
	/// information to make this instruction complete. For example, `la	$t0,
	/// undefined_label` will not be considered executable until undefined_label
	/// is actually defined, at which point this dependency will be resolved.
	var unresolvedDependencies = [String]()
	/// The final parsed representation of the instruction.
    var type: InstructionType
	/// The 'pretty' formatting of this instruction's arguments.
    var instructionString: String? {
        get {
            if self.arguments.count == 0 {
				return nil
			}
			var string = self.arguments[0].stringByPaddingToLength(8, withString: " ", startingAtIndex: 0)
			if case let .Directive(directive, _) = self.type where [.Ascii, .Asciiz].contains(directive) {
				// Add string literal delimiters before and after arguments; only for .ascii/.asciiz
				string += stringLiteralDelimiter + self.arguments[1].toStringWithLiteralEscapes() + stringLiteralDelimiter
			} else if case .Memory(_) = self.type {
				// Special formatting of memory instruction, e.g. lw  $s0, 0($sp)
				string += "\(self.arguments[1]), \(self.arguments[2])(\(self.arguments[3]))"
			} else {
				// Default formatting for instruction, e.g. add	$t0, $t1, $t2
				var counter = 0
				self.arguments[1..<self.arguments.count].forEach({ string += $0 + (++counter < self.arguments.count - 1 ? ", " : "") })
			}
			return string
        }
    }
	/// All labels that are on this instruction, formatted to come directly
	/// after one another.
	var labelString: String? {
		get {
			if self.labels.count == 0 {
				return nil
			}
			return self.labels.joinWithSeparator(labelDelimiter) + labelDelimiter
		}
	}
	/// The 'pretty' formatting of this instruction's arguments, with any labels
	/// preceeding it, and any comments following it.
    var completeString: String? {
        get {
			if self.labels.count == 0 && self.comment == nil && self.instructionString == nil {
				// Nothing at all to print in this instruction; should never happen
				return nil
			}
			let label = self.labelString ?? ""
			let instruction = self.instructionString ?? ""
			return label.stringByPaddingToLength(24, withString: " ", startingAtIndex: 0) + instruction.stringByPaddingToLength(32, withString: " ", startingAtIndex: 0) + (self.comment ?? "")
        }
    }
	/// The raw encoding of this instruction in hexadecimal format.
	///
	/// Format for R-type instructions:
	/// 0000 00ss ssst tttt dddd dhhh hhff ffff
	///
	/// Format for I-type instructions:
	/// oooo ooss ssst tttt iiii iiii iiii iiii
	///
	/// Format for J-type instructions:
	/// oooo ooii iiii iiii iiii iiii iiii iiii
	var numericEncoding: Int32 {
		get {
			if self.arguments.count == 0 {
				return INT32_MAX
			}
			if case .Directive(_) = self.type {
				// Directives have no encoded representation
				return INT32_MAX
			}
			let oShift: Int32 = 26 // Number of bits to shift the opcode in
			let sShift: Int32 = 21 // Number of bits to shift the s register in
			let tShift: Int32 = 16 // Number of bits to shift the t register in
			let dShift: Int32 = 11 // Number of bits to shift the d register in
			let hShift: Int32 = 6 // Number of bits to shift the shift amount in
			// Immediate and function code can just be directly added with an or
			var encoding = Int32.allZeros
			switch(self.type) {
			case let .ALUR(_, dest, src1, src2):
				// Format for R-type instructions is
				// 0000 00ss ssst tttt dddd dhhh hhff ffff
				// dest is d, s, t, and h depend on whether src2 is a register or shift amount
				encoding |= dest.number << dShift
				switch(src2) {
				case .Left(let reg):
					encoding |= src1.number << sShift
					encoding |= reg.number << tShift
				case .Right(let shift):
					encoding |= src1.number << tShift
					encoding |= shift << hShift
				}
				guard let functionCode = rTypeFunctionCodes[self.arguments[0]] else {
					print("Unrepresentable instruction: \(self.completeString ?? self.rawString)")
					return INT32_MAX
				}
				encoding |= functionCode
			case let .ALUI(_, dest, src1, src2):
				// Format for I-type instructions is
				// oooo ooss ssst tttt iiii iiii iiii iiii
				encoding |= dest.number << tShift
				encoding |= src1.number << sShift
				encoding |= src2.unsignedExtended.signed()
				guard let opcode = iTypeOpcodes[self.arguments[0]] else {
					print("Unrepresentable instruction: \(self.completeString ?? self.rawString)")
					return INT32_MAX
				}
				encoding |= opcode << oShift
			case let .Memory(_, _, dest, offset, addr):
				// Format for I-type instructions is
				// oooo ooss ssst tttt iiii iiii iiii iiii
				encoding |= dest.number << tShift
				encoding |= addr.number << sShift
				encoding |= offset.unsignedExtended.signed()
				guard let opcode = iTypeOpcodes[self.arguments[0]] else {
					print("Unrepresentable instruction: \(self.completeString ?? self.rawString)")
					return INT32_MAX
				}
				encoding |= opcode << oShift
			case let .Jump(_, dest):
				switch(dest) {
				case .Left(let reg):
					// This is actually an R-type instruction, not a J-type
					// Format for the R-type jump:
					// 0000 00ss sss0 0000 0000 0000 00ff ffff
					encoding |= reg.number << sShift
					guard let functionCode = rTypeFunctionCodes[self.arguments[0]] else {
						print("Unrepresentable instruction: \(self.completeString ?? self.rawString)")
						return INT32_MAX
					}
					encoding |= functionCode
				case .Right(let address):
					// This is a true J-type
					// Format for J-type instructions:
					// oooo ooii iiii iiii iiii iiii iiii iiii
					encoding |= address & 0x03FFFFFF // Only want 26 bits
				}
			case let .Branch(_, _, src1, src2, dest):
				// Again don't know how to generate offset without information from the outside world
				// Additionally, branches that compare with zero have different values for t
				// bgez = 00001 = 1, bgezal = 10001 = 17, bgtz = 00000 = 0,
				// bltz = 00000 = 0, bltzal = 10000 = 16, blez = 00000 = 0
				// Branch instructions are I-type, so their format is
				// oooo ooss ssst tttt iiii iiii iiii iiii
				// src1 is s, src2 is t
				encoding |= src1.number << sShift
				let src2Num: Int32
				if src2 != nil {
					// This was a beq or bne
					src2Num = src2!.number
				} else {
					// This was a branch that compares with 0
					switch(self.arguments[0]) {
					case "bgez":
						src2Num = 1
					case "bgezal":
						src2Num = 17
					case "bltzal":
						src2Num = 16
					case "bltz", "bgtz", "blez":
						src2Num = 0
					default:
						src2Num = INT32_MAX
					}
				}
				encoding |= src2Num << tShift
				guard let opcode = iTypeOpcodes[self.arguments[0]] else {
					print("Unrepresentable instruction: \(self.completeString ?? self.rawString)")
					return INT32_MAX
				}
				encoding |= opcode << oShift
				encoding |= dest.unsignedExtended.signed()
				break
			case .Syscall:
				// Technically an R-type instruction; everything but function code is 0
				guard let functionCode = rTypeFunctionCodes[self.arguments[0]] else {
					print("Unrepresentable instruction: \(self.completeString ?? self.rawString)")
					return INT32_MAX
				}
				encoding |= functionCode
			default:
				print("Unrepresentable instruction: \(self.completeString ?? self.rawString)")
				return INT32_MAX
			}
			return encoding
		}
	}
    var description: String { get { return "\(self.location.toHexWith0x()):\t\(self.instructionString ?? (self.completeString ?? self.rawString))" } }
	
	/// Initialize an instruction with all data already parsed and validated.
	/// This initializer should only be used with simple instructions. All
	/// parsing logic must be completed before this is called.
	private init(rawString: String, location: Int32, pcIncrement: Int32, arguments: [String], labels: [String], comment: String?, type: InstructionType) {
		self.rawString = rawString
		self.location = location
		self.pcIncrement = pcIncrement
		self.arguments = arguments
		self.labels = labels
		self.comment = comment
		self.type = type
	}
	
	/// Resolve dependencies (some or all) that this instruction has. For
	/// example, `la	$t0, undefined_label` needs to know the location of
	/// undefined_label to be considered fully resolved, at which point,
	/// self.unresolvedDependencies will have count 0.
	///
	/// - Parameters:
	///		- dependency: One of the labels that this instruction depends on.
	///		- location: The raw location of this label. If this instruction uses
	///		an offset instead of a full address, then it will be determined
	///		within this function.
	func resolveDependency(dependency: String, location: Int32) {
		switch(self.type) {
		case let .Jump(link, _):
			// Overwrite dest with a new value
			self.arguments[1] = (location >> 2).toHexWith0x()
			self.type = .Jump(link: link, dest: .Right(location >> 2))
			// Instructions are always aligned to a 4-byte boundary, so the address can safely be shifted down 2 here
			// without losing any information; just need to bitshift back up on the way out during execution
		case let .Branch(op, link, src1, src2, _):
			// Overwrite dest with a new value, an offset from the current location
			let offset = location - self.location
			let newImm = Immediate(Int16(truncatingBitPattern: offset >> 2))
			// Instructions are always aligned to a 4-byte boundary, so the offset can safely be shifted down 2 here
			// without losing any information; just need to bitshift back up on the way out during execution
			self.arguments[3] = "\(newImm.value)"
			self.type = .Branch(op: op, link: link, src1: src1, src2: src2, dest: newImm)
		case let .ALUI(op, dest, src1, _):
			// This comes from the la instruction, which is decomposed into a lui and ori combination
			// Overwrite src2 with a new value depending on which instruction this is
			let newImm: Immediate
			switch(self.arguments[0]) {
			case "lui":
				// Want the upper 16 bits of the value
				newImm = Immediate(Int16(truncatingBitPattern: location >> 16))
				self.arguments[2] = "\(newImm.value)"
				// lui syntax has 2 arguments, not 3: lui	dest, imm
			case "ori":
				// Want the lower 16 bits of the value
				newImm = Immediate(Int16(truncatingBitPattern: location & 0xFFFF))
				self.arguments[3] = "\(newImm.value)"
				// ori syntax has 3 arguments like normal: ori	dest, src, imm
			default:
				fatalError("Invalid instruction for resolving dependency: \(self)")
			}
			self.type = .ALUI(op: op, dest: dest, src1: src1, src2: newImm)
		default:
			// Should never happen
			fatalError("Invalid instruction for resolving dependency: \(self)")
		}
		self.unresolvedDependencies.removeAtIndex(self.unresolvedDependencies.indexOf(dependency)!)
	}
	
	/// Initialize one or multiple instructions from a given input string,
	/// beginning at at the given location. If the string represents a pseudo
	/// instruction, multiple instructions will be returned in the array. All
	/// instructions returned are guaranteed to be simple. Fails if the string
	/// would generate any kind of invalid instruction.
	///
	/// - Returns: An array of Instruction objects, all of which are guaranteed
	/// to be simple.
	class func parseString(string: String, location: Int32, verbose: Bool) -> [Instruction]? {
		// Split this instruction on any whitespace or valid separator punctuation (not including newlines), ignoring empty strings
		var args = string.componentsSeparatedByCharactersInSet(validInstructionSeparatorsCharacterSet).filter({ return !$0.isEmpty })
		if verbose {
			print("All parsed arguments: \(args)")
		}
		
		// Comment removal: if anything in arguments contains a hashtag (wow, I did just call it a hashtag instead of a pound sign),
		// then remove it and any subsequent elements from the array and continue parsing
		let comment: String?
		let argumentContainsComment = args.map({ $0.containsString(commentDelimiter) })
		if let commentBeginningIndex = argumentContainsComment.indexOf(true) {
			let commentBeginningString = args[commentBeginningIndex]
			if commentBeginningString[0] == commentDelimiter {
				// The comment is the start of this argument, just remove this argument and all that follow
				comment = args[commentBeginningIndex..<args.count].joinWithSeparator(" ")
				args.removeRange(commentBeginningIndex..<args.count)
			} else {
				// The comment begins somewhere else in the argument, e.g. something:#like_this, or $t1, $t1, $t2#this
				let separatedComponents = commentBeginningString.componentsSeparatedByString(commentDelimiter)
				let nonCommentPart = separatedComponents[0]
				// nonCommentPart is guaranteed to not be the empty string
				args[commentBeginningIndex] = nonCommentPart // Put the non-comment part back in the arguments
				let commentParts = separatedComponents[1..<separatedComponents.count] + args[(commentBeginningIndex + 1)..<args.count]
				comment = commentParts.joinWithSeparator(" ")
				args.removeRange((commentBeginningIndex + 1)..<args.count) // Remove everything past the comment beginning
			}
			if verbose {
				print("Comment: \(comment!)")
			}
		} else {
			comment = nil
		}
		
		// Label identification: if anything at the beginning of arguments ends with a colon,
		// then remove it from arguments to be parsed and add it to this instruction's labels array
		var labels = [String]()
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
				labels.append(label)
				if verbose {
					print("Label: \(label)")
				}
			}
		}
		
		// Done removing things from arguments, but directives may modify further
		var arguments = args
		if args.count == 0 {
			// This instruction only contained comments and/or labels
			let nonExecutable = Instruction(rawString: string, location: location, pcIncrement: 0, arguments: arguments, labels: labels, comment: comment, type: .NonExecutable)
			return [nonExecutable]
		}
		
		let argCount = args.count - 1 // Don't count the actual instruction
		if args[0][0] == directiveDelimiter {
			// MARK: Directive parsing
			// Requires a significant amount of additional parsing to make sure arguments are in order
			// Parsing runs under the assumption that this instruction will immediately be executed,
			// even if the interpreter's execution is currently paused.
			guard let dotDirective = DotDirective(rawValue: args[0]) else {
				print("Invalid directive: \(args[0])")
				return nil
			}
			let pcIncrement: Int32
			switch(dotDirective) {
			case .Align:
				// Align current address to be on a 2^n-byte boundary; 1 argument, must be 0, 1, or 2
				if argCount != 1 {
					print("Directive \(dotDirective.rawValue) expects 1 argument, got \(argCount).")
					return nil
				} else if !["0", "1", "2"].contains(args[1]) {
					print("Invalid alignment factor: \(args[1])")
					return nil
				}
				let n = Int32(args[1])! // n is either 0, 1, or 2
				let alignment = 1 << n // alignment is either 1, 2, or 4
				let offset = location % alignment
				pcIncrement = offset == 0 ? 0 : alignment - offset
			case .Data, .Text:
				// Change to data segment (address may be supplied; unimplemented as of now)
				if argCount != 0 {
					print("Directive \(dotDirective.rawValue) expects 0 arguments, got \(argCount).")
					return nil
				}
				pcIncrement = 0
			case .Global:
				// Declare a global label; 1 argument
				pcIncrement = 0
				if argCount != 1 {
					print("Directive \(dotDirective.rawValue) expects 1 argument, got \(argCount).")
					return nil
				} else if !validLabelRegex.test(args[1]) {
					print("Invalid label: \(args[1])")
					return nil
				}
			case .Ascii, .Asciiz:
				// Interesting problem:
				// .asciiz		"This is the string."		# This " confuses things
				// .asciiz		"This is the # string."		# Doesn't confuse things, but comment is thought to begin at first hashtag
				// Allocate space for a string; 1 argument, though it may have been split by parsing above, so it needs to be reassembled
				if argCount == 0 {
					// Can't just check argCount != 1 because the string may have been split up above
					print("Directive \(dotDirective.rawValue) expects 1 argument, got 0.")
					return nil
				}
				// Need to ensure that the whitespace from the original instruction's argument isn't lost
				guard let stringBeginningRange = string.rangeOfString(stringLiteralDelimiter) else {
					print("Directive \(dotDirective.rawValue) expects string literal.")
					return nil
				}
				guard let stringEndRange = string.rangeOfString(stringLiteralDelimiter, options: [.BackwardsSearch]) where stringBeginningRange.endIndex <= stringEndRange.startIndex else {
					print("String literal expects closing delimiter.")
					return nil
				}
				let rawArgument = string.substringWithRange(stringBeginningRange.endIndex..<stringEndRange.startIndex)
				let directivePart = string[string.startIndex..<stringBeginningRange.endIndex]
				if directivePart.characters.count + rawArgument.characters.count + 1 != string.characters.count {
					// There is trailing stuff after the string literal is closed, check if it's a comment
					let trailingStuff = string[stringEndRange.endIndex..<string.endIndex]
					if trailingStuff.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet()).hasPrefix(commentDelimiter) {
						// Trailing stuff is just a comment, allow this
					} else {
						print("Invalid data after string literal: \(trailingStuff)")
						return nil
					}
				}
				guard let escapedArgument = try? rawArgument.toEscapedString() else {
					return nil // Couldn't escape this string
				}
				pcIncrement = Int32(escapedArgument.lengthOfBytesUsingEncoding(NSASCIIStringEncoding) + (dotDirective == .Asciiz ? 1 : 0)) // Add 1 for null terminator if needed
				arguments = [args[0], escapedArgument + (dotDirective == .Asciiz ? "\0" : "")]
			case .Space:
				// Allocate n bytes
				if argCount != 1 {
					print("Directive \(dotDirective.rawValue) expects 1 argument, got \(argCount).")
					return nil
				}
				guard let n = Int32(args[1]) where n >= 0 else {
					print("Invalid number of bytes to allocate: \(args[1])")
					return nil
				}
				pcIncrement = n
			case .Byte, .Half, .Word:
				// Allocate space for n bytes with initial values
				if argCount == 0 {
					print("Directive \(dotDirective.rawValue) expects arguments, got none.")
					return nil
				}
				// Ensure the location that these values will be written to is aligned
				let bytesPerArgument: Int32 = (dotDirective == .Byte ? 1 : (dotDirective == .Half ? 2 : 4))
				if location % bytesPerArgument != 0 {
					// This is an unaligned address for this data size
					print("Directive \(dotDirective.rawValue) must be on a memory address of alignment \(bytesPerArgument).")
					return nil
				}
				// Ensure every argument can be transformed to an appropriately sized integer
				var validArgs = true
				switch(dotDirective) {
				case .Byte:
					args[1..<args.count].forEach({ if Int8($0) == nil { print("Invalid argument: \($0)"); validArgs = false } })
				case .Half:
					args[1..<args.count].forEach({ if Int16($0) == nil { print("Invalid argument: \($0)"); validArgs = false } })
				case .Word:
					args[1..<args.count].forEach({ if Int32($0) == nil { print("Invalid argument: \($0)"); validArgs = false } })
				default:
					// Never reached
					fatalError("Invalid dot directive: \(dotDirective.rawValue)")
				}
				if !validArgs {
					return nil
				}
				pcIncrement = Int32(argCount)*bytesPerArgument
			}
			let directive = Instruction(rawString: string, location: location, pcIncrement: pcIncrement, arguments: arguments, labels: labels, comment: comment, type: .Directive(directive: dotDirective, args: Array(arguments[1..<arguments.count])))
			return [directive]
		}
		
		let type: InstructionType
		switch(args[0]) {
		case "syscall":
			if argCount != 0 {
				print("Instruction \(args[0]) espects 0 arguments, got \(argCount).")
				return nil
			}
			let syscall = Instruction(rawString: string, location: location, pcIncrement: 4, arguments: arguments, labels: labels, comment: comment, type: .Syscall)
			return [syscall]
		// MARK: ALU-R instruction parsing
		case "add", "addu":
			if argCount != 3 {
				print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
				return nil
			}
			guard let dest = Register(args[1], writing: true), src1 = Register(args[2], writing: false), src2 = Register(args[3], writing: false) else {
				return nil
			}
			type = .ALUR(op: .Left(args[0] == "add" ? (&+) : { return ($0.unsigned() &+ $1.unsigned()).signed() }), dest: dest, src1: src1, src2: .Left(src2))
			let add = Instruction(rawString: string, location: location, pcIncrement: 4, arguments: arguments, labels: labels, comment: comment, type: type)
			return [add]
		case "sub", "subu":
			if argCount != 3 {
				print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
				return nil
			}
			guard let dest = Register(args[1], writing: true), src1 = Register(args[2], writing: false), src2 = Register(args[3], writing: false) else {
				return nil
			}
			type = .ALUR(op: .Left(args[0] == "sub" ? (&-) : { return ($0.unsigned() &- $1.unsigned()).signed() }), dest: dest, src1: src1, src2: .Left(src2))
			let sub = Instruction(rawString: string, location: location, pcIncrement: 4, arguments: arguments, labels: labels, comment: comment, type: type)
			return [sub]
		case "and", "or", "xor", "nor":
			if argCount != 3 {
				print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
				return nil
			}
			guard let dest = Register(args[1], writing: true), src1 = Register(args[2], writing: false), src2 = Register(args[3], writing: false) else {
				return nil
			}
			let type = InstructionType.ALUR(op: .Left(args[0] == "and" ? (&) : (args[0] == "or" ? (|) : (args[0] == "xor" ? (^) : ({ return ~($0 | $1) })))), dest: dest, src1: src1, src2: .Left(src2))
			let bitwise = Instruction(rawString: string, location: location, pcIncrement: 4, arguments: arguments, labels: labels, comment: comment, type: type)
			return [bitwise]
		case "slt", "sltu":
			if argCount != 3 {
				print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
				return nil
			}
			guard let dest = Register(args[1], writing: true), src1 = Register(args[2], writing: false), src2 = Register(args[3], writing: false) else {
				return nil
			}
			type = .ALUR(op: .Left(args[0] == "slt" ? { return $0 < $1 ? 1 : 0 } : { return $0.unsigned() < $1.unsigned() ? 1 : 0 }), dest: dest, src1: src1, src2: .Left(src2))
			let slt = Instruction(rawString: string, location: location, pcIncrement: 4, arguments: arguments, labels: labels, comment: comment, type: type)
			return [slt]
		case "sll", "sra", "srl":
			// SLL and SRA are default implementations for signed Int types, SRL is basically unsigned right shift
			if argCount != 3 {
				print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
				return nil
			}
			guard let dest = Register(args[1], writing: true), src1 = Register(args[2], writing: false), shift = Int32(args[3]) else {
				return nil
			}
			if !(0..<32 ~= shift) {
				// REPL would otherwise terminate if it were to attempt executing a bitshift of 32 bits or more
				print("Invalid shift amount: \(shift)")
				return nil
			}
			type = .ALUR(op: .Left(args[0] == "sll" ? (<<) : (args[0] == "sra" ? (>>) : { return ($0.unsigned() >> $1.unsigned()).signed() })), dest: dest, src1: src1, src2: .Right(shift))
			let shifti = Instruction(rawString: string, location: location, pcIncrement: 4, arguments: arguments, labels: labels, comment: comment, type: type)
			return [shifti]
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
			type = .ALUR(op: .Left(args[0] == "sllv" ? { return $0 << ($1 & 0x1F) } : (args[0] == "srav" ? { return $0 >> ($1 & 0x1F)} : { return ($0.unsigned() >> ($1 & 0x1F).unsigned()).signed() })), dest: dest, src1: src1, src2: .Left(src2))
			let shift = Instruction(rawString: string, location: location, pcIncrement: 4, arguments: arguments, labels: labels, comment: comment, type: type)
			return [shift]
		// MARK: ALU-I instruction parsing
		case "addi", "addiu":
			if argCount != 3 {
				print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
				return nil
			}
			guard let dest = Register(args[1], writing: true), src1 = Register(args[2], writing: false), src2 = Immediate.parseString(args[3], canReturnTwo: false) else {
				return nil
			}
			type = .ALUI(op: args[0] == "addi" ? (&+) : { return ($0.unsigned() &+ $1.unsigned()).signed() }, dest: dest, src1: src1, src2: src2.0)
			let addi = Instruction(rawString: string, location: location, pcIncrement: 4, arguments: arguments, labels: labels, comment: comment, type: type)
			return [addi]
		case "andi", "ori", "xori":
			if argCount != 3 {
				print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
				return nil
			}
			guard let dest = Register(args[1], writing: true), src1 = Register(args[2], writing: false), src2 = Immediate.parseString(args[3], canReturnTwo: false) else {
				return nil
			}
			type = .ALUI(op: args[0] == "andi" ? (&) : (args[0] == "ori" ? (|) : (^)), dest: dest, src1: src1, src2: src2.0)
			let bitwisei = Instruction(rawString: string, location: location, pcIncrement: 4, arguments: arguments, labels: labels, comment: comment, type: type)
			return [bitwisei]
		case "slti", "sltiu":
			if argCount != 3 {
				print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
				return nil
			}
			guard let dest = Register(args[1], writing: true), src1 = Register(args[2], writing: false), src2 = Immediate.parseString(args[3], canReturnTwo: false) else {
				return nil
			}
			type = .ALUI(op: args[0] == "slti" ? { return $0 < $1 ? 1 : 0} : { return $0.unsigned() < $1.unsigned() ? 1 : 0 }, dest: dest, src1: src1, src2: src2.0)
			let slti = Instruction(rawString: string, location: location, pcIncrement: 4, arguments: arguments, labels: labels, comment: comment, type: type)
			return [slti]
		case "lui":
			if argCount != 2 {
				print("Instruction \(args[0]) expects 2 arguments, got \(argCount).")
				return nil
			}
			guard let dest = Register(args[1], writing: true), src = Immediate.parseString(args[2], canReturnTwo: false) else {
				return nil
			}
			type = .ALUI(op: { return $1 << 16 }, dest: dest, src1: zero, src2: src.0)
			let lui = Instruction(rawString: string, location: location, pcIncrement: 4, arguments: arguments, labels: labels, comment: comment, type: type)
			return [lui]
		// MARK: Memory instruction parsing
		case "lw", "lh", "lb", "sw", "sh", "sb":
			if argCount != 3 {
				print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
				return nil
			}
			let storing = args[0][0] == "s"
			let size = args[0][1] == "b" ? 0 : args[0][1] == "h" ? 1 : 2
			guard let memReg = Register(args[1], writing: !storing), offset = Immediate.parseString(args[2], canReturnTwo: false), addr = Register(args[3], writing: false) else {
				return nil
			}
			type = .Memory(storing: storing, size: size, memReg: memReg, offset: offset.0, addr: addr)
			let memory = Instruction(rawString: string, location: location, pcIncrement: 4, arguments: arguments, labels: labels, comment: comment, type: type)
			return [memory]
		// MARK: Jump instruction parsing
		case "j", "jal":
			if argCount != 1 {
				print("Instruction \(args[0]) expects 1 argument, got \(argCount).")
				return nil
			}
			if !validLabelRegex.test(args[1]) {
				print("Invalid label: \(args[1])")
				return nil
			}
			type = .Jump(link: args[0] == "jal", dest: .Right(aaaa.signExtended))
			let jump = Instruction(rawString: string, location: location, pcIncrement: 4, arguments: arguments, labels: labels, comment: comment, type: type)
			jump.unresolvedDependencies.append(args[1])
			return [jump]
		case "jr", "jalr":
			if argCount != 1 {
				print("Instruction \(args[0]) expects 1 argument, got \(argCount).")
				return nil
			}
			guard let dest = Register(args[1], writing: false) else {
				return nil
			}
			type = .Jump(link: args[0] == "jalr", dest: .Left(dest))
			let jump = Instruction(rawString: string, location: location, pcIncrement: 4, arguments: arguments, labels: labels, comment: comment, type: type)
			return [jump]
		// MARK: Branch instruction parsing
		case "beq", "bne":
			if argCount != 3 {
				print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
				return nil
			}
			guard validLabelRegex.test(args[3]), let src1 = Register(args[1], writing: false), src2 = Register(args[2], writing: false) else {
				return nil
			}
			type = .Branch(op: args[0] == "beq" ? (==) : (!=), link: false, src1: src1, src2: src2, dest: aaaa)
			let equal = Instruction(rawString: string, location: location, pcIncrement: 4, arguments: arguments, labels: labels, comment: comment, type: type)
			equal.unresolvedDependencies.append(args[3])
			return [equal]
		case "bgez", "bgezal", "bltz", "bltzal", "bgtz", "bltez":
			if argCount != 2 {
				print("Instruction \(args[0]) expects 2 arguments, got \(argCount).")
				return nil
			}
			guard validLabelRegex.test(args[2]), let src1 = Register(args[1], writing: false) else {
				return nil
			}
			let link = args[0] == "bgezal" || args[0] == "blzal"
			// All comparisons are with zero as the second argument
			let op: OperationBool
			switch(args[0]) {
			case "bgez", "bgezal":
				op = (>=)
			case "bltz", "bltzal":
				op = (<)
			case "bgtz":
				op = (>)
			case "bltez":
				op = (<=)
			default:
				fatalError("Invalid branch instruction \(args[0])")
			}
			type = .Branch(op: op, link: link, src1: src1, src2: nil, dest: aaaa)
			let compare = Instruction(rawString: string, location: location, pcIncrement: 4, arguments: arguments, labels: labels, comment: comment, type: type)
			compare.unresolvedDependencies.append(args[2])
			return [compare]
		// MARK: More complex/pseudo instruction parsing
		case "li":
			// Pseudo instruction to load a 32-bit immediate into a register
			if argCount != 2 {
				print("Instruction \(args[0]) expects 2 arguments, got \(argCount).")
				return nil
			}
			guard let _ = Register(args[1], writing: true), src = Immediate.parseString(args[2], canReturnTwo: true) else {
				return nil
			}
			// Determine what to load into the upper 16 bits of the register, will be 0 if the immediate isn't larger than 16 bits
			let src2: Int16
			if src.1 != nil {
				src2 = src.1!.value
			} else {
				src2 = 0
			}
			// This must be decomposed into two instructions, since the immediate may be 32 bits
			// lui	dest, src.upper
			let lui = Instruction.parseString("lui " + args[1] + ", \(src2)", location: location, verbose: false)![0]
			lui.labels = labels
			lui.comment = comment
			// ori	dest, dest, src.lower
			let ori = Instruction.parseString("ori " + args[1] + ", " + args[1] + ", \(src.0.value)", location: location + 4, verbose: false)![0]
			return [lui, ori]
		case "la":
			// Pseudo instruction to load a 32-bit address of a label into a register
			if argCount != 2 {
				print("Instruction \(args[0]) expects 2 arguments, got \(argCount).")
				return nil
			}
			guard validLabelRegex.test(args[2]), let _ = Register(args[1], writing: true) else {
				return nil
			}
			// This must be decomposed into two instructions, since addresses are always 32 bits
			// lui	dest, src.upper
			let lui = Instruction.parseString("lui " + args[1] + ", \(aaaa.value)", location: location, verbose: false)![0]
			lui.unresolvedDependencies.append(args[2])
			lui.labels = labels
			lui.comment = comment
			// ori	dest, dest, src.lower
			let ori = Instruction.parseString("ori " + args[1] + ", " + args[1] + ", \(aaaa.value)", location: location + 4, verbose: false)![0]
			ori.unresolvedDependencies.append(args[2])
			return [lui, ori]
		case "move":
			// Pseudo instruction, transforms to
			// add	dest, src, $0
			if argCount != 2 {
				print("Instruction \(args[0]) expects 2 arguments, got \(argCount).")
				return nil
			}
			guard let _ = Register(args[1], writing: true), _ = Register(args[2], writing: false) else {
				return nil
			}
			let add = Instruction.parseString("add " + args[1] + ", " + args[2] + ", $zero", location: location, verbose: false)![0]
			add.labels = labels
			add.comment = comment
			return [add]
		case "not":
			// Pseudo instruction, transforms to
			// nor	dest, src, $0
			if argCount != 2 {
				print("Instruction \(args[0]) expects 2 arguments, got \(argCount).")
				return nil
			}
			guard let _ = Register(args[1], writing: true), _ = Register(args[2], writing: false) else {
				return nil
			}
			let nor = Instruction.parseString("nor " + args[1] + ", " + args[2] + ", $zero", location: location, verbose: false)![0]
			nor.labels = labels
			nor.comment = comment
			return [nor]
		case "clear":
			// Pseudo instruction, transforms to
			// add	dest, $0, $0
			if argCount != 1 {
				print("Instruction \(args[0]) expects 2 arguments, got \(argCount).")
				return nil
			}
			guard let _ = Register(args[1], writing: true) else {
				return nil
			}
			let add = Instruction.parseString("add " + args[1] + ", $zero, $zero", location: location, verbose: false)![0]
			add.labels = labels
			add.comment = comment
			return [add]
		case "mfhi", "mflo":
			if argCount != 1 {
				print("Instruction \(args[0]) expects 2 arguments, got \(argCount).")
				return nil
			}
			guard let dest = Register(args[1], writing: true) else {
				return nil
			}
			type = .ALUR(op: .Left(+), dest: dest, src1: args[0] == "mfhi" ? hi : lo, src2: .Left(zero))
			let mfhi = Instruction(rawString: string, location: location, pcIncrement: 4, arguments: arguments, labels: labels, comment: comment, type: type)
			return [mfhi]
		case "mult", "multu":
			if argCount != 2 {
				print("Instruction \(args[0]) expects 2 arguments, got \(argCount).")
				return nil
			}
			guard let src1 = Register(args[1], writing: false), src2 = Register(args[2], writing: false) else {
				return nil
			}
			type = .ALUR(op: .Right({ let fullValue = (args[0] == "mult" ? $0.signed64()&*$1.signed64() : ($0.unsigned64()&*$1.unsigned64()).signed()); return (fullValue.signedUpper32(), fullValue.signedLower32()) }), dest: zero, src1: src1, src2: .Left(src2)) // Destination doesn't matter
			let mult = Instruction(rawString: string, location: location, pcIncrement: 4, arguments: arguments, labels: labels, comment: comment, type: type)
			return [mult]
		case "mul":
			// Multiplication pseudo instruction, which stores the lower 32 bits of src1*src2 in the destination
			if argCount != 3 {
				print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
				return nil
			}
			guard let _ = Register(args[1], writing: true), _ = Register(args[2], writing: false), _ = Register(args[3], writing: false) else {
				return nil
			}
			// Decompose into 2 instructions
			// mult	src1, src2
			let mult = Instruction.parseString("mult " + args[2] + ", " + args[3], location: location, verbose: false)![0]
			mult.labels = labels
			mult.comment = comment
			// mflo	dest
			let mflo = Instruction.parseString("mflo " + args[1], location: location + 4, verbose: false)![0]
			return [mult, mflo]
		case "div" where argCount != 3, "divu":
			// Catches only the real div instruction, which puts $0/$1 in lo, $0%$1 in hi
			if argCount != 2 {
				print("Instruction \(args[0]) expects 2 arguments, got \(argCount).")
				return nil
			}
			guard let src1 = Register(args[1], writing: false), src2 = Register(args[2], writing: false) else {
				return nil
			}
			type = .ALUR(op: .Right({ return args[0] == "div" ? (Int32.remainderWithOverflow($0, $1).0, Int32.divideWithOverflow($0, $1).0) : (UInt32.remainderWithOverflow($0.unsigned(), $1.unsigned()).0.signed(), UInt32.divideWithOverflow($0.unsigned(), $1.unsigned()).0.signed()) }), dest: zero, src1: src1, src2: .Left(src2)) // Destination doesn't matter
			let div = Instruction(rawString: string, location: location, pcIncrement: 4, arguments: arguments, labels: labels, comment: comment, type: type)
			return [div]
		case "rem", "div":
			// Pseudoinstructions that store the remainder or quotient of src1/src2 in the destination
			if argCount != 3 {
				print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
				return nil
			}
			guard let _ = Register(args[1], writing: true), _ = Register(args[2], writing: false), _ = Register(args[3], writing: false) else {
				return nil
			}
			// Decompose this into 2 instructions
			// div	src1, src2
			let div = Instruction.parseString("div " + args[2] + ", " + args[3], location: location, verbose: false)![0]
			div.labels = labels
			div.comment = comment
			// mflo	dest/mfhi dest, depending on the pseudo instruction
			let move = Instruction.parseString((args[0] == "rem" ? "mfhi " : "mflo ") + args[1], location: location + 4, verbose: false)![0]
			return [div, move]
		default:
			return nil
		}
	}
}