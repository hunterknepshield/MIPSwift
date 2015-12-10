//
//  REPL.swift
//  MIPSwift
//
//  Created by Hunter Knepshield on 12/10/15.
//  Copyright © 2015 Hunter Knepshield. All rights reserved.
//

import Foundation

class REPL {
    var registers = RegisterFile()
    var verbose = false
    
    func run() {
        print("Initializing REPL...")
        
        while true {
            // Read input
            let input = readInput() // Read input (whitespace is already trimmed)
            if input.rangeOfString(commandBeginning)?.minElement() == input.startIndex {
                // This is a command, not an instruction; parse it as such
                executeCommand(Command(input))
            } else {
                // This is an instruction, not a command; parse it as such
                executeInstruction(Instruction(input, verbose))
            }
        }
    }
    
    func readInput() -> String {
        let inputData = keyboard.availableData
        return NSString(data: inputData, encoding:NSUTF8StringEncoding)!.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()) // Trims whitespace before of and after the input, including trailing newline
    }
    
    func executeCommand(command: Command) {
        switch(command) {
        case .Dump:
            // Print the current contents of the register file
            print(registers)
        case .Exit:
            print("Exiting...")
            exit(0)
        case .Verbose:
            // Toggle current verbosity setting
            verbose = !verbose
        case .Help:
            // Display the help menu
            print("MIPSwift v\(version)")
        case .Invalid(let invalid):
            print("Invalid command: \(invalid)")
        }
    }
        
    func executeInstruction(instruction: Instruction) {
        switch(instruction) {
        case .rType(let op, let rd, let rs, let rt):
            let rsValue = registers.get(rs.name)
            let rtValue = registers.get(rt.name)
            let result = op.operation!(rsValue, rtValue)
            registers.set(rd.name, result)
        case .iType(let op, let rt, let rs, let imm):
            let rsValue = registers.get(rs.name)
            let result = op.operation!(rsValue, imm.signExtended)
            registers.set(rt.name, result)
        case .jType(let op, let label):
            assertionFailure("J-type instructions unimplemented: \(op) \(label.name).")
        case .Invalid(let invalid):
            print("Invalid instruction decoded: \(invalid)")
        }
    }
}