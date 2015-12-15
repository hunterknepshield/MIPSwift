//
//  Constants.swift
//  MIPSwift
//
//  Created by Hunter Knepshield on 12/10/15.
//  Copyright © 2015 Hunter Knepshield. All rights reserved.
//

import Foundation

// General constants
let mipswiftVersion = 1.0
let commandLineOptions = "[-d] [-noae] [-f file]"
let beginningPc: Int32 = 0x00400000
let beginningMem: Int32 = 0x10000000
let stdIn = NSFileHandle.fileHandleWithStandardInput()

// Constants to aid with parsing logic
let uninstantiableRegisters = ["hi", "$hi", "lo", "$lo", "pc", "$pc"] // Registers that the user can't directly access
let immutableRegisters = uninstantiableRegisters + ["$zero", "$0"] // Registers that the user can't write to
let validRegisters = ["$zero", "$0", "$at", "$1", "$v0", "$2", "$v1", "$3", "$a0", "$4", "$a1", "$5", "$a2", "$6", "$a3", "$7", "$t0", "$8", "$t1", "$9", "$t2", "$10", "$t3", "$11", "$t4", "$12", "$t5", "$13", "$t6", "$14", "$t7", "$15", "$s0", "$16", "$s1", "$17", "$s2", "$18", "$s3", "$19", "$s4", "$20", "$s5", "$21", "$s6", "$22", "$s7", "$23", "$t8", "$24", "$t9", "$25", "$k0", "$26", "$k1", "$27", "$gp", "$28", "$sp", "$29", "$fp", "$30", "$ra", "$31", "pc", "hi", "lo"]

// Register objects that are used often and/or inaccessible to the user
let zero = Register("$zero", writing: true, user: false)!
let ra = Register("$ra", writing: true, user: false)!
let pc = Register("pc", writing: true, user: false)!
let hi = Register("hi", writing: true, user: false)!
let lo = Register("lo", writing: true, user: false)!

// Strings to help with string parsing
let commandDelimiter = ":"
let directiveDelimiter = "."
let stringLiteralDelimiter = "\""
let registerDelimiter = "$"
let labelDelimiter = ":"
let commentDelimiter = "#"
let validInstructionSeparators = "(), \t"
let validInstructionSeparatorsCharacterSet = NSCharacterSet(charactersInString: validInstructionSeparators)
let validLabelRegex = Regex("^[a-zA-Z][0-9a-zA-Z_]*$")! // Labels must be alphanumeric and must start with a letter