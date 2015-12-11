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
    var labelsToLocations = [String: Int32]() // Maps labels to locations
    var locationsToInstructions = [Int32: Instruction]() // Maps locations to instructions
    var verbose = false
    var autodump = false
    
    init(options: REPLOptions = REPLOptions()) {
        print("Initializing REPL...")
        self.registers.set(pc.name, currentPc)
        if options.verbose {
            self.verbose = true
        }
        if options.autodump {
            self.autodump = true
        }
        if options.everythingOn {
            self.verbose = true
            self.autodump = true
        }
        self.registers.printOption = options.printSetting
    }
    
    func run() {
        var previousInstruction: Instruction? = nil
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
                    // This wasn't a valid instruction; don't increment/store/execute anything
                    print("Invalid instruction: \(instruction)")
                    continue
                case .Empty:
                    // This line contained only labels and/or comments; don't increment PC or execute
                    let dupes = findDuplicateLabels(instruction.labels)
                    if dupes.count > 0 {
                        // There was at least one duplicate label; don't increment/store/execute anything
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
                        // There was at least one duplicate label; don't increment/store/execute anything
                        print("Cannot overwrite label", terminator: dupes.count > 1 ? "s: " : ": ")
                        var counter = 0
                        let end = dupes.count
                        dupes.forEach({ print($0, terminator: ++counter < end ? " " : "\n") })
                        continue
                    }
                    let newPc = currentPc + 4
                    self.registers.set(pc.name, newPc)
                    self.currentPc = newPc
                    executeInstruction(instruction)
                }
                // Store this instruction and map any labels
                previousInstruction = instruction
                instruction.labels.forEach({ labelsToLocations[$0] = instruction.location }) // Store labels in the dictionary
                if autodump {
                    executeCommand(.Dump)
                }
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
    
    func executeCommand(command: Command) {
        switch(command) {
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
            self.autodump = !self.autodump
            print("Auto-dump \(self.autodump ? "enabled" : "disabled").")
        case .Exit:
            print("Exiting MIPSwift.")
            exit(0)
        case .Verbose:
            // Toggle current verbosity setting
            self.verbose = !self.verbose
            print("Verbose parsing \(self.verbose ? "enabled" : "disabled").")
        case .Help:
            // Display the help menu
            // TODO more helpful stuff here
            print("MIPSwift v\(mipswiftVersion)")
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
                // This is a mult/div instruction
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
        case .Empty:
            // Should never happen
            assertionFailure("Empty instruction: \(instruction)")
        case .Invalid:
            // Should never happen
            assertionFailure("Invalid instruction: \(instruction)")
        }
    }
    
    func findDuplicateLabels(labels: [String]) -> [String] {
        // If labelsToLocations[labels[i]] != nil, then this label is already mapped to a location, so return it
        return labels.filter({ return labelsToLocations[$0] != nil })
    }
}