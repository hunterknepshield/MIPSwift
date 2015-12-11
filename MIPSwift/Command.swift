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
    case Dump
    case AutoDump
    case Exit
    case Verbose
    case Help
    case NoOp
    case Hex
    case Decimal
    case Invalid(String)
    
    init(_ string: String) {
        switch(string) {
        case ":dump", ":d", ":reg", ":r":
            self = .Dump
        case ":autodump", ":a":
            self = .AutoDump
        case ":exit", ":e", ":quit", ":q":
            self = .Exit
        case ":verbose", ":v":
            self = .Verbose
        case ":help", ":h", ":?":
            self = .Help
        case ":noop", ":n":
            self = .NoOp
        case ":dec", ":decimal":
            self = .Decimal
        case ":hex":
            self = .Hex
        default:
            self = .Invalid(string)
        }
    }
}