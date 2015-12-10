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
    case Exit
    case Verbose
    case Help
    case Invalid(String)
    
    init(_ string: String) {
        switch(string) {
        case ":dump", ":d", ":reg", ":r":
            self = .Dump
        case ":exit", ":e", ":quit", ":q":
            self = .Exit
        case ":verbose", ":v":
            self = .Verbose
        case ":help", ":h":
            self = .Help
        default:
            self = .Invalid(string)
        }
    }
}