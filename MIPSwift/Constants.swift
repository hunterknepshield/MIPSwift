//
//  Constants.swift
//  MIPSwift
//
//  Created by Hunter Knepshield on 12/10/15.
//  Copyright © 2015 Hunter Knepshield. All rights reserved.
//

import Foundation

// MARK: General constants

/// The version of this program.
let mipswiftVersion = 1.0
/// All valid command-line options.
let commandLineOptions = "[-d] [-noae] [-f file]"
/// The beginning location of the text segment. Also the initial value of the
/// program counter.
let beginningText: Int32 = 0x00400000
/// The beginning location of the data segment.
let beginningData: Int32 = 0x10000000
/// The last byte of memory accessible to the user's program, 0x7FFFFFFF.
let memoryLimit = INT32_MAX
/// The initial location of the stack pointer. The stack grows towards smaller
/// addresses. If the user attempts to increment the stack pointer instead of
/// decrementing it, the REPL will attempt to stop it before causing an integer
/// overflow.
let beginningSp: Int32 = 0x7FFFFFFC
/// The initial return address. When the program jumps to this address, it's
/// assumed to mean same thing as using the exit syscall (exit code 0).
let beginningRa = Int32(bitPattern: 0x80000000)
/// The file handle associated with keyboard/standard input.
let stdIn = NSFileHandle.fileHandleWithStandardInput()
/// An immediate with value 0xAAAA, to represent an uninitialized value within
/// an instruction; makes memory dump reading simpler to find unresolved
/// instructions. Binary encoding: 1010 1010 1010 1010.
let aaaa = Immediate(Int16(bitPattern: UInt16(0xAAAA)))

// MARK: Register parsing constants

/// Registers that the user can't directly access.
let uninstantiableRegisters = ["hi", "$hi", "lo", "$lo", "pc", "$pc"]
/// Registers that the user can't write to.
let immutableRegisters = uninstantiableRegisters + ["$zero", "$0"]
/// All register names. If a raw number to a register is generated, its 'pretty'
/// alias can be found at validRegisters[2\*i], e.g. validRegisters[0] = "$zero",
/// validRegisters[2\*3] = "$v1", etc.
let validRegisters = ["$zero", "$0", "$at", "$1", "$v0", "$2", "$v1", "$3", "$a0", "$4", "$a1", "$5", "$a2", "$6", "$a3", "$7", "$t0", "$8", "$t1", "$9", "$t2", "$10", "$t3", "$11", "$t4", "$12", "$t5", "$13", "$t6", "$14", "$t7", "$15", "$s0", "$16", "$s1", "$17", "$s2", "$18", "$s3", "$19", "$s4", "$20", "$s5", "$21", "$s6", "$22", "$s7", "$23", "$t8", "$24", "$t9", "$25", "$k0", "$26", "$k1", "$27", "$gp", "$28", "$sp", "$29", "$fp", "$30", "$ra", "$31", "pc", "$pc", "hi", "$hi", "lo", "$lo"]

// MARK: Register constants

/// The register $0, which always contains tha value 0.
let zero = Register("$zero", writing: true, user: false)!
/// The register $at, which is used by the assembler for storing temporary
/// values in pseudo instruction expansion.
let at = Register("$at", writing: true, user: false)!
/// The register $ra, which is used as the return address for function calls.
let ra = Register("$ra", writing: true, user: false)!
/// The register $sp, which is used as the address of the top of the stack.
let sp = Register("$sp", writing: true, user: false)!
/// The register $fp, which is used as the address of the base of the current
/// stack frame.
let fp = Register("$fp", writing: true, user: false)!
/// The register $gp, which is used as a pointer into the data segment.
/// Generally unused.
let gp = Register("$gp", writing: true, user: false)!
/// The register hi, which is used in 64-bit instructions, such as multiplication
/// and division.
let hi = Register("hi", writing: true, user: false)!
/// The register lo, which is used in 64-bit instructions, such as multiplication
/// and division.
let lo = Register("lo", writing: true, user: false)!
/// The register pc, which is used as the address of the current instruction to
/// execute.
let pc = Register("pc", writing: true, user: false)!
/// The register $a0, which is used for argument passing, including in syscalls.
let a0 = Register("$a0", writing: true, user: false)!
/// The register $a1, which is used for argument passing, including in syscalls.
let a1 = Register("$a1", writing: true, user: false)!
/// The register $a2, which is used for argument passing, including in syscalls.
let a2 = Register("$a2", writing: true, user: false)!
/// The register $a3, which is used for argument passing, including in syscalls.
let a3 = Register("$a3", writing: true, user: false)!
/// The register $v0, which is used for return values, including in syscalls.
let v0 = Register("$v0", writing: true, user: false)!
/// The register $v1, which is used for return values, including in syscalls.
let v1 = Register("$v1", writing: true, user: false)!

// MARK: String parsing constants and regular expressions

