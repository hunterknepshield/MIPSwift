//
//  Command.swift
//  MIPSwift
//
//  Created by Hunter Knepshield on 12/10/15.
//  Copyright © 2015 Hunter Knepshield. All rights reserved.
//

import Foundation

enum Command {
    // Representation of a user-entered command, like :dump or :exit
    // These are not instructions and do not affect the register file,
    // and are only executed for effect
    case AutoExecute
    case Execute
    case Trace
    case Dump
    case Label
    case AutoDump
    case Exit
    case Verbose
    case Help
    case NoOp
    case Hex
    case Decimal
    case Octal
    case Binary
    case Invalid(String)
    
    init(_ string: String) {
        if string == "" {
            self = .NoOp
            return
        }
        let strippedString = string[1..<string.characters.count] // Remove the commandBeginning character
        switch(strippedString) {
        case "autoexecute", "ae":
            self = .AutoExecute
        case "execute", "exec", "ex", "e":
            self = .Execute
        case "trace", "t":
            self = .Trace
        case "dump", "d", "reg", "r":
            self = .Dump
        case "label", "l":
            self = .Label
        case "autodump", "ad":
            self = .AutoDump
        case "exit", "quit", "q":
            self = .Exit
        case "verbose", "v":
            self = .Verbose
        case "help", "h", "?":
            self = .Help
        case "noop", "n", "":
            self = .NoOp
        case "hex", "hexadecimal":
            self = .Hex
        case "dec", "decimal":
            self = .Decimal
        case "oct", "octal":
            self = .Octal
        case "bin", "binary":
            self = .Binary
        default:
            self = .Invalid(strippedString)
        }
    }
}