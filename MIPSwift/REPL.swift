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
    var currentPc = beginningPc // To avoid constantly getting and setting self.registers.pc
    var pausedPc: Int32? // Keep track of where execution was last paused
    var labelsToLocations = [String : Int32]() // Maps labels to locations
    var locationsToInstructions = [Int32 : Instruction]() // Maps locations to instructions
    var firstInstruction: Instruction?
    var lastExecutedInstruction: Instruction?
    var verbose = false
    var autodump = false
    var autoexecute = true
    var trace = false
    
    init(options: REPLOptions = REPLOptions()) {
        print("Initializing REPL...", terminator: " ")
        self.registers.set(pc.name, currentPc)
        self.verbose = options.verbose
        self.autodump = options.autodump
        self.autoexecute = options.autoexecute
        self.trace = options.trace        
        self.registers.printOption = options.printSetting
        
        self.run()
    }
    
    func run() {
        print("Ready to run. Type '\(commandBeginning)help' for more.")
        var previousInstruction: Instruction?
        while true {
            // Print the prompt
            print("\(currentPc.format(PrintOption.HexWith0x.rawValue))> ", terminator: "") // Prints PC without a newline
            // Read input
            let input = readInput() // Read input (whitespace is already trimmed)
            if input.rangeOfString(commandBeginning)?.minElement() == input.startIndex || input == "" {
                // This is a command, not an instruction; parse it as such
                // Also ignore any PC update logic
                executeCommand(Command(input))
            } else {
                // This is an instruction, not a command; parse it as such
                let instruction = Instruction(string: input, location: currentPc, previous: previousInstruction, verbose: verbose)
                switch(instruction.type) {
                case .Invalid:
                    // This wasn't a valid instruction; don't store/execute anything
                    print("Invalid instruction: \(instruction)")
                    continue
                case .NonExecutable:
                    // This line contained only labels and/or comments; don't execute anything
                    let dupes = findDuplicateLabels(instruction.labels)
                    if dupes.count > 0 {
                        // There was at least one duplicate label; don't store/execute anything
                        print("Cannot overwrite label", terminator: dupes.count > 1 ? "s: " : ": ")
                        var counter = 0
                        let end = dupes.count
                        dupes.forEach({ print($0, terminator: ++counter < end ? " " : "\n") })
                        continue
                    }
                    break
                default:
                    // Increment the program counter, store its new value in the register file, and then execute
                    let dupes = findDuplicateLabels(instruction.labels)
                    if dupes.count > 0 {
                        // There was at least one duplicate label; don't store/execute anything
                        print("Cannot overwrite label", terminator: dupes.count > 1 ? "s: " : ": ")
                        var counter = 0
                        let end = dupes.count
                        dupes.forEach({ print($0, terminator: ++counter < end ? " " : "\n") })
                        continue
                    }
                    locationsToInstructions[self.currentPc] = instruction
                    
                    // Increment the program counter by 4 (may change again with J-type)
                    let newPc = self.currentPc + 4
                    self.registers.set(pc.name, newPc)
                    self.currentPc = newPc
                    
                    if self.autoexecute {
                        executeInstruction(instruction)
                    }
                }
                // Store this instruction and map any labels
                if self.firstInstruction == nil {
                    self.firstInstruction = instruction
                }
                previousInstruction = instruction
                instruction.labels.forEach({ labelsToLocations[$0] = instruction.location }) // Store labels in the dictionary
            }
        }
    }
    
    func readInput() -> String {
        let inputData = keyboard.availableData
        let inputString = NSString(data: inputData, encoding:NSUTF8StringEncoding)!.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()) // Trims whitespace before of and after the input, including trailing newline
        if !inputString.canBeConvertedToEncoding(NSASCIIStringEncoding) {
            return ":\(inputString)"
        }
        return inputString
    }
    
    func resumeExecution() {
        print("Resuming execution...")
        // Auto-execute was disabled, so resume execution from the instruction after self.lastExecutedInstruction
        // Alternatively, if lastExecutedInstruction is nil, nothing was ever executed, so start from the beginning
        var currentInstruction = locationsToInstructions[pausedPc ?? beginningPc]
        while currentInstruction != nil {
            // Execute the current instruction, then execute currentInstruction.next, etc. until nil is found
            executeInstruction(currentInstruction!)
            currentInstruction = currentInstruction!.next
        }
        print("Execution has caught up. Auto-execute of instructions is \(self.autoexecute ? "enabled" : "disabled").")
        if !self.autoexecute {
            // Update the pausedPc to note that execution has come this far
            self.pausedPc = self.currentPc
        }
    }
    
    func executeCommand(command: Command) {
        switch(command) {
        case .AutoExecute:
            // Toggle current auto-execute setting
            self.autoexecute = !self.autoexecute
            if self.autoexecute {
                // If autoexecute was previously disabled, execution may need to catch up
                if self.currentPc == self.pausedPc {
                    // The program counter is already current; don't call resumeExecution()
                    print("Auto-execute of instructions enabled.")
                } else {
                    print("Auto-execute of instructions enabled.", terminator: " ")
                    resumeExecution()
                }
            } else {
                print("Auto-execute of instructions disabled.")
                self.pausedPc = self.currentPc
            }
        case .Execute:
            // Run commands from wherever the user last disabled auto-execute
            if self.autoexecute {
                print("Auto-execute is enabled. No unexecuted instructions to execute.")
            } else {
                resumeExecution()
            }
        case .Trace:
            // Toggle current trace setting
            self.trace = !self.trace
            print("Trace \(self.trace ? "enabled": "disabled").")
        case .Dump:
            // Print the current contents of the register file
            print(registers)
        case .Label:
            // Print the current labels that are stored in order of their location (if locations are equal, alphabetical order)
            let format = PrintOption.HexWith0x.rawValue
            var counter = 0 // For determining whether to print a space or newline after each pair
            let end = labelsToLocations.count
            print("All labels currently stored: ", terminator: end == 0 ? "(none)\n" : "")
            labelsToLocations.sort({ return $0.0.1 < $0.1.1 || ($0.0.1 == $0.1.1 && $0.0.0 < $0.1.0) }).forEach({ print("\($0.0): \($0.1.format(format))", terminator: ++counter < end ? " " : "\n") })
        case .AutoDump:
            // Toggle current auto-dump setting
            self.autodump = !self.autodump
            print("Auto-dump \(self.autodump ? "enabled" : "disabled").")
        case .Exit:
            print("Exiting MIPSwift.")
            exit(0)
        case .Verbose:
            // Toggle current verbosity setting
            self.verbose = !self.verbose
            print("Verbose instruction parsing \(self.verbose ? "enabled" : "disabled").")
        case .Status:
            print("Current interpreter settings:")
            print("\tVerbose \(self.verbose ? "enabled" : "disabled").")
            print("\tAuto-dump \(self.autodump ? "enabled" : "disabled").")
            print("\tAuto-execute \(self.autoexecute ? "enabled" : "disabled").")
            print("\tTrace \(self.trace ? "enabled" : "disabled").")
        case .Help:
            // Display the help message
            print("The value printed with the prompt is the current value of the program counter. For example: '\(beginningPc.format(PrintOption.HexWith0x.rawValue))>'")
            print("Enter MIPS instructions line by line. Any instructions that the interpreter declares invalid are entirely ignored and discarded.")
            print("To enter an interpreter command, type '\(commandBeginning)' followed by the command. Valid commands are:")
            print("\tautoexecute/ae: toggle auto-execution of entered instructions.")
            print("\texecute/exec/ex/e: execute all instructions previously paused by disabling auto-execution.")
            print("\ttrace/t: print every instruction as it is executed.")
            print("\tverbose/v: toggle verbose parsing of instructions.")
            print("\tlabel/l: print all labels as well as their locations.")
            print("\tdump/d/registers/register/reg/r: print the values of all registers.")
            print("\tautodump/ad: toggle auto-dump of registers after execution of every instruction.")
            print("\thexadecimal/hex: set register dumps to print out values in hexadecimal (base 16).")
            print("\tdecimal/dec: set register dumps to print out values in decimal (base 10).")
            print("\toctal/oct: set register dumps to print out values in octal (base 8).")
            print("\tbinary/bin: set register dumps to print out values in binary (base 2).")
            print("\tstatus/settings/s: display current interpreter settings.")
            print("\thelp/h/?: display this message.")
            print("\tabout: display information about this software.")
            print("\tnoop/n: do nothing.")
            print("\texit/quit/q: exit the interpreter.")
        case .About:
            // Display information about the interpreter
            print("MIPSwift v\(mipswiftVersion): a MIPS interpreter written in Swift by Hunter Knepshield.")
            print("Modification and redistribution of this software is permitted under the MIT License. See LICENSE.txt for more information.")
        case .NoOp:
            // Do nothing
            break
        case .Decimal:
            self.registers.printOption = .Decimal
            print("Outputting register file using decimal print formatting.")
        case .Hex:
            self.registers.printOption = .Hex
            print("Outputting register file using hexadecimal print formatting.")
        case .Binary:
            self.registers.printOption = .Binary
            print("Outputting register file using binary print formatting.")
        case .Octal:
            self.registers.printOption = .Octal
            print("Outputting register file using octal print formatting.")
        case .Invalid(let invalid):
            print("Invalid command: \(invalid)")
        }
    }
        
    func executeInstruction(instruction: Instruction) {
        switch(instruction.type) {
        case .rType(let op, let rd, let rs, let rt):
            let rsValue = registers.get(rs.name)
            let rtValue = registers.get(rt.name)
            if op.type == .ALUR || op.operation != nil {
                let result = op.operation!(rsValue, rtValue)
                self.registers.set(rd.name, result)
            } else if op.type == .ComplexInstruction && op.bigOperation != nil {
                // This is a mult/div instruction, need to modify hi/lo
                let result = op.bigOperation!(rsValue, rtValue)
                let hiValue = Int32(result >> 32) // Upper 32 bits
                let loValue = Int32(result & 0xFFFFFFFF) // Lower 32 bits
                self.registers.set(hi.name, hiValue)
                self.registers.set(lo.name, loValue)
            }
        case .iType(let op, let rt, let rs, let imm):
            let rsValue = registers.get(rs.name)
            let result = op.operation!(rsValue, imm.signExtended)
            self.registers.set(rt.name, result)
        case .jType(let op, let label):
            assertionFailure("J-type instructions unimplemented: \(op) \(label).")
        case .NonExecutable:
            // Assume all housekeeping (i.e. label assignment) has already happened
            if self.trace {
                print(instruction)
            }
            return
        case .Invalid:
            // Should never happen
            assertionFailure("Invalid instruction: \(instruction)")
        }
        
        if self.trace {
            print(instruction)
        }
        if self.autodump {
            executeCommand(.Dump)
        }
        self.lastExecutedInstruction = instruction
    }
    
    func findDuplicateLabels(labels: [String]) -> [String] {
        // If labelsToLocations[labels[i]] != nil, then this label is already mapped to a location, so return it
        return labels.filter({ return labelsToLocations[$0] != nil })
    }
}