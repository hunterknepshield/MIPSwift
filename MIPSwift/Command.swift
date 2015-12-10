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
    case Dump
    case Exit
    case Invalid(String)
    
    init(_ string: String) {
        switch(string) {
        case ":dump":
            self = .Dump
        case ":exit":
            self = .Exit
        default:
            self = .Invalid(string)
        }
    }
}