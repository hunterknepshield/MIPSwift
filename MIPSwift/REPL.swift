//
//  REPL.swift
//  MIPSwift
//
//  Created by Hunter Knepshield on 12/10/15.
//  Copyright © 2015 Hunter Knepshield. All rights reserved.
//

import Foundation

/// A read-eval-print loop for interpreting MIPS assembly instructions.
class REPL {
	// MARK: Memory and state variables
	
	/// The register file in its current state.
	var registers = RegisterFile()
	/// Maps labels to locations in memory.
    var labelsToLocations = [String : Int32]()
	/// Maps locations in memory to instructions.
    var locationsToInstructions = [Int32 : Instruction]()
	/// Keeps track of any instructions that have as-of-yet resolved label
	/// dependencies. For example, j label when label has yet to be defined.
	var unresolvedInstructions = [String: [Instruction]]()
	/// Maps locations in memory to individual bytes.
    var memory = [Int32 : UInt8]()
	/// The current value of the program counter. Used to avoid constantly
	/// getting and setting self.registers.pc.
	var currentTextLocation = beginningText
	/// Keeps track of where execution was last paused.
	var pausedTextLocation: Int32?
	/// Used to determine whether things are currently being written to the data
	/// or the text segment.
	var writingData = false
	/// Used to keep track of current point the interpreter is writing data to
	/// in the data segment
	var currentDataLocation = beginningData
	/// Used to determine the current location at which a piece of data should
	/// be written; may be either in the text segment or in the data segment.
	var currentWriteLocation: Int32 {
		get { return self.writingData ? self.currentDataLocation : self.currentTextLocation }
		set {
			if self.writingData { currentDataLocation = newValue }
			else { self.currentTextLocation = newValue }
		}
	}
	
	// MARK: Interpreter settings
	
	/// The source from which input is currently being read.
	var inputSource: NSFileHandle
	/// Used to determine whether or not input is being read from a file or
	/// standard input.
	var usingFile: Bool
	/// Current setting for verbose instruction parsing.
    var verbose = false
	/// Current setting for auto-dump of registers after instruction execution.
    var autodump = false
	/// Current setting for auto-execution of instructions.
    var autoexecute = true
	/// Current setting for printing of instructions during execution.
    var trace = false
	
