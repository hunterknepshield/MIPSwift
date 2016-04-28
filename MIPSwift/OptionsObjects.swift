//
//  OptionsObjects.swift
//  MIPSwift
//
//  Created by Hunter Knepshield on 12/10/15.
//  Copyright © 2015 Hunter Knepshield. All rights reserved.
//

import Foundation

/// A structure that encapsulates interpreter settings to be passed in during
/// the initialization of a REPL object.
struct REPLOptions {
    var verbose = false
    var autodump = false
    var autoexecute = true
    var trace = false
	/// The initial dump setting for how registers will be formatted.
    var printSetting: PrintOption = .Hex
	/// The initial source the REPL will read input from.
    var inputSource = stdIn
	/// Indicate to the REPL that it will be reading from a file or not. If
	/// inputSource != stdIn, this should be true.
    var usingFile = false
}

enum PrintOption: String, CustomStringConvertible {
	/// 8 hex digits, filling in with 0.
    case Hex = "%08x"
	/// 8 hex digits with a leading 0x, filling in with 0.
    case HexWith0x = "%#010x"
	/// 11 decimal digits, filling in with 0.
    case Decimal = "%011d"
	/// 11 octal digits, filling in with 0.
    case Octal = "%011o"
	/// 32 binary digits, filling in with 0.
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
                return "Hexadecimal (with leading 0x)"
            }
        }
    }
}