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
    
    init?(_ name: String, user: Bool = true) {
        if user && immutableRegisters.contains(name) {
            print("User may not modify register: \(name)")
            return nil
        } else if !validRegisters.contains(name) {
            print("Invalid register reference: \(name)")
            return nil
        }
        self.name = name
    }
}