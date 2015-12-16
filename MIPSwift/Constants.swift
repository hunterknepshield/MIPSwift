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
/// The initial value of the program counter.
let beginningPc: Int32 = 0x00400000
/// The initial location of the data segment.
let beginningData: Int32 = 0x10000000
/// The initial location of the stack pointer.
let beginningSp: Int32 = 0x7FFFEB38
/// The file handle associated with keyboard/standard input.
let stdIn = NSFileHandle.fileHandleWithStandardInput()

// MARK: Register parsing constants

/// Registers that the user can't directly access.
let uninstantiableRegisters = ["hi", "$hi", "lo", "$lo", "pc", "$pc"]
/// Registers that the user can't write to.
let immutableRegisters = uninstantiableRegisters + ["$zero", "$0"]
/// All register names.
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
/// The register $pc, which is used as the address of the current instruction to
/// execute.
let pc = Register("$pc", writing: true, user: false)!
/// The register $hi, which is used in 64-bit instructions, such as multiplication
/// and division.
let hi = Register("$hi", writing: true, user: false)!
/// The register $lo, which is used in 64-bit instructions, such as multiplication
/// and division.
let lo = Register("$lo", writing: true, user: false)!

// MARK: String parsing constants

/// Marks the beginning of an interpreter command, e.g. :help.
let commandDelimiter = ":"
/// Marks the beginning of an assembler directive, e.g. .text.
let directiveDelimiter = "."
/// Marks the beginning of a string argument, e.g. .ascii "This is a string."
let stringLiteralDelimiter = "\""
/// Marks the beginning of a register reference, e.g. add $t0, $t1, $t2.
let registerDelimiter = "$"
/// Marks the end of a label, e.g. some_label: add	$t0, $t1, $t2
let labelDelimiter = ":"
/// Marks the beginning of a comment, e.g. add	$t0, $t1, $t2 # This is a
/// comment.
let commentDelimiter = "#"
/// All punctuation in instruction strings that separates arguments.
let validInstructionSeparators = "(), \t"
/// The character set which represents all punctuation in instruction strings
/// that separates arguments.
let validInstructionSeparatorsCharacterSet = NSCharacterSet(charactersInString: validInstructionSeparators)
/// A regular expression that matches only valid labels. All valid labels must
/// be alphanumeric, and must start with a letter.
let validLabelRegex = Regex("^[a-zA-Z][0-9a-zA-Z_]*$")!