	/// Initialize a REPL with supplied settings.
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
        self.registers.set(pc.name, currentTextLocation)
        self.registers.set(sp.name, beginningSp)
    }
	
	/// Begin reading input. This function will continue running until either
	/// an error occurs within Swift itself, or the :exit command is used.
    @noreturn func run() {
        if self.usingFile {
            print("Reading file.")
        } else {
            print("Ready to read input. Type '\(commandDelimiter)help' for more.")
        }
        while true {
            if !self.usingFile {
                // Print the prompt if reading from stdIn
                print("\(self.currentWriteLocation.toHexWith0x())> ", terminator: "") // Prints PC without a newline
            }
            let input = readInput() // Read input (whitespace is already trimmed from either end)
            input.forEach({ inputString in
                if inputString.rangeOfString(commandDelimiter)?.minElement() == inputString.startIndex || inputString == "" {
                    // This is a command, not an instruction; parse it as such
					guard let command = Command(inputString) else {
						print("Invalid command: \(inputString)")
						return
					}
                    executeCommand(command)
                } else if let instArray = Instruction.parseString(inputString, location: self.currentWriteLocation, verbose: verbose) {
					instArray.forEach({ inst in
						// Ensure all labels in this instruction are fresh
						let dupes = inst.labels.filter({ return labelsToLocations[$0] != nil })
						if dupes.count > 0 {
							// There was at least one duplicate label; don't store/execute anything
							print("Cannot overwrite label", terminator: dupes.count > 1 ? "s: " : ": ")
							var counter = 0
							dupes.forEach({ print($0, terminator: ++counter < dupes.count ? " " : "\n") })
							return
						}
						inst.labels.forEach({ labelsToLocations[$0] = inst.location }) // Store labels in the dictionary
						// Attempt to resolve dependencies
						let unresolved = inst.unresolvedDependencies
						unresolved.forEach({
							if let loc = labelsToLocations[$0] {
								// Know the location of this label
								print("Can be resolved: \($0) to \(loc)")
								inst.resolveDependency($0, location: loc)
							} else {
								// Don't yet know the label of this location; pause execution
								print("As-of-yet unresolved dependency: \($0)")
								print("Execution will be paused. Attempting to resume execution before all dependencies are resolved may cause undefined behavior.")
								// TODO stuff with unresolvedInstructions, pausing
							}
						})
						switch(inst.type) {
						case .NonExecutable:
							// This line contained only labels and/or comments; don't execute anything.
							locationsToInstructions[inst.location] = inst
						case .Directive(_):
							// This is an assembler directive; always execute these right away
							executeDirective(inst)
						default:
							// Check if this location already contains an instruction
							if let existingInstruction = locationsToInstructions[inst.location] {
								switch(existingInstruction.type) {
								case .NonExecutable:
									// This is fine; only labels or comments here, just overwrite
									inst.labels = existingInstruction.labels + inst.labels
									locationsToInstructions[inst.location] = inst
								case .Directive(_) where existingInstruction.pcIncrement == 0:
									// Alright to overwrite a directive as long as its pcIncrement is 0,
									// e.g. a .data directive
									break
								case _ where existingInstruction.pcIncrement == 0:
									print("PC increment is 0 for \(existingInstruction)")
									break
								default:
									// This is bad; overwriting an executable instruction
									// This is likely caused by an issue with internal REPL state
									print("Cannot overwrite existing instruction: \(existingInstruction)")
								}
							}
							// Increment the current location by however much the instruction requires
							// Don't set self.registers.pc here though, set it in execution (avoids issues with pausing)
							locationsToInstructions[self.currentWriteLocation] = inst
							let newPc = self.currentWriteLocation + inst.pcIncrement
							self.currentWriteLocation = newPc
							// TODO possibly write inst.numericEncoding to memory[self.currentWriteLocation..<self.currentWriteLocation + 4] once all pseudo instructions are properly decoded?
							
							if self.autoexecute {
								executeInstruction(inst)
							}
						}
					})
                } else {
                    print("Invalid instruction: \(inputString)")
                }
            })
        }
    }
	
	/// Read available input from the current input source. If it is a file, the
	/// entire file will be read at once (because NSFileHandles are poorly
	/// implemented). Because of this, an array of strings is returned. If
	/// reading from standard input, the array is guaranteed to have count 1.
	///
	/// - Returns: All input read, separated out line by line.
    func readInput() -> [String] {
        let inputData = self.inputSource.availableData
        if inputData.length == 0 && self.usingFile {
            // Reached the end of file, switch back to standard input
            print("End of file reached. Switching back to standard input. Auto-execute of instructions is \(self.autoexecute ? "enabled" : "disabled").")
            self.inputSource.closeFile()
            self.inputSource = stdIn
            self.usingFile = false
            return ["\(commandDelimiter)noop"]
        }
		// Trims whitespace before of and after the input, including trailing newline, then split on newline characters
        var returnedArray = NSString(data: inputData, encoding: NSUTF8StringEncoding)!.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()).componentsSeparatedByCharactersInSet(NSCharacterSet.newlineCharacterSet())
		// Remove any empty lines
        returnedArray = returnedArray.filter({ return !$0.isEmpty })
		// If any strings contain non-ASCII characters, make them invalid commands
        returnedArray = returnedArray.map({ return $0.canBeConvertedToEncoding(NSASCIIStringEncoding) ? $0 : "\(commandDelimiter)\($0)" })
        return returnedArray
    }
	
	/// Resume execution from the last executed instruction until it catches up
	/// and needs new input.
    func resumeExecution() {
        print("Resuming execution...")
        // Auto-execute was disabled, so resume execution from the instruction after self.lastExecutedInstructionLocation
        // Alternatively, if lastExecutedInstructionLocation's lookup is nil, nothing was ever executed, so start from the beginning
        var currentInstruction = locationsToInstructions[pausedTextLocation ?? beginningText]
        while currentInstruction != nil {
            // Execute the current instruction, then execute the next instruction, etc. until nil is found
            executeInstruction(currentInstruction!)
            currentInstruction = locationsToInstructions[currentTextLocation]
        }
        print("Execution has caught up. Auto-execute of instructions is \(self.autoexecute ? "enabled" : "disabled").")
        if self.autoexecute {
            // Auto-execution is enabled, so wipe any stored pausedTextLocation value
            self.pausedTextLocation = nil
        } else {
            // Update the pausedTextLocation to note that execution has come this far
            self.pausedTextLocation = self.currentTextLocation
        }
    }
	
	/// Execute a parsed interpreter command.
    func executeCommand(command: Command) {
        switch(command) {
        case .AutoExecute:
            // Toggle current auto-execute setting
            self.autoexecute = !self.autoexecute
            if self.autoexecute {
                // If autoexecute was previously disabled, execution may need to catch up
                if self.currentTextLocation == self.pausedTextLocation {
                    // The program counter is already current, don't call resumeExecution()
                    print("Auto-execute of instructions enabled.")
                } else {
                    print("Auto-execute of instructions enabled.", terminator: " ")
                    resumeExecution()
                }
            } else {
                print("Auto-execute of instructions disabled.")
                self.pausedTextLocation = self.currentTextLocation
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
            print("Trace \(self.trace ? "enabled" : "disabled").")
        case .RegisterDump:
            // Print the current contents of the register file
            print(registers)
        case .SingleRegister(let name):
            // Register name is already guaranteed to be valid (checked in Command construction)
            let value = self.registers.get(name)
            print("\(name): \(value.format(self.registers.printOption.rawValue))")
        case .LabelDump:
            // Print the current labels that are stored in order of their location (if locations are equal, alphabetical order)
            print("All labels currently stored: ", terminator: labelsToLocations.count == 0 ? "(none)\n" : "\n")
            labelsToLocations.sort({ return $0.0.1 < $0.1.1 || ($0.0.1 == $0.1.1 && $0.0.0 < $0.1.0) }).forEach({ print("\t\($0.0): \($0.1.toHexWith0x())") })
        case .SingleLabel(let label):
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
        case .SingleInstruction(let location):
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
			case .Middle(let reg):
				location = self.registers.get(reg.name)
            case .Right(let label):
				guard let loc = labelsToLocations[label] else {
					print("Invalid label: \(label)")
					return
				}
				location = loc
            }
            // Print numWords*4 bytes of memory starting at location
            var words = [Int32]()
			var ascii = "" // Queue up ASCII representations of memory values to print after each line, similar to hexdump
            for i in 0..<numWords {
                let address = location + 4*i // Loading in 4-byte chunks
				if let instruction = self.locationsToInstructions[address], let encoding = instruction.numericEncoding {
					// Check the instruction memory first
					let (highest, higher, lower, lowest) = encoding.toBytes()
					words.append(encoding)
					ascii += "\(highest.toPrintableCharacter())\(higher.toPrintableCharacter())\(lower.toPrintableCharacter())\(lowest.toPrintableCharacter())"
				} else {
					// Check regular memory
					let highest = self.memory[address] ?? 0
					let higher = self.memory[address + 1] ?? 0
					let lower = self.memory[address + 2] ?? 0
					let lowest = self.memory[address + 3] ?? 0
					words.append(Int32(highest: highest, higher: higher, lower: lower, lowest: lowest))
					ascii += "\(highest.toPrintableCharacter())\(higher.toPrintableCharacter())\(lower.toPrintableCharacter())\(lowest.toPrintableCharacter())"
				}
            }
            var counter = 0 // For formatting individual lines
			var lineString = "" // The string that will be printed
            words.forEach({
                if counter % 4 == 0 {
                    // Make new lines every 16 bytes (4 sets of 32 bits)
					print("[\((location + counter*4).toHexWith0x())]", terminator: "\t")
                }
				lineString += ascii[counter*4..<(counter*4 + 4)]
                print($0.toHexWith0x(), terminator: ++counter % 4 == 0 ? "\t\t" : " ") // Counter incremented here
				if counter % 4 == 0 {
					print("\(lineString)")
					lineString = ""
				}
            })
            if counter % 4 != 0 {
				// The last line didn't have 4 full hex values on it, spit out the last bit
				// A 32-bit number printed in hex with the leading 0x is 10 characters long
				// plus the space that precedes it, making 11 characters per missing word
				let numMissing = 4 - counter%4
				let paddingString = String(count: 11*numMissing, repeatedValue: " " as Character) + "\t\t"
				print("\(paddingString)\(lineString)")
			}
        case .AutoDump:
            // Toggle current auto-dump setting
            self.autodump = !self.autodump
            print("Auto-dump \(self.autodump ? "enabled" : "disabled").")
        case .Exit(let code):
            print("Exiting MIPSwift.")
            if self.usingFile {
                self.inputSource.closeFile()
            }
            stdIn.closeFile()
            exit(code)
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
            print("The value printed with the prompt is the current value of the program counter. For example: '\(beginningText.toHexWith0x())>'")
            print("To enter an interpreter command, type '\(commandDelimiter)' followed by the command. Type '\(commandDelimiter)commands' to see all commands.")
        case .Commands:
            print("All interpreter commands:")
            print("\tautoexecute|ae: toggle auto-execution of entered instructions.")
            print("\texecute|exec|ex|e: execute all instructions previously paused by disabling auto-execution.")
            print("\ttrace|t: toggle printing of every instruction as it is executed.")
            print("\tverbose|v: toggle verbose parsing of instructions.")
            print("\tregisterdump|regdump|registers|regs|rd: print the current values of all registers.")
            print("\tregister|reg|r [register]: print the current value of a register.")
            print("\tautodump|ad: toggle auto-dump of registers after execution of every instruction.")
            print("\tlabeldump|labels|ld: print all labels as well as their locations.")
            print("\tlabel|l [label]: print the location of a label.")
            print("\tinstructions|insts|instructiondump|instdump|id: print all instructions as well as their locations.")
            print("\tinstruction|inst|i [location]: print the instruction at a location.")
            print("\tmemory|mem|m [location|register|label] [count]: print a number of words beginning at a location in memory.")
            print("\thexadecimal|hex: set register dumps to print out values in hexadecimal (base 16).")
            print("\tdecimal|dec: set register dumps to print out values in signed decimal (base 10).")
            print("\toctal|oct: set register dumps to print out values in octal (base 8).")
            print("\tbinary|bin: set register dumps to print out values in binary (base 2).")
            print("\tstatus|settings|s: display current interpreter settings.")
            print("\thelp|h|?: display the help message.")
            print("\tabout: display information about this software.")
            print("\tcommands|cmds|c: display this message.")
            print("\tnoop|n: do nothing.")
            print("\tfile|f|use|usefile|openfile|open|o [file]: open a file to read instructions from (auto-execution will be paused).")
            print("\texit|quit|q: exit the interpreter.")
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
        }
    }
	
	/// Execute a parsed instruction. Assumes that no .Directive types will be
	/// passed in.
    func executeInstruction(instruction: Instruction) {
        if self.trace {
			if let encoding = instruction.numericEncoding {
				print("\(instruction)\t\t\(encoding.format(PrintOption.Binary.rawValue))")
			} else {
				print("\(instruction)")
			}
        }
		
        // Update the current location
        let newLocation = instruction.location + instruction.pcIncrement
        self.currentWriteLocation = newLocation
		self.registers.set(pc.name, newLocation)
		
        switch(instruction.type) {
        case let .ALUR(op, dest, src1, src2):
            let src1Value = self.registers.get(src1.name)
			let src2Value: Int32
			switch(src2) {
			case .Left(let reg):
				src2Value = self.registers.get(reg.name)
			case .Right(let shift):
				src2Value = shift
			}
            switch(op) {
            case .Left(let op32):
                let result = op32(src1Value, src2Value)
                self.registers.set(dest.name, result)
            case .Right(let op64):
                // This instruction generates a 64-bit result, whose value will be stored in hi and lo
                let (hiValue, loValue) = op64(src1Value, src2Value)
                self.registers.set(hi.name, hiValue)
                self.registers.set(lo.name, loValue)
            }
        case let .ALUI(op, dest, src1, src2):
            let src1Value = self.registers.get(src1.name)
			let result = op(src1Value, src2.signExtended)
			self.registers.set(dest.name, result)
        case let .Memory(storing, size, memReg, offset, addrReg):
            let addrRegValue = self.registers.get(addrReg.name)
            let address = addrRegValue + offset.signExtended // Immediate is offset in bytes
            if address % Int32(1 << size) != 0 {
                print("Unaligned memory address: \(address.toHexWith0x())")
				break // TODO terminate here in the future?
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
                    self.memory[address + 1] = lowest
                case 2:
                    // Storing a word
                    let (highest, higher, lower, lowest) = valueToStore.toBytes()
                    self.memory[address] = highest
                    self.memory[address + 1] = higher
                    self.memory[address + 2] = lower
                    self.memory[address + 3] = lowest
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
                    loadedValue = Int32(highest: 0, higher: 0, lower: self.memory[address] ?? 0, lowest: self.memory[address + 1] ?? 0)
                case 2:
                    // Loading a word
                    let highest = self.memory[address] ?? 0
                    let higher = self.memory[address + 1] ?? 0
                    let lower = self.memory[address + 2] ?? 0
                    let lowest = self.memory[address + 3] ?? 0
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
                self.registers.set(ra.name, self.currentTextLocation)
            }
            self.registers.set(pc.name, destinationAddress)
            self.currentTextLocation = destinationAddress
        case let .Branch(op, link, src1, src2, dest):
            let reg1Value = self.registers.get(src1.name)
			let src2Value: Int32
			if src2 != nil {
				// Comparing with a second register
				src2Value = self.registers.get(src2!.name)
			} else {
				// Comparing with 0
				src2Value = 0
			}
            if op(reg1Value, src2Value) {
                // Take this branch
                guard let destinationAddress = labelsToLocations[dest] else {
                    fatalError("Undefined label: \(dest)") // Not checked until execution to allow labels do be defined anywhere before running
                }
                if link {
                    self.registers.set(ra.name, self.currentTextLocation)
                }
                self.registers.set(pc.name, destinationAddress)
                self.currentTextLocation = destinationAddress
            }
        case .Directive(_):
			// Never reached, directives are always executed immediately
			fatalError("Cannot execute directive as instruction.")
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
	
	/// Execute a syscall.
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
            // Print the string that starts at address $a0 and go until '\0' (0x00) is found
            let address = self.registers.get("$a0")
			var charValue = self.memory[address] ?? 0
			while charValue != 0 {
				print(UnicodeScalar(charValue), terminator: "")
				charValue = self.memory[address] ?? 0
			}
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
			self.executeCommand(.Exit(code: 0))
        case .Exit2:
            // The assembly program has exited with exit code in $a0
            print("Program terminated with exit code \(self.registers.get("$a0"))")
			self.executeCommand(.Exit(code: self.registers.get("$a0")))
        default:
			// Either actually invalid or just unimplemented
            print("Invalid syscall code: \(self.registers.get("$v0"))")
        }
    }
	
	/// Execute an assembler directive.
    func executeDirective(instruction: Instruction) {
        if case let .Directive(directive, args) = instruction.type {
            // Arguments, if any, are guaranteed to be valid at this point
            switch(directive) {
            case .Text:
                self.writingData = false
            case .Data:
                self.writingData = true
            case .Global:
                let label = args[0]
                // If label is already defined, don't need to do anything
                // If it isn't already defined, TODO implement
                if labelsToLocations[label] == nil {
                    print("Undefined label: \(label) TODO implement")
                }
            case .Align:
                // Align current counter to a 2^n-byte boundary; increment already calculated
				self.currentWriteLocation += instruction.pcIncrement
            case .Space:
                // Allocate n bytes, which essentially amounts to skipping forward n bytes
				self.currentWriteLocation += instruction.pcIncrement
            case .Word:
                let initialValues = args.map({ return Int32($0)! })
				for value in initialValues {
					self.memory[self.currentWriteLocation++] = value.unsignedHighest8()
					self.memory[self.currentWriteLocation++] = value.unsignedHigher8()
					self.memory[self.currentWriteLocation++] = value.unsignedLower8()
					self.memory[self.currentWriteLocation++] = value.unsignedLowest8()
				}
            case .Half:
                let initialValues = args.map({ return Int16($0)! })
				for value in initialValues {
					self.memory[self.currentWriteLocation++] = value.unsignedUpper8()
					self.memory[self.currentWriteLocation++] = value.unsignedLower8()
				}
            case .Byte:
                let initialValues = args.map({ return Int8($0)! })
				for value in initialValues {
					self.memory[self.currentWriteLocation++] = UInt8(bitPattern: value)
				}
            case .Ascii, .Asciiz:
				let string = args[0] // Already has the null terminator if appropriate, sequences are escaped
				for char in string.unicodeScalars {
					let value = UInt8(char.value)
					self.memory[self.currentWriteLocation++] = value
				}
            }
        } else {
            fatalError("Attempting to execute illegal directive: \(instruction)")
        }
    }
}