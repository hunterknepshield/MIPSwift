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
let beginningPc: Int32 = 0x00400000
let beginningMem: Int32 = 0x10000000

// Constants to aid with parsing logic
let immutableRegisters = ["hi", "$hi", "lo", "$lo", "pc", "$pc", "$zero", "$0"]
let validRegisters = ["$zero", "$0", "$at", "$1", "$v0", "$2", "$v1", "$3", "$a0", "$4", "$a1", "$5", "$a2", "$6", "$a3", "$7", "$t0", "$8", "$t1", "$9", "$t2", "$10", "$t3", "$11", "$t4", "$12", "$t5", "$13", "$t6", "$14", "$t7", "$15", "$s0", "$16", "$s1", "$17", "$s2", "$18", "$s3", "$19", "$s4", "$20", "$s5", "$21", "$s6", "$22", "$s7", "$23", "$t8", "$24", "$t9", "$25", "$k0", "$26", "$k1", "$27", "$gp", "$28", "$sp", "$29", "$fp", "$30", "$ra", "$31", "pc", "hi", "lo"]

// Register objects that are used often and/or inaccessible to the user
let zero = Register("$zero", user: false)!
let pc = Register("pc", user: false)!
let hi = Register("hi", user: false)!
let lo = Register("lo", user: false)!

// Standard input
let keyboard = NSFileHandle.fileHandleWithStandardInput()

// Strings to help with string parsing
let commandBeginning = ":"
let labelEnd = ":"
let commentBeginning = "#"
let validInstructionSeparators = "(), \t"
let validInstructionSeparatorsCharacterSet = NSCharacterSet(charactersInString: validInstructionSeparators)
let validLabelCharacters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"
let validLabelCharactersCharacterSet = NSCharacterSet(charactersInString: validLabelCharacters)