//
//  REPL.swift
//  MIPSwift
//
//  Created by Hunter Knepshield on 12/10/15.
//  Copyright © 2015 Hunter Knepshield. All rights reserved.
//

import Foundation

class REPL {
    var inputSource: NSFileHandle
    var usingFile: Bool
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
    
    init(options: REPLOptions) {
        print("Initializing REPL...", terminator: " ")
        self.registers.set(pc.name, currentPc)
        self.verbose = options.verbose
        self.autodump = options.autodump
        self.autoexecute = options.autoexecute
        self.trace = options.trace        
        self.registers.printOption = options.printSetting
        self.inputSource = options.inputSource
        self.usingFile = options.usingFile
    }
    
    func run() {
        if self.usingFile {
            print("Reading file.")
        } else {
            print("Ready to read input. Type '\(commandBeginning)help' for more.")
        }
        var previousInstruction: Instruction?
        while true {
            if !self.usingFile {
                // Print the prompt if reading from stdIn
                print("\(currentPc.toHexWith0x())> ", terminator: "") // Prints PC without a newline
            }
            let input = readInput() // Read input (whitespace is already trimmed from either end)
            input.forEach({ inputString in
                if inputString.rangeOfString(commandBeginning)?.minElement() == inputString.startIndex || inputString == "" {
                    // This is a command, not an instruction; parse it as such
                    executeCommand(Command(inputString))
                } else {
                    // This is an instruction, not a command; parse it as such
                    let instruction = Instruction(string: inputString, location: currentPc, previous: previousInstruction, verbose: verbose)
                    switch(instruction.type) {
                    case .Invalid:
                        // This wasn't a valid instruction; don't store/execute anything
                        print("Invalid instruction: \(instruction)")
                        return
                    case .NonExecutable:
                        // This line contained only labels and/or comments; don't execute anything
                        let dupes = instruction.labels.filter({ return labelsToLocations[$0] != nil })
                        if dupes.count > 0 {
                            // There was at least one duplicate label; don't store/execute anything
                            print("Cannot overwrite label", terminator: dupes.count > 1 ? "s: " : ": ")
                            var counter = 0
                            dupes.forEach({ print($0, terminator: ++counter < dupes.count ? " " : "\n") })
                            return
                        }
                    default:
                        // Increment the program counter, store its new value in the register file, and then execute
                        let dupes = instruction.labels.filter({ return labelsToLocations[$0] != nil })
                        if dupes.count > 0 {
                            // There was at least one duplicate label; don't store/execute anything
                            print("Cannot overwrite label", terminator: dupes.count > 1 ? "s: " : ": ")
                            var counter = 0
                            dupes.forEach({ print($0, terminator: ++counter < dupes.count ? " " : "\n") })
                            return
                        }
                        locationsToInstructions[self.currentPc] = instruction
                        
                        // Increment the program counter by 4
                        // Don't set self.registers.pc here though, set it in execution (avoids issues with pausing)
                        let newPc = self.currentPc + instruction.pcIncrement
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
            })
        }
    }
    
    func readInput() -> [String] {
        let inputData = self.inputSource.availableData
        if inputData.length == 0 && self.usingFile {
            // Reached the end of file, switch back to standard input
            print("End of file reached. Switching back to standard input. Auto-execute of instructions is \(self.autoexecute ? "enabled" : "disabled").")
            self.inputSource.closeFile()
            self.inputSource = stdIn
            self.usingFile = false
            return [":noop"]
        }
        let inputString = NSString(data: inputData, encoding: NSUTF8StringEncoding)!.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()) // Trims whitespace before of and after the input, including trailing newline
        var returnedArray: [String]
        if self.usingFile {
            // inputData contains the entire file's contents; NSFileHandles do not read files line by line
            returnedArray = inputString.componentsSeparatedByCharactersInSet(NSCharacterSet.newlineCharacterSet())
        } else {
            returnedArray = [inputString]
        }
        returnedArray = returnedArray.filter({ return !$0.isEmpty }) // Remove any empty lines
        returnedArray = returnedArray.map({ return $0.canBeConvertedToEncoding(NSASCIIStringEncoding) ? $0 : ":\(inputString)" }) // If any strings contain non-ASCII characters, make them invalid commands
        return returnedArray
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
        if self.autoexecute {
            // Auto-execution is enabled, so wipe any stored pausedPc value
            self.pausedPc = nil
        } else {
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
                    // The program counter is already current, don't call resumeExecution()
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
        case .RegisterDump:
            // Print the current contents of the register file
            print(registers)
        case .Register(let name):
            // Register name is already guaranteed to be valid (checked in Command construction)
            let value = self.registers.get(name)
            print("\(name): \(value.format(self.registers.printOption.rawValue))")
        case .LabelDump:
            // Print the current labels that are stored in order of their location (if locations are equal, alphabetical order)
            print("All labels currently stored: ", terminator: labelsToLocations.count == 0 ? "(none)\n" : "\n")
            labelsToLocations.sort({ return $0.0.1 < $0.1.1 || ($0.0.1 == $0.1.1 && $0.0.0 < $0.1.0) }).forEach({ print("\t\($0.0): \($0.1.toHexWith0x())") })
        case .Label(let label):
            // Print the location of the given label
            if let location = labelsToLocations[label] {
                print("\(label): \(location.toHexWith0x())")
            } else {
                print("\(label): (undefined)")
            }
        case .InstructionDump:
            // Print all instructions currently stored
            print("All instructions currently stored: ", terminator: locationsToInstructions.count == 0 ? "(none)\n" : "\n")
            locationsToInstructions.sort({ return $0.0 < $1.0 }).forEach({ print("\t\($0.1)") })
        case .Instruction(let location):
            // Print the instruction at the given location
            if let instruction = locationsToInstructions[location] {
                print("\t\(instruction)")
            } else {
                print("Invalid location: \(location.toHexWith0x())")
            }
        case .AutoDump:
            // Toggle current auto-dump setting
            self.autodump = !self.autodump
            print("Auto-dump \(self.autodump ? "enabled" : "disabled").")
        case .Exit:
            print("Exiting MIPSwift.")
            if self.usingFile {
                self.inputSource.closeFile()
            }
            stdIn.closeFile()
            exit(0)
        case .Verbose:
            // Toggle current verbosity setting
            self.verbose = !self.verbose
            print("Verbose instruction parsing \(self.verbose ? "enabled" : "disabled").")
        case .Status:
            print("Current interpreter settings:")
            print("\t\(self.verbose ? "[X]" : "[ ]") Verbose instruction parsing is \(self.verbose ? "enabled" : "disabled").")
            print("\t\(self.autodump ? "[X]" : "[ ]") Auto-dump of registers after instruction execution is \(self.autodump ? "enabled" : "disabled").")
            print("\t\(self.autoexecute ? "[X]" : "[ ]") Auto-execute of instructions is \(self.autoexecute ? "enabled" : "disabled").")
            print("\t\(self.trace ? "[X]" : "[ ]") Trace printing of instructions during execution is \(self.trace ? "enabled" : "disabled").")
            print("\tRegisters will be printed using \(self.registers.printOption.description.lowercaseString).")
        case .Help:
            // Display the help message
            print("Enter MIPS instructions line by line. Any instructions that the interpreter declares invalid are entirely ignored and discarded.")
            print("The value printed with the prompt is the current value of the program counter. For example: '\(beginningPc.toHexWith0x())>'")
            print("To enter an interpreter command, type '\(commandBeginning)' followed by the command. Type '\(commandBeginning)commands' to see all commands.")
        case .Commands:
            print("All interpreter commands:")
            print("\tautoexecute/ae: toggle auto-execution of entered instructions.")
            print("\texecute/exec/ex/e: execute all instructions previously paused by disabling auto-execution.")
            print("\ttrace/t: print every instruction as it is executed.")
            print("\tverbose/v: toggle verbose parsing of instructions.")
            print("\tregisterdump/regdump/registers/regs/rd: print the values of all registers.")
            print("\tregister/reg/r [register]: print the value of a register.")
            print("\tautodump/ad: toggle auto-dump of registers after execution of every instruction.")
            print("\tlabeldump/labels/ld: print all labels as well as their locations.")
            print("\tlabel/l [label]: print the location of a label.")
            print("\tinstructions/insts/instructiondump/instdump/id: print all instructions as well as their locations.")
            print("\tinstruction/inst/i [location]: print the instruction at a location.")
            print("\thexadecimal/hex: set register dumps to print out values in hexadecimal (base 16).")
            print("\tdecimal/dec: set register dumps to print out values in decimal (base 10).")
            print("\toctal/oct: set register dumps to print out values in octal (base 8).")
            print("\tbinary/bin: set register dumps to print out values in binary (base 2).")
            print("\tstatus/settings/s: display current interpreter settings.")
            print("\thelp/h/?: display the help message.")
            print("\tabout: display information about this software.")
            print("\tcommands/cmds/c: display this message.")
            print("\tnoop/n: do nothing.")
            print("\tfile/f/use/usefile/openfile/open/o [file]: open a file to read instructions from.")
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
        case .UseFile(let filename):
            // The user has specified an input file to read
            if let openFile = NSFileHandle(forReadingAtPath: filename) {
                self.usingFile = true
                self.inputSource = openFile
                self.autoexecute = false // Disable for good measure
                print("Opened file: \(filename)")
            } else {
                print("Unable to open file: \(filename).")
            }
        case .Invalid(let invalid):
            print("Invalid command: \(invalid)")
        }
    }
        
    func executeInstruction(instruction: Instruction) {
        if self.trace {
            print(instruction)
        }
        // Update the program counter
        self.registers.set(pc.name, instruction.location + instruction.pcIncrement)
        // Determine how to execute the instruction
        switch(instruction.type) {
        case .RType(let op, let rd, let rs, let rt):
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
        case .IType(let op, let rt, let rs, let imm):
            let rsValue = registers.get(rs.name)
            let result = op.operation!(rsValue, imm.signExtended)
            self.registers.set(rt.name, result)
        case .JType(let op, let destination):
            // Jump to the destination
            let destinationLocation: Int32
            switch(destination) {
            case .Left(let reg):
                destinationLocation = self.registers.get(reg.name)
            case .Right(let label):
                if let loc = labelsToLocations[label] {
                    destinationLocation = loc
                } else {
                    assertionFailure("Undefined label: \(label)")
                    destinationLocation = INT32_MAX
                }
            }
            // op.operation is used to compute the (possibly) new return address
            let newRa = op.operation!(self.registers.get(ra.name), self.registers.get(pc.name))
            self.registers.set(ra.name, newRa)
            self.registers.set(pc.name, destinationLocation)
            self.currentPc = destinationLocation
            // TODO resume execution at currentPc
        case .Syscall:
            // This is a very complex operation that is based on various register values already set,
            // including a0, v0, etc., and may return values back in various registers
            executeSyscall()
        case .Directive(_):
            // This is another complex operation that may modify large amounts of data in a single line
            // The entire instruction needs to be passed because there may be large amounts of arguments
            executeDirective(instruction)
        case .NonExecutable:
            // Assume all housekeeping (e.g. label assignment) has already happened
            if self.trace {
                print(instruction)
            }
            return
        case .Invalid:
            // Should never happen; invalid instructions are dummped in the REPL and never executed
            assertionFailure("Invalid instruction: \(instruction)")
        }
        
        if self.autodump {
            executeCommand(.RegisterDump)
        }
        self.lastExecutedInstruction = instruction
    }
    
    func executeSyscall() {
        if let syscallCode = SyscallCode(rawValue: self.registers.get("$v0")) {
            switch(syscallCode) {
            case .PrintInt:
                // Print the integer currently in $a0
                print(self.registers.get("$a0"))
            case .PrintString:
                // Print the string that starts at address $a0 and go until '\0' is found
                let address = self.registers.get("$a0")
                print("TODO: read string at \(address)")
            case .ReadInt:
                // Read an integer from standard input and return it in $v0
                // Maximum of 2147483647, minimum of -2147483648
                let inputString: String = NSString(data: stdIn.availableData, encoding: NSUTF8StringEncoding)!.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
                if let value = Int32(inputString) {
                    self.registers.set("$v0", value)
                } else {
                    print("Invalid input for ReadInt syscall: \(inputString).")
                }
            case .Exit:
                // The assembly program has exited, so exit the interpreter as well
                print("Program terminated with exit code 0.")
                self.executeCommand(.Exit)
            case .Exit2:
                // The assembly program has exited with exit code in $a0
                print("Program terminated with exit code \(self.registers.get("$a0"))")
                self.executeCommand(.Exit)
            default:
                print("Syscall code unimplemented: \(self.registers.get("$v0"))")
            }
        } else {
            // Don't assert fail for now, just output
            print("Invalid syscall code: \(self.registers.get("$v0"))")
        }
    }
    
    func executeDirective(instruction: Instruction) {
        if case let .Directive(directive, args) = instruction.type {
            // Arguments, if any, are guaranteed to be valid here
            switch(directive) {
            case .Text:
                print("TODO: change to text segment")
            case .Data:
                print("TODO: change to data segment")
            case .Global:
                let label = args[0]
                // If label is already defined, don't need to do anything
                // If it isn't already defined, TODO implement
                if labelsToLocations[label] == nil {
                    print("Undefined label: \(label) TODO implement")
                }
            case .Align:
                // Align current counter to a 2^n-byte boundary
                let n = Int(args[0])!
                switch(n) {
                case 0:
                    break
                case 1:
                    break
                case 2:
                    break
                default:
                    assertionFailure("Invalid alignment: \(n)")
                }
            case .Space:
                // Allocate n bytes
                let n = Int(args[0])!
                print("TODO: allocate \(n) bytes")
            case .Word:
                let initialValues = args.map({ return Int32($0)! })
                // TODO implement
                print("Allocate space with values: \(initialValues)")
            case .Half:
                let initialValues = args.map({ return Int16($0)! })
                // TODO implement
                print("Allocate space with values: \(initialValues)")
            case .Byte:
                let initialValues = args.map({ return Int8($0)! })
                // TODO implement
                print("Allocate space with values: \(initialValues)")
            case .Ascii:
                let string = args[0]
                print("Allocate string: \(string)")
            case .Asciiz:
                let string = args[0] + "\0"
                print("Allocate string: \(string)")
            }
        } else {
            assertionFailure("Attempting to execute illegal directive: \(instruction)")
        }
    }
}