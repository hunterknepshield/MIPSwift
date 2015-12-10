//
//  Constants.swift
//  MIPSwift
//
//  Created by Hunter Knepshield on 12/10/15.
//  Copyright © 2015 Hunter Knepshield. All rights reserved.
//

import Foundation

// Register objects that are used often
let zero = Register(name: "$zero")
let pc = Register(name: "pc")
let hi = Register(name: "hi")
let lo = Register(name: "lo")

// Standard input
let keyboard = NSFileHandle.fileHandleWithStandardInput()

// Strings to help with parsing
let commandBeginning = ":"
let commentBeginning = "#"
let validInstructionSeparators = ":(),"