//
//  Register.swift
//  MIPSwift
//
//  Created by Hunter Knepshield on 12/10/15.
//  Copyright © 2015 Hunter Knepshield. All rights reserved.
//

import Foundation

// Representation of a source/destination register
struct Register {
    var name: String
    
    // Attempt to initialize a register from a given name,
    // fails if the user is attempting to write to a register inaccessible to them
    init?(_ name: String, writing: Bool, user: Bool = true) {
        if user && writing && immutableRegisters.contains(name) {
            // User is trying to use an immutable register as the destination of an operation
            print("User may not modify register: \(name)")
            return nil
        }
        if user && uninstantiableRegisters.contains(name) {
            // User is trying to modify this register they can't access themselves (e.g. hi, pc)
            print("User may not access register: \(name)")
            return nil
        }
        if !validRegisters.contains(name) {
            print("Invalid register reference: \(name)")
            return nil
        }
        self.name = name
    }
}