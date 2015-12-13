//
//  Register.swift
//  MIPSwift
//
//  Created by Hunter Knepshield on 12/10/15.
//  Copyright © 2015 Hunter Knepshield. All rights reserved.
//

import Foundation

struct Register {
    // Representation of a source/destination register
    var name: String
    
    // Attempt to initialize a register from a given name,
    // fails if the user is attempting to write to a register inaccessible to them
    init?(_ name: String, writing: Bool, user: Bool = true) {
        if user && writing && immutableRegisters.contains(name) {
            print("User may not modify register: \(name)")
            return nil
        }
        if user && uninstantiableRegisters.contains(name) {
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