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

enum DotDirective: String {
    case Text = ".text" // Change to text segment
    case Data = ".data" // Change to data segment
    case Global = ".globl" // Declare a global label
    case Align = ".align" // Align to a 2^n-byte boundary
    case Space = ".space" // Allocate n bytes of space
    case Word = ".word" // Store four byte values with initial values supplied
    case Half = ".half" // Store two byte values with initial values supplied
    case Byte = ".byte" // Store single bytes with initial values supplied
    case Ascii = ".ascii" // Non-null-terminated string
    case Asciiz = ".asciiz" // Null-terminated string
}