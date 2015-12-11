//
//  REPLOptions.swift
//  MIPSwift
//
//  Created by Hunter Knepshield on 12/10/15.
//  Copyright © 2015 Hunter Knepshield. All rights reserved.
//

import Foundation

struct REPLOptions {
    var verbose = false
    var autodump = false
    var printSetting: PrintOption = .Hex
    var everythingOn = false
}

enum PrintOption: String {
    case Hex = "%08x"
    case HexWith0x = "%#010x"
    case Decimal = "%010d"
    case Octal = "%016o"
    case Binary = "%032b"
}