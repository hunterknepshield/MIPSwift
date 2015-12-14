//
//  Immediate.swift
//  MIPSwift
//
//  Created by Hunter Knepshield on 12/10/15.
//  Copyright © 2015 Hunter Knepshield. All rights reserved.
//

import Foundation

// Representation of an immediate value
struct Immediate {
    var value: Int16 // Limited to 16 bits by MIPS instruciton structure itself
    var signExtended: Int32 { get { return Int32(value) } } // To perform operations
    
    // Initialize an immediate value from an integer
    init(value: Int16) {
        self.value = value
    }
    
    // Attempt to initialize an immediate value from a string; may fail
    init?(_ string: String) {
        if let immValue = Int16(string) {
            self.value = immValue
        } else {
            print("Unable to create immediate value from string: \(string)")
            return nil
        }
    }
}