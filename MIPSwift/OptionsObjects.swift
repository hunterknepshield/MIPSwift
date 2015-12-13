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
    var autoexecute = true
    var trace = false
    var printSetting: PrintOption = .Hex
    var inputSource = stdIn
    var usingFile = false
}

enum PrintOption: String, CustomStringConvertible {
    case Hex = "%08x"
    case HexWith0x = "%#010x"
    case Decimal = "%010d"
    case Octal = "%016o"
    case Binary = "%032b"
    
    var description: String {
        get {
            switch(self) {
            case .Hex:
                return "Hexadecimal"
            case .Decimal:
                return "Decimal"
            case .Octal:
                return "Octal"
            case .Binary:
                return "Binary"
            case .HexWith0x:
                return "Hexadecimal (with preceeding 0x)"
            }
        }
    }
}