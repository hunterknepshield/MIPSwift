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
	
	/// A REPLOptions instance with autodump set to true, autoexecute set to false, trace set to true, and all other settings the same as the default initializer.
	static let developerOptions = REPLOptions(verbose: false, autodump: true, autoexecute: false, trace: true, printSetting: .Hex, inputSource: stdIn)
}

/// An enumeration of the different possible formattings for numbers in MIPSwift.
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