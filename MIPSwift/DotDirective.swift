//
//  DotDirective.swift
//  MIPSwift
//
//  Created by Hunter Knepshield on 12/13/15.
//  Copyright © 2015 Hunter Knepshield. All rights reserved.
//

// All dot directives with descriptions:
// http://students.cs.tamu.edu/tanzir/csce350/reference/assembler_dir.html

import Foundation

/// Representation of an assembler directive.
enum DotDirective: String {
	/// Change to the text segment.
    case Text = ".text"
	/// Change to the data segment.
    case Data = ".data"
	/// Declare a global label.
    case Global = ".globl"
	/// Align to a 2^n-byte boundary.
    case Align = ".align"
	/// Allocate n bytes of space
    case Space = ".space"
	/// Store 4-byte values with initial values supplied
    case Word = ".word"
	/// Store 2-byte values with initial values supplied
    case Half = ".half"
	/// Store 1-byte values with initial values supplied
    case Byte = ".byte"
	/// Store a non-null-terminated string
    case Ascii = ".ascii"
	/// Store a null-terminated string
    case Asciiz = ".asciiz"
}