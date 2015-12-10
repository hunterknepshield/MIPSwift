//
//  Constants.swift
//  MIPSwift
//
//  Created by Hunter Knepshield on 12/10/15.
//  Copyright © 2015 Hunter Knepshield. All rights reserved.
//

import Foundation

// General constants
let version = 1.0

// Register objects that are used often
let zero = Register(name: "$zero")
let pc = Register(name: "pc")
let hi = Register(name: "hi")
let lo = Register(name: "lo")

// Standard input
let keyboard = NSFileHandle.fileHandleWithStandardInput()

// Strings to help with parsing
let commandBeginning = ":"
let labelEnd = ":"
let commentBeginning = "#"
let validInstructionSeparators = "(),"
let validInstructionSeparatorsCharacterSet = NSCharacterSet(charactersInString: validInstructionSeparators)
let validLabelCharacters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"
let validLabelCharactersCharacterSet = NSCharacterSet(charactersInString: validLabelCharacters)