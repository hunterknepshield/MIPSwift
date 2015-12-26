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

/// Representations of each type of MIPS instruction. Each InstructionType has
/// all appropriate associated values to complete the instruction, and they are
/// guaranteed to be valid to the extent that they can be without having
/// knowledge from the outside world (e.g. a .Jump instruction is guaranteed to
/// wrap a destination, but that destination may not be valid until the label
/// dependency is resolved).
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
	///		- unsigned: Used to determine if this instruction performs an
	///		unsigned load operation or not.
	///		- size: Used to determine the number of bytes to load or store. This
	///		value is a power of 2. 0 = byte, 1 = half-word, 2 = word.
	///		- memReg: The register that the value will be stored from or loaded
	///		into.
	///		- offset: The offset for calculation of the effective address.
	///		- addr: The register for calculation of the effective address.
	case Memory(storing: Bool, unsigned: Bool, size: Int, memReg: Register, offset: Immediate, addr: Register)
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
}

/// Representation of a MIPS instruction.
class Instruction: CustomStringConvertible {
	/// The parsed arguments of this instruction. Guaranteed to be non-empty.
	/// Must be mutable to allow for label resolution.
	var arguments = [String]()
	/// The location of this instruction in memory.
    let location: Int32
	/// The amount that this instruction increments the program counter. All
	/// simple instructions increment the program counter by just 4; pseudo
	/// instructions may increment by more than that.
    let pcIncrement: Int32
	/// Any potentially unresolved label dependencies that need more information
	/// to make the instruction complete. For example, `la $t0, undefined_label`
	/// will not be considered executable until undefined_label is actually
	/// defined, at which point this dependency can be resolved.
	var unresolvedLabelDependencies = [String]()
	/// The final parsed representation of the instruction.
    var type: InstructionType
	/// The 'pretty' formatting of this instruction's arguments.
    var instructionString: String {
        get {
			var string = self.arguments[0].stringByPaddingToLength(8, withString: " ", startingAtIndex: 0)
			if case .Memory(_) = self.type {
				// Special formatting of memory instruction, e.g. lw    $s0, 0($sp)
				string += "\(self.arguments[1]), \(self.arguments[2])(\(self.arguments[3]))"
			} else {
				// Default formatting for instructions, e.g. add    $t0, $t1, $t2
				string += self.arguments.dropFirst().joinWithSeparator(", ")
			}
			return string
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
				encoding |= dest.rawValue << dShift
				switch(src2) {
				case .Left(let reg):
					// mfhi and mflo have unusual encodings, they have no real sources to shift in
					// (src1 is hi/lo and src2 is zero, but this is just an implementation detail)
					// hi and lo's numbers are negative, so that's the easiest way to identify them
					if src1.rawValue >= 0 {
						// This isn't a mfhi/mflo instruction
						encoding |= src1.rawValue << sShift
						encoding |= reg.rawValue << tShift
					}
				case .Right(let shift):
					encoding |= src1.rawValue << tShift
					encoding |= shift << hShift
				}
				guard let functionCode = rTypeFunctionCodes[self.arguments[0]] else {
					print("Unrepresentable instruction: \(self.instructionString)")
					return INT32_MAX
				}
				encoding |= functionCode
			case let .ALUI(_, dest, src1, src2):
				// Format for I-type instructions is
				// oooo ooss ssst tttt iiii iiii iiii iiii
				encoding |= dest.rawValue << tShift
				encoding |= src1.rawValue << sShift
				encoding |= src2.unsignedExtended.signed
				guard let opcode = iTypeOpcodes[self.arguments[0]] else {
					print("Unrepresentable instruction: \(self.instructionString)")
					return INT32_MAX
				}
				encoding |= opcode << oShift
			case let .Memory(_, _, _, dest, offset, addr):
				// Format for I-type instructions is
				// oooo ooss ssst tttt iiii iiii iiii iiii
				encoding |= dest.rawValue << tShift
				encoding |= addr.rawValue << sShift
				encoding |= offset.unsignedExtended.signed
				guard let opcode = iTypeOpcodes[self.arguments[0]] else {
					print("Unrepresentable instruction: \(self.instructionString)")
					return INT32_MAX
				}
				encoding |= opcode << oShift
			case let .Jump(_, dest):
				switch(dest) {
				case .Left(let reg):
					// This is actually an R-type instruction, not a J-type
					// Format for the R-type jump:
					// 0000 00ss sss0 0000 0000 0000 00ff ffff
					encoding |= reg.rawValue << sShift
					guard let functionCode = rTypeFunctionCodes[self.arguments[0]] else {
						print("Unrepresentable instruction: \(self.instructionString)")
						return INT32_MAX
					}
					encoding |= functionCode
				case .Right(let address):
					// This is a true J-type
					// Format for J-type instructions:
					// oooo ooii iiii iiii iiii iiii iiii iiii
					guard let opcode = jTypeOpcodes[self.arguments[0]] else {
						print("Unrepresentable instruction: \(self.instructionString)")
						return INT32_MAX
					}
					encoding |= opcode << oShift
					encoding |= address & 0x03FFFFFF // Only want 26 bits
				}
			case let .Branch(_, _, src1, src2, dest):
				// Branches that compare with zero have different values for t
				// bgez = 00001 = 1, bgezal = 10001 = 17, bgtz = 00000 = 0,
				// bltz = 00000 = 0, bltzal = 10000 = 16, blez = 00000 = 0
				// Branch instructions are I-type, so their format is
				// oooo ooss ssst tttt iiii iiii iiii iiii
				// src1 is s, src2 is t
				encoding |= src1.rawValue << sShift
				let src2Num: Int32
				if src2 != nil {
					// This was a beq or bne
					src2Num = src2!.rawValue
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
					print("Unrepresentable instruction: \(self.instructionString)")
					return INT32_MAX
				}
				encoding |= opcode << oShift
				encoding |= dest.unsignedExtended.signed
			case .Syscall:
				// Technically an R-type instruction; everything but function code is 0
				guard let functionCode = rTypeFunctionCodes[self.arguments[0]] else {
					print("Unrepresentable instruction: \(self.instructionString)")
					return INT32_MAX
				}
				encoding |= functionCode
			}
			return encoding
		}
	}
    var description: String { get { return "\(self.location.hexWith0x):\t\(self.instructionString)" } }
	
	/// Initialize an instruction with all data already parsed and validated.
	/// This initializer should only be used with simple instructions. All
	/// parsing logic must be completed before this is called.
	private init(arguments: [String], location: Int32, pcIncrement: Int32, type: InstructionType) {
		self.arguments = arguments
		self.location = location
		self.pcIncrement = pcIncrement
		self.type = type
	}
	
	/// Initialize an instruction from its numeric encoding. Does not account
	/// for labels or dependencies, but will return an executable instruction.
	/// May fail if the encoding is invalid.
	class func parseEncoding(encoding: Int32, location: Int32) -> Instruction? {
		if encoding == INT32_MAX {
			// INT32_MAX is returned whenever encoding an instruction fails
			return nil
		}
		let oShift: Int32 = 26 // Number of bits to shift the opcode in
		let sShift: Int32 = 21 // Number of bits to shift the s register in
		let tShift: Int32 = 16 // Number of bits to shift the t register in
		let dShift: Int32 = 11 // Number of bits to shift the d register in
		let hShift: Int32 = 6 // Number of bits to shift the shift amount in
		// Not all of these may be used (or even valid), but they can all be generated
		let s = (encoding >> sShift) & 0x1F
		let t = (encoding >> tShift) & 0x1F
		let d = (encoding >> dShift) & 0x1F
		let regS = validRegisters[Int(s*2)]
		let regT = validRegisters[Int(t*2)]
		let regD = validRegisters[Int(d*2)]
		let imm = Immediate(Int16(bitPattern: UInt16(encoding & 0xFFFF)))
		let shift = (encoding >> hShift) & 0x1F

		let opcode = (encoding >> oShift) & 0x3F
		switch(opcode) {
		case 0:
			// An R-type instruction; get the function code to determine the instruction
			let functionCode = encoding & 0x3F // Want the lowest 6 bits
			guard let instructionName = rTypeFunctionCodes.keyForValue(functionCode) else {
				print("Invalid function code: \(functionCode)")
				return nil
			}
			switch(instructionName) {
			case "syscall":
				// The one really weird one; no arguments
				return Instruction.parseArgs([instructionName], location: location)![0]
			case "mult", "multu", "div", "divu":
				// Only have 2 arguments
				return Instruction.parseArgs([instructionName, regS, regT], location: location)![0]
			case "mfhi", "mflo":
				// Only have 1 argument
				return Instruction.parseArgs([instructionName, regD], location: location)![0]
			case "jr", "jalr":
				// Only have 1 argument
				return Instruction.parseArgs([instructionName, regS], location: location)![0]
			case "sll", "srl", "sra":
				// Shift instructions; they have 3 arguments, but one is the shift amount instead of regS
				return Instruction.parseArgs([instructionName, regD, regT, "\(shift)"], location: location)![0]
			default:
				// Most R-types take the usual 3 arguments
				return Instruction.parseArgs([instructionName, regD, regS, regT], location: location)![0]
			}
		case 1:
			// bgez, bgezal, bltz, and bltzal all have an opcode of 1, but have different values for t
			// bgez = 00001 = 1, bgezal = 10001 = 17, bltz = 00000 = 0, bltzal = 10000 = 16
			let instructionName: String
			switch(t) {
			case 0:
				instructionName = "bltz"
			case 1:
				instructionName = "bgez"
			case 16:
				instructionName = "bltzal"
			default:
				instructionName = "bgezal"
			}
			// Have to use a label then resolve
			let branch = Instruction.parseArgs([instructionName, regS, assemblerLabel], location: location)![0]
			branch.resolveLabelDependency(assemblerLabel, location: (location + imm.signExtended << 2))
			return branch
		case 2, 3:
			// A jump; needs to pass a label to parseArgs and then we already know how to resolve it
			guard let instructionName = jTypeOpcodes.keyForValue(opcode) else {
				print("Invalid opcode: \(opcode)")
				return nil
			}
			let destination = (encoding & 0x03FFFFFF) << 2 // Lower 26 bits of the encoding is the offset to the destination shifted right twice
			let jump = Instruction.parseArgs([instructionName, assemblerLabel], location: location)![0]
			jump.resolveLabelDependency(assemblerLabel, location: destination)
			return jump
		default:
			// An I-type instruction
			guard let instructionName = iTypeOpcodes.keyForValue(opcode) else {
				print("Invalid opcode: \(opcode)")
				return nil
			}
			switch(instructionName) {
			case "lui":
				// Takes 2 arguments
				return Instruction.parseArgs([instructionName, regT, "\(imm.value)"], location: location)![0]
			case "lw", "lh", "lhu", "lb", "lbu", "sw", "sh", "sb":
				// Special formatting for memory operations, but they take 3 arguments
				return Instruction.parseArgs([instructionName, regT, "\(imm.value)", regS], location: location)![0]
			case "beq", "bne":
				// Have to use a label then resolve
				let branch = Instruction.parseArgs([instructionName, regS, regT, assemblerLabel], location: location)![0]
				branch.resolveLabelDependency(assemblerLabel, location: (location + imm.signExtended << 2))
				return branch
			case "bgtz", "blez":
				// Have to use a label then resolve
				let branch = Instruction.parseArgs([instructionName, regS, assemblerLabel], location: location)![0]
				branch.resolveLabelDependency(assemblerLabel, location: (location + imm.signExtended << 2))
				return branch
			default:
				// Most I-types take 3 arguments
				return Instruction.parseArgs([instructionName, regT, regS, "\(imm.value)"], location: location)![0]
			}
		}
	}
	
	/// Resolve label dependencies that this instruction has. For example,
	/// `la	$t0, undefined_label` needs to know the location of undefined_label
	/// to be considered fully resolved, at which point,
	/// self.unresolvedLabelDependencies will have count 0.
	///
	/// - Parameters:
	///		- dependency: One of the labels that this instruction depends on.
	///		- location: The raw location of this label. If this instruction uses
	///		an offset instead of a full address, then it will be determined
	///		within this function.
	func resolveLabelDependency(dependency: String, location: Int32) {
		switch(self.type) {
		case let .Jump(link, _):
			// Overwrite dest with a new value
			self.arguments[1] = (location >> 2).hexWith0x
			self.type = .Jump(link: link, dest: .Right(location >> 2))
			// Instructions are always aligned to a 4-byte boundary, so the address can safely be shifted down 2 here
			// without losing any information; just need to bitshift back up on the way out during execution
		case let .Branch(op, link, src1, src2, _):
			// Overwrite dest with a new value, an offset from the current location
			let offset = location - self.location
			let newImm = Immediate(Int16(truncatingBitPattern: offset >> 2))
			// Instructions are always aligned to a 4-byte boundary, so the offset can safely be shifted down 2 here
			// without losing any information; just need to bitshift back up on the way out during execution
			if src2 == nil {
				// Comparing with 0, no second register argument
				self.arguments[2] = "\(newImm.value)"
			} else {
				// Comparing with a second register
				self.arguments[3] = "\(newImm.value)"
			}
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
		self.unresolvedLabelDependencies.removeAtIndex(self.unresolvedLabelDependencies.indexOf(dependency)!)
	}
	
	/// Initialize one or multiple instructions from a parsed input string,
	/// beginning at at the given location. If the arguments represent a pseudo
	/// instruction, multiple instructions will be returned in the array. All
	/// instructions returned are guaranteed to be simple. Fails if the string
	/// would generate any kind of invalid instruction. Assumes no labels or
	/// comments will be passed in.
	///
	/// - Returns: An array of Instruction objects, all of which are guaranteed
	/// to be simple.
	class func parseArgs(args: [String], location: Int32, verbose: Bool = false) -> [Instruction]? {
		let argCount = args.count - 1 // Don't count the actual instruction
		let type: InstructionType
		switch(args[0]) {
		case "syscall":
			if argCount != 0 {
				print("Instruction \(args[0]) espects 0 arguments, got \(argCount).")
				return nil
			}
			let syscall = Instruction(arguments: args, location: location, pcIncrement: 4, type: .Syscall)
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
			type = .ALUR(op: .Left(args[0] == "add" ? (&+) : { return ($0.unsigned &+ $1.unsigned).signed }), dest: dest, src1: src1, src2: .Left(src2))
			let add = Instruction(arguments: args, location: location, pcIncrement: 4, type: type)
			return [add]
		case "sub", "subu":
			if argCount != 3 {
				print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
				return nil
			}
			guard let dest = Register(args[1], writing: true), src1 = Register(args[2], writing: false), src2 = Register(args[3], writing: false) else {
				return nil
			}
			type = .ALUR(op: .Left(args[0] == "sub" ? (&-) : { return ($0.unsigned &- $1.unsigned).signed }), dest: dest, src1: src1, src2: .Left(src2))
			let sub = Instruction(arguments: args, location: location, pcIncrement: 4, type: type)
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
			let bitwise = Instruction(arguments: args, location: location, pcIncrement: 4, type: type)
			return [bitwise]
		case "slt", "sltu":
			if argCount != 3 {
				print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
				return nil
			}
			guard let dest = Register(args[1], writing: true), src1 = Register(args[2], writing: false), src2 = Register(args[3], writing: false) else {
				return nil
			}
			type = .ALUR(op: .Left(args[0] == "slt" ? { return $0 < $1 ? 1 : 0 } : { return $0.unsigned < $1.unsigned ? 1 : 0 }), dest: dest, src1: src1, src2: .Left(src2))
			let slt = Instruction(arguments: args, location: location, pcIncrement: 4, type: type)
			return [slt]
		case "sll", "sra", "srl":
			// SLL and SRA are default implementations for signed Int types, SRL is basically unsigned right shift
			if argCount != 3 {
				print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
				return nil
			}
			guard let dest = Register(args[1], writing: true), src1 = Register(args[2], writing: false), shiftAmount = Int32(args[3]) else {
				return nil
			}
			if !(0..<32 ~= shiftAmount) {
				// REPL would otherwise terminate if it were to attempt executing a bitshift of 32 bits or more
				print("Invalid shift amount: \(shiftAmount)")
				return nil
			}
			type = .ALUR(op: .Left(args[0] == "sll" ? (<<) : (args[0] == "sra" ? (>>) : { return ($0.unsigned >> $1.unsigned).signed })), dest: dest, src1: src1, src2: .Right(shiftAmount))
			let shift = Instruction(arguments: args, location: location, pcIncrement: 4, type: type)
			return [shift]
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
			type = .ALUR(op: .Left(args[0] == "sllv" ? { return $0 << ($1 & 0x1F) } : (args[0] == "srav" ? { return $0 >> ($1 & 0x1F)} : { return ($0.unsigned >> ($1 & 0x1F).unsigned).signed })), dest: dest, src1: src1, src2: .Left(src2))
			let shift = Instruction(arguments: args, location: location, pcIncrement: 4, type: type)
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
			type = .ALUI(op: args[0] == "addi" ? (&+) : { return ($0.unsigned &+ $1.unsigned).signed }, dest: dest, src1: src1, src2: src2.0)
			let addi = Instruction(arguments: args, location: location, pcIncrement: 4, type: type)
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
			let bitwisei = Instruction(arguments: args, location: location, pcIncrement: 4, type: type)
			return [bitwisei]
		case "slti", "sltiu":
			if argCount != 3 {
				print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
				return nil
			}
			guard let dest = Register(args[1], writing: true), src1 = Register(args[2], writing: false), src2 = Immediate.parseString(args[3], canReturnTwo: false) else {
				return nil
			}
			type = .ALUI(op: args[0] == "slti" ? { return $0 < $1 ? 1 : 0} : { return $0.unsigned < $1.unsigned ? 1 : 0 }, dest: dest, src1: src1, src2: src2.0)
			let slti = Instruction(arguments: args, location: location, pcIncrement: 4, type: type)
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
			let lui = Instruction(arguments: args, location: location, pcIncrement: 4, type: type)
			return [lui]
		// MARK: Memory instruction parsing
		case "lw", "lh", "lhu", "lb", "lbu", "sw", "sh", "sb":
			if argCount != 3 {
				print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
				return nil
			}
			let storing = args[0][0] == "s"
			let size = args[0][1] == "b" ? 0 : (args[0][1] == "h" ? 1 : 2)
			let unsigned = args[0].characters.count == 3
			guard let memReg = Register(args[1], writing: !storing), offset = Immediate.parseString(args[2], canReturnTwo: false), addr = Register(args[3], writing: false) else {
				return nil
			}
			type = .Memory(storing: storing, unsigned: unsigned, size: size, memReg: memReg, offset: offset.0, addr: addr)
			let memory = Instruction(arguments: args, location: location, pcIncrement: 4, type: type)
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
			let jump = Instruction(arguments: args, location: location, pcIncrement: 4, type: type)
			jump.unresolvedLabelDependencies.append(args[1])
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
			let jump = Instruction(arguments: args, location: location, pcIncrement: 4, type: type)
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
			let equal = Instruction(arguments: args, location: location, pcIncrement: 4, type: type)
			equal.unresolvedLabelDependencies.append(args[3])
			return [equal]
		case "bgez", "bgezal", "bltz", "bltzal", "bgtz", "blez":
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
			default: // blez
				op = (<=)
			}
			type = .Branch(op: op, link: link, src1: src1, src2: nil, dest: aaaa)
			let compare = Instruction(arguments: args, location: location, pcIncrement: 4, type: type)
			compare.unresolvedLabelDependencies.append(args[2])
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
			if src.1 == nil {
				// Decomposes into an addi with zero; the immediate fits within 16 bits
				// addi	dest, $0, src.lower
				let addi = Instruction.parseArgs(["addi", args[1], zero.name, "\(src.0.value)"], location: location)![0]
				return [addi]
			} else {
				// This must be decomposed into two instructions; the immediate is larger than 16 bits
				let src2 = src.1!.value
				// lui	dest, src.upper
				let lui = Instruction.parseArgs(["lui", args[1], "\(src2)"], location: location)![0]
				// ori	dest, dest, src.lower
				let ori = Instruction.parseArgs(["ori", args[1], args[1], "\(src.0.value)"], location: lui.location + lui.pcIncrement)![0]
				switch(ori.type) {
				case let .ALUI(_, dest, src1, src2):
					// The operation needs to be modified so that sign bits aren't extended to ensure proper operation
					// Otherwise, li $d, 32768 (INT16_MAX + 1) will return 0xFFFF8000 (which is INT16_MIN, -32768) when it
					// should return 0x00008000 (which is correct)
					let op: Operation32 = { return $0 | ($1 & 0xFFFF) }
					ori.type = .ALUI(op: op, dest: dest, src1: src1, src2: src2)
				default:
					// Never reached
					fatalError("Invalid ori instruction: \(ori)")
				}
				return [lui, ori]
			}
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
			let lui = Instruction.parseArgs(["lui", args[1], "\(aaaa.value)"], location: location)![0]
			lui.unresolvedLabelDependencies.append(args[2])
			// ori	dest, dest, src.lower
			let ori = Instruction.parseArgs(["ori", args[1], args[1], "\(aaaa.value)"], location: lui.location + lui.pcIncrement)![0]
			ori.unresolvedLabelDependencies.append(args[2])
			switch(ori.type) {
			case let .ALUI(_, dest, src1, src2):
				// The operation needs to be modified so that sign bits aren't extended to ensure proper operation
				let op: Operation32 = { return $0 | ($1 & 0xFFFF) }
				ori.type = .ALUI(op: op, dest: dest, src1: src1, src2: src2)
			default:
				// Never reached
				fatalError("Invalid ori instruction: \(ori)")
			}
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
			let add = Instruction.parseArgs(["add", args[1], args[2], zero.name], location: location)![0]
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
			let nor = Instruction.parseArgs(["nor", args[1], args[2], zero.name], location: location)![0]
			return [nor]
		case "clear":
			// Pseudo instruction, transforms to
			// add	dest, $0, $0
			if argCount != 1 {
				print("Instruction \(args[0]) expects 1 argument, got \(argCount).")
				return nil
			}
			guard let _ = Register(args[1], writing: true) else {
				return nil
			}
			let add = Instruction.parseArgs(["add", args[1], zero.name, zero.name], location: location)![0]
			return [add]
		case "mfhi", "mflo":
			if argCount != 1 {
				print("Instruction \(args[0]) expects 1 argument, got \(argCount).")
				return nil
			}
			guard let dest = Register(args[1], writing: true) else {
				return nil
			}
			type = .ALUR(op: .Left(+), dest: dest, src1: args[0] == "mfhi" ? hi : lo, src2: .Left(zero))
			let move = Instruction(arguments: args, location: location, pcIncrement: 4, type: type)
			return [move]
		case "mult", "multu":
			if argCount != 2 {
				print("Instruction \(args[0]) expects 2 arguments, got \(argCount).")
				return nil
			}
			guard let src1 = Register(args[1], writing: false), src2 = Register(args[2], writing: false) else {
				return nil
			}
			type = .ALUR(op: .Right({ let fullValue = (args[0] == "mult" ? $0.signed64&*$1.signed64 : ($0.unsigned64&*$1.unsigned64).signed); return (fullValue.signedUpper32, fullValue.signedLower32) }), dest: zero, src1: src1, src2: .Left(src2)) // Destination doesn't matter
			let mult = Instruction(arguments: args, location: location, pcIncrement: 4, type: type)
			return [mult]
		case "div" where argCount != 3, "divu":
			// Catches only the real div instruction, which puts $0 / $1 in lo, $0 % $1 in hi
			if argCount != 2 {
				print("Instruction \(args[0]) expects 2 arguments, got \(argCount).")
				return nil
			}
			guard let src1 = Register(args[1], writing: false), src2 = Register(args[2], writing: false) else {
				return nil
			}
			type = .ALUR(op: .Right({ return args[0] == "div" ? (Int32.remainderWithOverflow($0, $1).0, Int32.divideWithOverflow($0, $1).0) : (UInt32.remainderWithOverflow($0.unsigned, $1.unsigned).0.signed, UInt32.divideWithOverflow($0.unsigned, $1.unsigned).0.signed) }), dest: zero, src1: src1, src2: .Left(src2)) // Destination doesn't matter
			let div = Instruction(arguments: args, location: location, pcIncrement: 4, type: type)
			return [div]
		case "mul", "rem", "div":
			// Pseudoinstructions that store the product, remainder, or quotient of src1 and src2 in dest
			// src2 may be a register or an immediate
			// In the case of mul, the upper 32 bits of the product are ignored; the user may need to account for this
			if argCount != 3 {
				print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
				return nil
			}
			if validNumericRegex.test(args[3]) {
				// src2 is an immediate; decompose into 3 instructions
				guard let _ = Register(args[1], writing: true), _ = Register(args[2], writing: true), _ = Immediate.parseString(args[3], canReturnTwo: true) else {
					return nil
				}
				// li $at, src2 (which may be 1 or 2 instructions itself)
				let li = Instruction.parseArgs(["li", at.name, args[3]], location: location)!
				// mult/div src1, $at
				let math = Instruction.parseArgs([args[0] == "mul" ? "mult" : "div", args[2], at.name], location: li.last!.location + li.last!.pcIncrement)![0]
				// mflo/mfhi dest, depending on the pseudo instruction
				let move = Instruction.parseArgs([args[0] == "rem" ? "mfhi" : "mflo", args[1]], location: math.location + math.pcIncrement)![0]
				return li + [math, move]
			} else {
				// src2 is a register; decompose into 2 instructions
				guard let _ = Register(args[1], writing: true), _ = Register(args[2], writing: false), _ = Register(args[3], writing: false) else {
					return nil
				}
				// mult/div src1, src2
				let math = Instruction.parseArgs([args[0] == "mul" ? "mult" : "div", args[2], args[3]], location: location)![0]
				// mflo/mfhi dest, depending on the pseudo instruction
				let move = Instruction.parseArgs([args[0] == "rem" ? "mfhi" : "mflo", args[1]], location: math.location + math.pcIncrement)![0]
				return [math, move]
			}
		case "bge", "bgt", "ble", "blt":
			// Branch pseudo instructions, all of which decompose to a combination of slt and beq/bne
			// bge (branch on greater than or equal) becomes slt $at, src1, src2 and beq $at, $0, dest
			// bgt (branch on greater than) becomes slt $at, src2, src1 and bne $at, $0, dest
			// ble (branch on less than or equal) becomes slt $at, src2, src1 and beq $at, $0, dest
			// blt (branch on less than) becomes slt $at, src1, src2 and bne $at, $0, dest
			if argCount != 3 {
				print("Instruction \(args[0]) expects 3 arguments, got \(argCount).")
				return nil
			}
			guard validLabelRegex.test(args[3]), let _ = Register(args[1], writing: true), _ = Register(args[2], writing: false) else {
				return nil
			}
			let args1First: Bool
			switch(args[0]) {
			case "bge", "blt":
				args1First = true
			default:
				args1First = false
			}
			let comparison: String
			switch(args[0]) {
			case "bge", "ble":
				comparison = "beq"
			default:
				comparison = "bne"
			}
			let slt = Instruction.parseArgs(["slt", at.name, args1First ? args[1] : args[2], args1First ? args[2] : args[1]], location: location)![0]
			let branch = Instruction.parseArgs([comparison, at.name, zero.name, args[3]], location: slt.location + slt.pcIncrement)![0]
			// Dependency for the branch instruction is already baked in
			return [slt, branch]
		default:
			print("Invalid instruction: \(args[0])")
			return nil
		}
	}
}