/// Marks the beginning of an interpreter command, e.g. :help.
let commandDelimiter = ":"
/// Marks the beginning of an assembler directive, e.g. .text.
let directiveDelimiter = "."
/// Marks the beginning or end of a string argument, e.g. .asciiz "This is a string."
let stringLiteralDelimiter = "\""
/// Marks the beginning or end of a character argument, e.g. CHAR_A = 'A'
let characterLiteralDelimiter = "'"
/// Marks the beginning of a register reference, e.g. add $t0, $t1, $t2.
let registerDelimiter = "$"
/// Marks the end of a label, e.g. some_label: add	$t0, $t1, $t2
let labelDelimiter = ":"
/// Marks the beginning of a comment, e.g. add	$t0, $t1, $t2 # This is a
/// comment.
let commentDelimiter = "#"
/// All punctuation and whitespace in instruction strings that separates
/// arguments.
let validInstructionSeparators = "(), \t"
/// The character set which represents all punctuation and whitespace in
/// instruction strings that separates arguments.
let validInstructionSeparatorsCharacterSet = NSCharacterSet(charactersInString: validInstructionSeparators)
/// A regular expression that matches only valid labels. All valid labels must
/// be alphanumeric, must start with a letter, and must be at the beginning of
/// the string.
let validLabelRegex = Regex("^[a-zA-Z][\\w]*$")!
/// A regular expression that matches only valid label definitions. Similar to
/// validLabelRegex, but includes consideration for the ending colon delimiter.
let validLabelDefinitionRegex = Regex("^[a-zA-Z][\\w]*\(labelDelimiter)")!
/// A regular expression that matches comments at the end of a string.
let validCommentRegex = Regex("\(commentDelimiter).*$")!
/// A regular expression that matches only valid string literals, with
/// consideration for escape sequences.
let validStringLiteralRegex = Regex("\"([^\"\\\\]|\\\\.)*\"")!
/// A regular expression that matches only valid .ascii and .asciiz directives.
/// These directives are the messiest to parse because their string literals may
/// contain escape sequences, other (escaped) string literal delimiters, comment
/// delimiters, etc.
///
/// This regex has two capture groups. The first captures the string literal
/// argument, including the quotes. The second captures the comment, if there is
/// one.
let validAsciiDirectiveRegex = Regex("^\\.asciiz?\\s+(\"(?:[^\"\\\\]|\\\\.)*\")\\s*(\(commentDelimiter).*)?$")!
/// A regular expression that matches only valid equals directives. These
/// directives are also fairly messy to parse because they may contain no
/// whitespace.
///
/// This regex has two capture groups. The first captures the string that gives
/// the name of the constant. The second captures its value.
let validEqualsDirectiveRegex = Regex("^([a-zA-Z][\\w]*)\\s*=\\s*((?:0[xX][\\da-fA-F]+)|(?:-?\\d+))$")!
/// A regular expression that matches a valid number, either in decimal or
/// hexadecimal.
let validNumericRegex = Regex("^((0[xX][\\da-fA-F]+)|(-?\\d+))$")!
/// A regular expression that matches only valid hexadecimal numbers that may be
/// converted to a 32-bit number (1 to 8 hex characters).
let valid32BitHexRegex = Regex("^0[xX][\\da-fA-F]{1,8}$")!
/// A regular expression that matches only valid hexadecimal numbers that may be
/// converted to a 16-bit number (1 to 4 hex characters).
let valid16BitHexRegex = Regex("^0[xX][\\da-fA-F]{1,4}$")!

// MARK: Instruction parsing constants

/// The generic label used when decoding instructions that require label
/// resolution from their numeric encodings.
let assemblerLabel = "ASSEMBLER_TEMP"
/// Maps R-type instruction names to function codes (all R-type opcodes are
/// 000000).
let rTypeFunctionCodes: [String : Int32] = ["add": 0x20, "addu": 0x21, "and": 0x24, "break": 0x0D, "div": 0x1A, "divu": 0x1B, "jalr": 0x09, "jr": 0x08, "mfhi": 0x10, "mflo": 0x12, "mthi": 0x11, "mtlo": 0x13, "mult": 0x18, "multu": 0x19, "nor": 0x27, "or": 0x25, "sll": 0x00, "sllv": 0x04, "slt": 0x2A, "sltu": 0x2B, "sra": 0x03, "srav": 0x07, "srl": 0x02, "srlv": 0x06, "sub": 0x22, "subu": 0x23, "syscall": 0x0C, "xor": 0x26]
/// Maps I-type instruction names to opcodes.
let iTypeOpcodes: [String : Int32] = ["addi": 0x08, "addiu": 0x09, "andi": 0x0C, "beq": 0x04, "bgez": 0x01, "bgezal": 0x01, "bgtz": 0x07, "blez": 0x06, "bltz": 0x01, "bltzal": 0x01, "bne": 0x05, "lb": 0x20, "lbu": 0x24, "lh": 0x21, "lhu": 0x25, "lui": 0x0F, "lw": 0x23, "lwc1": 0x31, "ori": 0x0D, "sb": 0x28, "slti": 0x0A, "sltiu": 0x0B, "sh": 0x29, "sw": 0x2B, "swc1": 0x39, "xori": 0x0E]
/// Maps J-type instruction names to opcodes.
let jTypeOpcodes : [String : Int32] = ["j": 0x02, "jal": 0x03]