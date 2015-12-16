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
    var memory = [Int32 : UInt8]() // Maps locations to memory
    var verbose = false
    var autodump = false
    var autoexecute = true
    var trace = false
    
    init(options: REPLOptions) {
        print("Initializing REPL...", terminator: " ")
        self.verbose = options.verbose
        self.autodump = options.autodump
        self.autoexecute = options.autoexecute
        self.trace = options.trace
        self.registers.printOption = options.printSetting
        self.inputSource = options.inputSource
        self.usingFile = options.usingFile
        
        // Set initial register values
        self.registers.set(pc.name, currentPc)
        self.registers.set(sp.name, beginningSp)
    }
    
    func run() {
        if self.usingFile {
            print("Reading file.")
        } else {
            print("Ready to read input. Type '\(commandDelimiter)help' for more.")
        }
        while true {
            if !self.usingFile {
                // Print the prompt if reading from stdIn
                print("\(currentPc.toHexWith0x())> ", terminator: "") // Prints PC without a newline
            }
            let input = readInput() // Read input (whitespace is already trimmed from either end)
            input.forEach({ inputString in
                if inputString.rangeOfString(commandDelimiter)?.minElement() == inputString.startIndex || inputString == "" {
                    // This is a command, not an instruction; parse it as such
                    executeCommand(Command(inputString))
                } else if var inst = Instruction(string: inputString, location: currentPc, verbose: verbose) {
                    switch(inst.type) {
                    case .NonExecutable:
                        // This line contained only labels and/or comments; don't execute anything, but make sure labels are all valid
                        let dupes = inst.labels.filter({ return labelsToLocations[$0] != nil })
                        if dupes.count > 0 {
                            // There was at least one duplicate label; don't store/execute anything
                            print("Cannot overwrite label", terminator: dupes.count > 1 ? "s: " : ": ")
                            var counter = 0
                            dupes.forEach({ print($0, terminator: ++counter < dupes.count ? " " : "\n") })
                            return
                        }
                        inst.labels.forEach({ labelsToLocations[$0] = inst.location }) // Store labels in the dictionary
                    default:
                        // Increment the program counter, store its new value in the register file, and then execute
                        let dupes = inst.labels.filter({ return labelsToLocations[$0] != nil })
                        if dupes.count > 0 {
                            // There was at least one duplicate label; don't store/execute anything
                            print("Cannot overwrite label", terminator: dupes.count > 1 ? "s: " : ": ")
                            var counter = 0
                            dupes.forEach({ print($0, terminator: ++counter < dupes.count ? " " : "\n") })
                            return
                        }
                        inst.labels.forEach({ labelsToLocations[$0] = inst.location }) // Store labels in the dictionary
                        // Check if this location already contains an instruction
                        if let existingInstruction = locationsToInstructions[inst.location] {
                            switch(existingInstruction.type) {
                            case .NonExecutable:
                                // This is fine; only labels or comments here, just overwrite
                                inst.labels = existingInstruction.labels + inst.labels
                                inst.comment = "\(existingInstruction.comment ?? "") \(inst.comment ?? "")"
                                locationsToInstructions[inst.location] = inst
                            default:
                                // This is bad; overwriting an executable instruction
                                // This is likely caused by an issue with internal REPL state
                                print("Cannot overwrite existing instruction: \(existingInstruction)")
                            }
                        }
                        
                        // Increment the program counter by however much the instruction requires
                        // Don't set self.registers.pc here though, set it in execution (avoids issues with pausing)
                        locationsToInstructions[self.currentPc] = inst
                        let newPc = self.currentPc + inst.pcIncrement
                        self.currentPc = newPc
                        
                        if self.autoexecute {
                            executeInstruction(inst)
                        }
                    }
                } else {
                    print("Invalid instruction: \(inputString)")
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
        // Auto-execute was disabled, so resume execution from the instruction after self.lastExecutedInstructionLocation
        // Alternatively, if lastExecutedInstructionLocation's lookup is nil, nothing was ever executed, so start from the beginning
        var currentInstruction = locationsToInstructions[pausedPc ?? beginningPc]
        while currentInstruction != nil {
            // Execute the current instruction, then execute the next instruction, etc. until nil is found
            executeInstruction(currentInstruction!)
            currentInstruction = locationsToInstructions[currentPc]
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
            guard let location = labelsToLocations[label] else {
                print("\(label): (undefined)")
                break
            }
            print("\(label): \(location.toHexWith0x())")
        case .InstructionDump:
            // Print all instructions currently stored
            print("All instructions currently stored: ", terminator: locationsToInstructions.count == 0 ? "(none)\n" : "\n")
            locationsToInstructions.sort({ return $0.0 < $1.0 }).forEach({ print("\t\($0.1)") })
        case .Instruction(let location):
            // Print the instruction at the given location
            guard let instruction = locationsToInstructions[location] else {
                print("Invalid location: \(location.toHexWith0x())")
                break
            }
            print("\t\(instruction)")
        case .Memory(let loc, let numWords):
            let location: Int32
            switch(loc) {
            case .Left(let int):
                location = int
            case .Right(let reg):
                location = self.registers.get(reg.name)
            }
            // Print numBytes of memory starting at location
            var words = [Int32]()
            for i in 0..<numWords {
                let address = location + 32*i
                let highest = self.memory[address] ?? 0
                let higher = self.memory[address + 8] ?? 0
                let lower = self.memory[address + 16] ?? 0
                let lowest = self.memory[address + 24] ?? 0
                words.append(Int32(highest: highest, higher: higher, lower: lower, lowest: lowest))
            }
            var counter = 0
            words.forEach({
                if counter % 4 == 0 {
                    // Make new lines every 16 bytes (4 sets of 32 bits)
                    print("[\((location + counter*4).toHexWith0x())]", terminator: "\t")
                }
                print($0.toHexWith0x(), terminator: ++counter % 4 == 0 ? "\n" : " ")
            })
            if counter % 4 != 0 { print("") }
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
            print("To enter an interpreter command, type '\(commandDelimiter)' followed by the command. Type '\(commandDelimiter)commands' to see all commands.")
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
            print("\tmemory/mem/m [location] [count]: print a number of words beginning at a location in memory.")
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
            guard let openFile = NSFileHandle(forReadingAtPath: filename) else {
                print("Unable to open file: \(filename).")
                break
            }
            self.usingFile = true
            self.inputSource = openFile
            self.autoexecute = false // Disable for good measure
            print("Opened file: \(filename)")
        case .Invalid(let invalid):
            print("Invalid command: \(invalid)")
        }
    }
        
    func executeInstruction(instruction: Instruction) {
        if self.trace {
            print(instruction)
        }
        // Update the program counter
        let newPc = instruction.location + instruction.pcIncrement
        self.currentPc = newPc
        self.registers.set(pc.name, newPc)
        
        switch(instruction.type) {
        case let .ALUR(op, dest, src1, src2):
            let src1Value = self.registers.get(src1.name)
            let src2Value = self.registers.get(src2.name)
            switch(op) {
            case .Left(let op32):
                let result = op32(src1Value, src2Value)
                self.registers.set(dest!.name, result) // Destination guaranteed to be non-nil
            case .Right(let (op64, moveFromHi)):
                // This is a div/mult instruction or a div/rem/mul pseudoinstruction
                let (hiValue, loValue) = op64(src1Value, src2Value)
                self.registers.set(hi.name, hiValue)
                self.registers.set(lo.name, loValue)
                if dest != nil {
                    // This was one of the pseudoinstructions, so there is a destination
                    // Hi and lo are always modified to mimic the real pseudoinstruction's execution
                    // Essentially, this amounts to an additional mfhi/mflo after the div/mul executes
                    if moveFromHi {
                        self.registers.set(dest!.name, hiValue)
                    } else {
                        self.registers.set(dest!.name, loValue)
                    }
                }
            }
        case let .ALUI(op, dest, src1, src2):
            let src1Value = self.registers.get(src1.name)
            switch(op) {
            case .Left(let op32):
                let result = op32(src1Value, src2.signExtended)
                self.registers.set(dest.name, result)
            case .Right(let (op64, moveFromHi)):
                // This was a div/rem/mul pseudoinstruction
                let (hiValue, loValue) = op64(src1Value, src2.signExtended)
                self.registers.set(hi.name, hiValue)
                self.registers.set(lo.name, loValue)
                if moveFromHi {
                    self.registers.set(dest.name, hiValue)
                } else {
                    self.registers.set(dest.name, loValue)
                }
            }
        case let .Memory(storing, size, memReg, offset, addrReg):
            let addrRegValue = self.registers.get(addrReg.name)
            let address = addrRegValue + offset.signExtended*8 // Immediate is offset in bytes
            if address % Int32(1 << size) != 0 {
                print("Unaligned memory reference: \(address.toHexWith0x())")
                // TODO disallow
            }
            if storing {
                // Storing the value in memReg to memory
                let valueToStore = self.registers.get(memReg.name)
                switch(size) {
                case 0:
                    // Storing a single byte (from low-order bits)
                    let lowest = valueToStore.unsignedLowest8()
                    self.memory[address] = lowest
                case 1:
                    // Storing a half-word (from low-order bits)
                    let lower = valueToStore.unsignedLower8()
                    let lowest = valueToStore.unsignedLowest8()
                    self.memory[address] = lower
                    self.memory[address + 8] = lowest
                case 2:
                    // Storing a word
                    let (highest, higher, lower, lowest) = valueToStore.toBytes()
                    self.memory[address] = highest
                    self.memory[address + 8] = higher
                    self.memory[address + 16] = lower
                    self.memory[address + 24] = lowest
                default:
                    // Never reached
                    fatalError("Invalid size of store word: \(size)")
                }
            } else {
                // Loading a value from memory into memReg
                let loadedValue: Int32
                switch(size) {
                case 0:
                    // Loading a single byte
                    loadedValue = Int32(highest: 0, higher: 0, lower: 0, lowest: self.memory[address] ?? 0)
                case 1:
                    // Loading a half-word
                    loadedValue = Int32(highest: 0, higher: 0, lower: self.memory[address] ?? 0, lowest: self.memory[address + 8] ?? 0)
                case 2:
                    // Loading a word
                    let highest = self.memory[address] ?? 0
                    let higher = self.memory[address + 8] ?? 0
                    let lower = self.memory[address + 16] ?? 0
                    let lowest = self.memory[address + 24] ?? 0
                    loadedValue = Int32(highest: highest, higher: higher, lower: lower, lowest: lowest)
                default:
                    // Never reached
                    fatalError("Invalid size of load word: \(size)")
                }
                self.registers.set(memReg.name, loadedValue)
            }
        case let .Jump(link, dest):
            let destinationAddress: Int32
            switch(dest) {
            case .Left(let reg):
                destinationAddress = self.registers.get(reg.name)
            case .Right(let label):
                guard let loc = labelsToLocations[label] else {
                    fatalError("Undefined label: \(label)") // Not checked until execution to allow labels do be defined anywhere before running
                }
                destinationAddress = loc
            }
            if link {
                self.registers.set(ra.name, self.currentPc)
            }
            self.registers.set(pc.name, destinationAddress)
            self.currentPc = destinationAddress
        case let .Branch(op, link, src1, src2, dest):
            let reg1Value = self.registers.get(src1.name)
            let reg2Value = self.registers.get(src2.name)
            if op(reg1Value, reg2Value) {
                // Take this branch
                guard let destinationAddress = labelsToLocations[dest] else {
                    fatalError("Undefined label: \(dest)") // Not checked until execution to allow labels do be defined anywhere before running
                }
                if link {
                    self.registers.set(ra.name, self.currentPc)
                }
                self.registers.set(pc.name, destinationAddress)
                self.currentPc = destinationAddress
            }
        case .Directive(_, _):
            // Abstract this away; large amount of parsing required
            // Arguments are guaranteed to be valid, otherwise instruction generation would have failed
            executeDirective(instruction)
        case .Syscall:
            // Abstract this away; large amount of parsing required
            executeSyscall()
        case .NonExecutable:
            // Assume all housekeeping like label storage has already occurred; nothing to do here
            break
        }
                
        if self.autodump {
            executeCommand(.RegisterDump)
        }
    }
    
    func executeSyscall() {
        guard let syscallCode = SyscallCode(rawValue: self.registers.get("$v0")) else {
            // Don't fatalError() for now, just output
            print("Invalid syscall code: \(self.registers.get("$v0"))")
            return
        }
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
            guard let value = Int32(inputString) else {
                print("Invalid input for ReadInt syscall: \(inputString).")
                break
            }
            self.registers.set("$v0", value)
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
                    fatalError("Invalid alignment: \(n)")
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
            fatalError("Attempting to execute illegal directive: \(instruction)")
        }
    }
}