//
//  Command.swift
//  MIPSwift
//
//  Created by Hunter Knepshield on 12/10/15.
//  Copyright © 2015 Hunter Knepshield. All rights reserved.
//

import Foundation

enum Command: String {
    // Representation of a user-entered command, like :dump or :exit
    case Dump = ":dump"
    case Exit = ":exit"
    case Invalid = ""
}