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
    case Text // Change to text segment
    case Data // Change to data segment
    case Global // Declare a global label
    case Align // Align to a 2^n-byte boundary
    case Space // Allocate n bytes of space
    case Word // Store four byte values with initial values supplied
    case Half // Store two byte values with initial values supplied
    case Byte // Store single bytes with initial values supplied
    case Ascii // Non-null-terminated string
    case Asciiz // Null-terminated string    
}