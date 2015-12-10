//
//  REPL.swift
//  MIPSwift
//
//  Created by Hunter Knepshield on 12/10/15.
//  Copyright © 2015 Hunter Knepshield. All rights reserved.
//

import Foundation

class REPL {
    let keyboard = NSFileHandle.fileHandleWithStandardInput()
    let registers = RegisterFile()
    let commandBeginning: Character = ":"
    
    func run() {
        print("Initializing REPL...")
        
        while true {
            // Read input
            let input = readInput() // Read input (whitespace is already trimmed)
            if input[0] == commandBeginning {
                // This is a command, not an instruction; attempt to parse as such
                print("Got a command.")
                executeCommand(parseCommand(input))
            } else {
                // This is not a command, attempt to parse as an instruction
                print("Got an instruction.")
                
            }
        }
    }
    
    func readInput() -> String {
        let inputData = keyboard.availableData
        return NSString(data: inputData, encoding:NSUTF8StringEncoding)!.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()) // Trims whitespace before of and after the input, including trailing newline
    }
    
    func parseCommand(commandString: String) -> Command {
        return Command(rawValue: commandString) ?? Command.Invalid
    }
    
    func executeCommand(command: Command) {
        switch(command) {
        case .Dump:
            // Print the current contents of the register file
            print(registers)
        case .Exit:
            print("Exiting...")
            exit(0)
        case .Invalid:
            assertionFailure("Invalid command.")
        }
    }
    
    func parseInstruction(instructionString: String) -> Instruction {
        let operationString = "add" // TODO parse instructionString
        let operation = Operation(rawValue: operationString) ?? Operation.Invalid
        
        switch(operation) {
        case .Add: // All ALU-R operations
            let rd = Register(name: "")
            let rs = Register(name: "")
            let rt = Register(name: "")
            return Instruction.rType(operation, rd, rs, rt)
            // TODO other cases (ALU-I, memory, ...)
        case .Invalid:
            return Instruction.Invalid(instructionString)
        }
    }
    
    func executeInstruction(instruction: Instruction) {
        switch(instruction) {
        case .rType(let op, let rd, let rs, let rt):
            print("R-type")
        case .iType(let op, let rt, let rs, let imm):
            print("I-type")
        case .jType(let op, let label):
            print("Unimplemented")
            assertionFailure("J-type instructions unimplemented.")
        case .Invalid(let badInstruction):
            assertionFailure("Invalid instruction decoded: \(badInstruction).")
        }
    }
}