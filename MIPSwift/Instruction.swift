//
//  Instruction.swift
//  MIPSwift
//
//  Created by Hunter Knepshield on 12/10/15.
//  Copyright © 2015 Hunter Knepshield. All rights reserved.
//

import Foundation

enum Instruction {
    case rType(Operation, Register, Register, Register) // op, rd, rs, rt
    case iType(Operation, Register, Register, Immediate) // op, rt, rs, imm
    case jType(Operation, Label) // op, target
    case interpreterCommand(Command) // The user has entered something like :exit
}

struct Register {
    var name: String
}

struct Immediate {
    var value: Int16 // Limited to 16 bits
}

struct Label {
    var name: String
    var location: Int32 // Limited to 26 bits
}

enum Operation {
    
}

enum Command {
    case exit
}