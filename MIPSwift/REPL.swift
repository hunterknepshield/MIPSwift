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
	/// Keeps track of any instructions that have as-of-yet unresolved label
	/// dependencies. For example, j label when label has yet to be defined.
	var unresolvedInstructions = [String : [Instruction]]()
	/// Maps constant declarations to their values.
	var constantsToValues = [String : Int32]()
	/// Maps locations in memory to individual bytes.
    var memory = [Int32 : UInt8]()
	/// The current value of the program counter. Used to avoid constantly
	/// getting and setting self.registers.pc.
	var currentTextLocation = beginningText
	/// Keeps track of where execution was last paused.
	var pausedTextLocation: Int32?
	/// Used to determine whether execution is currently being resumed or not.
	/// This avoids issues with multiple levels of recursion when calling
	/// resumeExecution() from a jump or branch.
	var currentlyResuming = false
	/// Used to keep track of current point the interpreter is writing data to
	/// in the data segment
	var currentDataLocation = beginningData
	/// Used to determine whether things are currently being written to the data
	/// or the text segment.
	var writingData = false
	/// Used to determine the current location at which a piece of data should
	/// be written; may be either in the text segment or in the data segment.
	var currentWriteLocation: Int32 {
		get { return self.writingData ? self.currentDataLocation : self.currentTextLocation }
		set {
			if self.writingData { self.currentDataLocation = newValue }
			else { self.currentTextLocation = newValue }
		}
	}
	
	// MARK: Interpreter settings
	
	/// The source from which input is currently being read, may be stdIn or an
	/// open file.
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
		
		// Set initial REPL options
        self.verbose = options.verbose
        self.autodump = options.autodump
        self.autoexecute = options.autoexecute
        self.trace = options.trace
        self.registers.printOption = options.printSetting
        self.inputSource = options.inputSource
        self.usingFile = options.usingFile
        
        // Set initial register values
        self.registers.set(pc.name, beginningText)
        self.registers.set(sp.name, beginningSp)
		self.registers.set(fp.name, beginningSp)
		self.registers.set(gp.name, beginningData)
		self.registers.set(ra.name, beginningRa)
    }
	
	/// Begin reading input. This function will continue running until either an
	/// error occurs within the interpreter itself or the exit command is used.
    @noreturn func run() {
        if self.usingFile {
            print("Reading file.")
        } else {
            print("Ready to read input. Type '\(commandDelimiter)help' for more information.")
        }
        while true {
            if !self.usingFile {
                // Print the prompt if reading from stdIn
                print("\(self.currentWriteLocation.hexWith0x)> ", terminator: "") // Prints PC without a newline
            }
            let input = readInput() // Read input (whitespace is already trimmed from either end)
			for var inputString in input {
				// If this input string is an interpreter command, assume there are no labels or comments to strip
				// Otherwise, strip them, then proceed with parsing
				if inputString == "" || inputString[0] == commandDelimiter {
					// This is a command, not an instruction; parse it as such
					guard let command = Command(inputString) else {
						print("Invalid command: \(inputString)")
						continue
					}
					executeCommand(command)
					continue
				}
				let labels = stripLabels(&inputString)
				if self.verbose && labels.count > 0 {
					print("Label\(labels.count > 1 ? "s" : ""): \(labels.joinWithSeparator(", "))")
				}
				let comment = stripComment(&inputString)
				if self.verbose && comment != nil {
					print("Comment: \(comment!)")
				}
				var args = splitArgs(inputString)
				if self.verbose && args.count > 0 {
					print("Arguments: \(args)")
				}
				if args.count == 0 {
					// This line only contained labels and/or comments, don't execute anything, but store the labels
					storeLabels(labels, location: self.currentWriteLocation)
					continue
				}
				
				// Replace all arguments except the first with constants' values if they're exact matches
				// TODO do this with labels and/or combine constants and labels into one map?
				// + Would allow constants to be defined in the future and execution would just pause like current behavior with undefined labels
				// - Would require more parsing logic on any immediate-based instruction, including la/li
				for (index, arg) in args.dropFirst().enumerate() {
					if validLabelRegex.test(arg), let value = self.constantsToValues[arg] {
						// This argument will be replaced with a constant's value
						if self.verbose {
							print("Replacing argument \(arg) with value \(value).")
						}
						args[index + 1] = "\(value)"
					}
				}
				
				// This line needs to be parsed
				if args[0][0] == directiveDelimiter || (args.count == 3 && args[1] == "=") {
					// This is an assembler directive, not an instruction; parse it as such
					guard let directive = Directive.parseArgs(args) else {
						continue
					}
					executeDirective(directive)
				} else if let instArray = Instruction.parseArgs(args, location: self.currentWriteLocation, verbose: verbose) {
					// This instruction is now known to be valid, so store the labels
					guard storeLabels(labels, location: self.currentWriteLocation) else {
						// At least one label was invalid (already printed to the user), don't store these instructions
						continue
					}
					for inst in instArray {
						// Attempt to resolve dependencies that this instruction has
						let unresolved = inst.unresolvedLabelDependencies
						for label in unresolved {
							if let loc = labelsToLocations[label] {
								// Know the location of this label already
								inst.resolveLabelDependency(label, location: loc)
							} else {
								// Don't yet know the location of this label yet; pause execution to avoid issues
								if self.autoexecute {
									self.autoexecute = false
									self.pausedTextLocation = inst.location
									if !self.usingFile {
										print("Execution will be paused. Attempting to resume execution before all dependencies are resolved will result in undefined behavior.")
									}
									// If a file is being read, the label is likely defined elsewhere already, so don't print anything
								}
								if let existingUnresolved = self.unresolvedInstructions[label] {
									self.unresolvedInstructions[label] = existingUnresolved + [inst]
								} else {
									self.unresolvedInstructions[label] = [inst]
								}
							}
						}
						
						// Check if this location already contains an instruction
						if let existingInstruction = self.locationsToInstructions[inst.location] {
							// This is bad; overwriting an executable instruction
							// This is likely caused by an issue with internal REPL state
							print("Cannot overwrite existing instruction: \(existingInstruction)")
						}
						
						self.locationsToInstructions[inst.location] = inst
						
						// If auto-execution is disabled and there isn't yet a pause location, make one
						if !self.autoexecute && self.pausedTextLocation == nil {
							self.pausedTextLocation = inst.location
						}
						
						// Write this instruction's encoding out to memory
						let encoding = inst.numericEncoding
						if encoding == INT32_MAX {
							// Something went wrong...
							print("\(inst) has no valid encoding.")
						} else {
							self.memory[self.currentWriteLocation] = encoding.highestByte
							self.memory[self.currentWriteLocation + 1] = encoding.higherByte
							self.memory[self.currentWriteLocation + 2] = encoding.lowerByte
							self.memory[self.currentWriteLocation + 3] = encoding.lowestByte
						}
						
						// Increment the current location by however much the instruction requires
						// Don't set self.registers.pc here though, set it in execution (avoids issues with pausing)
						self.locationsToInstructions[self.currentWriteLocation] = inst
						let newPc = self.currentWriteLocation + inst.pcIncrement
						self.currentWriteLocation = newPc
						
						if self.autoexecute {
							executeInstruction(inst)
						}
					}
				} else {
					print("Invalid instruction: \(inputString)")
				}
			}
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
			if self.unresolvedInstructions.count != 0 {
				print("There are still instructions that have unresolved label dependencies. Attempting to resume execution before resolving them will result in undefined behavior. Execute the '\(commandDelimiter)unresolved' comamnd to view them.")
			}
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
	
	/// Strip all labels from an input string using regular expressions. The
	/// string is modified in place.
	///
	/// - Returns: An array of 0 or more valid labels.
	func stripLabels(inout string: String) -> [String] {
		var labels = [String]()
		while case let matches = validLabelDefinitionRegex.match(string) where matches.count > 0 {
			// Remove the label, trim whitespace, and check again
			labels.append(matches[0])
			string.removeRange(string.rangeOfString(matches[0])!)
			string = string.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
		}
		return labels.map({ return String($0.characters.dropLast()) }) // Cuts off the trailing colon
	}
	
	/// Strip the comment from an input string using regular expressions. The
	/// string is modified in place.
	///
	/// - Returns: A comment string (including the delimiter), or nil if no
	///	comment was in this string.
	func stripComment(inout string: String) -> String? {
		let matches: [String]
		if validAsciiDirectiveRegex.test(string) {
			// This is a .ascii/.asciiz directive, want the second capture group of the regex
			matches = validAsciiDirectiveRegex.match(string, captureGroup: 2)
		} else {
			// This isn't a (valid) .ascii/.asciiz directive, use default parsing
			matches = validCommentRegex.match(string)
		}
		
		if matches.count > 0 && matches[0] != "" {
			// Remove the comment, trim whitespace, then return
			string.removeRange(string.rangeOfString(matches[0])!)
			string = string.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
			return matches[0]
		} else {
			// No comment, but trim whitespace just in case
			string = string.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
			return nil
		}
	}
	
	/// Split an input string into its constituent arguments. Assumes that no
	/// labels or comments are in the string.
	///
	/// - Returns: An array of 0 or more arguments (not checked for validity).
	func splitArgs(string: String) -> [String] {
		let defaultSplit = string.componentsSeparatedByCharactersInSet(validInstructionSeparatorsCharacterSet).filter({ return !$0.isEmpty })
		if validAsciiDirectiveRegex.test(string) {
			// This is a .ascii/.asciiz directive, want to capture the directive itself and the literal
			let matches = validAsciiDirectiveRegex.match(string, captureGroup: 1)
			return [defaultSplit[0], matches[0]]
		} else {
			return defaultSplit
		}
	}
	
	/// Set the given location as the location of the supplied labels.
	///
	/// - Returns: A boolean indicating whether or not all labels were
	/// previously undefined.
	func storeLabels(labels: [String], location: Int32) -> Bool {
		// Ensure all labels are fresh; will fail here
		let dupes = labels.filter({ return self.labelsToLocations[$0] != nil || self.constantsToValues[$0] != nil })
		if dupes.count > 0 {
			// There was at least one duplicate label; don't store anything
			print("Name\(dupes.count > 1 ? "s" : "") already defined: \(dupes.joinWithSeparator(", "))")
			return false
		}
		
		// Store newly defined labels in the dictionary, resolving any previously unresolved dependencies if possible
		for label in labels {
			self.labelsToLocations[label] = location
			if let unresolvedArray = self.unresolvedInstructions[label] {
				// There are existing instructions that depend on this label
				for unresolved in unresolvedArray {
					unresolved.resolveLabelDependency(label, location: location)
				}
				self.unresolvedInstructions[label] = nil
			}
		}
		return true
	}
	
	/// Resume execution from the last executed instruction until it catches up
	/// and needs new input.
	func resumeExecution(fromJump: Bool = false) {
		self.currentlyResuming = true
		
		let restoreWritingData: Bool
		if self.writingData {
			self.writingData = false // In case a .data directive was last executed
			restoreWritingData = true
		} else {
			restoreWritingData = false
		}
		
		if !fromJump {
			print("Resuming execution...")
		}
		
        // If fromJump is false, auto-execute was disabled, so resume execution from the instruction at self.pausedTextLocation
		// If fromJump is true, resume execution from the current program counter, since a jump was taken
		var currentInstruction = locationsToInstructions[fromJump ? self.currentTextLocation : (self.pausedTextLocation ?? 0)]
        while currentInstruction != nil {
            // Execute the current instruction, then execute the next instruction, etc. until nil is found
            executeInstruction(currentInstruction!)
            currentInstruction = locationsToInstructions[self.currentTextLocation]
        }
		
		if !fromJump {
			print("Execution has caught up. Auto-execute of instructions is \(self.autoexecute ? "enabled" : "disabled").")
		}
		
		// Update the pausedTextLocation to note that execution has come this far, or wipe it if auto-execute is enabled
		self.pausedTextLocation = self.autoexecute ? nil : self.currentTextLocation
		if restoreWritingData {
			self.writingData = true
		}
		self.currentlyResuming = false
    }
	
	/// Execute a parsed interpreter command.
    func executeCommand(command: Command) {
        switch(command) {
        case .AutoExecute:
            // Toggle current auto-execute setting
			if self.unresolvedInstructions.count > 0 {
				// The user is attempting to resume execution and turn auto-execute on, but there are unresolved instructions
				print("Unable to toggle auto-execute, there are still unresolved label dependencies present. Use the '\(commandDelimiter)unresolved' command to view them.")
				break
			}
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
			if self.unresolvedInstructions.count > 0 {
				// The user is attempting to resume execution, but there are unresolved instructions
				print("Unable to resume execution, there are still unresolved label dependencies present. Use the '\(commandDelimiter)unresolved' command to view them.")
				break
			}
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
            print("All labels currently stored: ", terminator: self.labelsToLocations.count == 0 ? "(none)\n" : "\n")
			let alphabetized = self.labelsToLocations.sort({ return $0.0.1 < $0.1.1 || ($0.0.1 == $0.1.1 && $0.0.0 < $0.1.0) })
			alphabetized.forEach({ print("\t\($0.stringByPaddingToLength(24, withString: " ", startingAtIndex: 0)) \($1.hexWith0x)") })
        case .SingleLabel(let label):
            // Print the location of the given label
            guard let location = labelsToLocations[label] else {
                print("\(label): (undefined)")
                break
            }
            print("\(label): \(location.hexWith0x)")
		case .Unresolved:
			// Print any unresolved labels.
			print("Currently unresolved labels: ", terminator: self.unresolvedInstructions.count == 0 ? "(none)\n" : "")
			print(self.unresolvedInstructions.keys.sort({ $0 < $1 }).joinWithSeparator(", "))
		case .ConstantDump:
			// Print the current constants that are stored
			print("All constants currently stored: ", terminator: self.constantsToValues.count == 0 ? "(none)\n" : "\n")
			let alphabetized = self.constantsToValues.sort({ return $0.0.0 < $0.1.0 })
			alphabetized.forEach({ print("\t\($0.stringByPaddingToLength(24, withString: " ", startingAtIndex: 0)) \($1)") })
		case .SingleConstant(let constant):
			// Print the value of the given constant
			guard let value = self.constantsToValues[constant] else {
				print("\(constant): (undefined)")
				break
			}
			print("\(constant): \(value)")
        case .InstructionDump:
            // Print all instructions currently stored
            print("All instructions currently stored: ", terminator: self.locationsToInstructions.count == 0 ? "(none)\n" : "\n")
            self.locationsToInstructions.sort({ return $0.0 < $1.0 }).forEach({ print("\t\($0.1.description.stringByPaddingToLength(48, withString: " ", startingAtIndex: 0))\($0.1.numericEncoding.format(PrintOption.Binary.rawValue))") })
        case .SingleInstruction(let loc, let count):
            // Print a number of instructions starting at the given location
			let location: Int32
			switch(loc) {
			case .Left(let address):
				location = address
			case .Right(let label):
				guard let address = self.labelsToLocations[label] else {
					print("Undefined label: \(label)")
					location = INT32_MAX
					break
				}
				location = address
			}
			for i in 0..<count {
				// Instructions are on 4-byte boundaries
				if let instruction = self.locationsToInstructions[location + 4*i] {
					print("\t\(instruction.description.stringByPaddingToLength(48, withString: " ", startingAtIndex: 0))\(instruction.numericEncoding.format(PrintOption.Binary.rawValue))")
				} else {
					print("\t\((location + 4*i).hexWith0x):\t(undefined)")
				}
			}
        case .Memory(let loc, let count):
            let location: Int32
            switch(loc) {
            case .Left(let int):
                location = int
			case .Middle(let reg):
				location = self.registers.get(reg.name)
            case .Right(let label):
				guard let loc = self.labelsToLocations[label] else {
					print("Invalid label: \(label)")
					return // Can't just break because of nested switch
				}
				location = loc
            }
            // Print count*4 bytes of memory starting at location
            var words = [Int32]()
			var ascii = "" // Queue up ASCII representations of memory values to print after each line, similar to hexdump
			let distanceToLimit = memoryLimit - location + 1
			if Int(distanceToLimit/4) < count {
				// This operation would cause integer overflow, thereby attempting to access invalid memory space above the memory limit
				print("Cannot access memory space above \(memoryLimit.hexWith0x). Use a count of \(distanceToLimit/4) or try a lower address.")
				break
			}
			// Get the values out of memory
            for i in 0..<count {
                let address = location + 4*i // Loading in 4-byte chunks
				let highest = self.memory[address] ?? 0
				let higher = self.memory[address + 1] ?? 0
				let lower = self.memory[address + 2] ?? 0
				let lowest = self.memory[address + 3] ?? 0
				words.append(Int32(highest: highest, higher: higher, lower: lower, lowest: lowest, extendValue: 0))
				ascii += "\(highest.printableCharacter)\(higher.printableCharacter)\(lower.printableCharacter)\(lowest.printableCharacter)"
            }
            var counter = 0 // For formatting individual lines
			var lineString = "" // The string that will be printed
			// Print the values
            words.forEach({
                if counter % 4 == 0 {
                    // Make new lines every 16 bytes (4 words)
					print("[\((location + counter*4).hexWith0x)]", terminator: "\t")
                }
				lineString += ascii[counter*4..<(counter*4 + 4)]
                print($0.hexWith0x, terminator: ++counter % 4 == 0 ? "\t\t" : " ") // Counter incremented here
				if counter % 4 == 0 {
					// Print the ASCII characters for the values in the most recent 16 bytes
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
			executeCommand(.RegisterDump) // Dump everything before exiting
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
            print("The value printed with the prompt is the current value of the program counter. For example: '\(beginningText.hexWith0x)>'")
            print("To enter an interpreter command, type '\(commandDelimiter)' followed by the command. Type '\(commandDelimiter)commands' to see all commands.")
        case .Commands:
            print("All interpreter commands. Required parameters are displayed in [brackets], optional parameters are displayed in (parentheses), and multiple valid values are separated|by|pipes. Locations are assumed to be given in hexadecimal, and register names must begin with the '\(registerDelimiter)' delimiter.")
            print("\tautoexecute|ae:                                 toggle auto-execution of entered instructions.")
            print("\texecute|exec|ex|e:                              execute all instructions previously paused by disabling auto-execution.")
            print("\ttrace|t:                                        toggle printing of every instruction as it is executed.")
            print("\tverbose|v:                                      toggle verbose parsing of instructions.")
            print("\tregisterdump|regdump|registers|regs|rd:         print the current values of all registers.")
            print("\tregister|reg|r [register]:                      print the current value of a register.")
            print("\tautodump|ad:                                    toggle auto-dump of registers after execution of every instruction.")
            print("\tlabeldump|labels|ld:                            print all labels as well as their locations.")
            print("\tlabel|l [label]:                                print the location of a label.")
			print("\tunresolved|unres|u:                             print any as-of-yet unresolved labels.")
			print("\tconstantdump|constdump|constants|consts|cd:     print all constants as well as their values.")
			print("\tconstant|const|con|c [constant]:                print the value of a constant.")
            print("\tinstructions|insts|instructiondump|instdump|id: print all instructions as well as their locations.")
            print("\tinstruction|inst|i [location|label] (count):    print a number of instructions starting at a location.")
            print("\tmemory|mem|m [location|register|label] (count): print a number of words beginning at a location in memory.")
            print("\thexadecimal|hex:                                set register dumps to print out values in hexadecimal (base 16).")
            print("\tdecimal|dec:                                    set register dumps to print out values in signed decimal (base 10).")
            print("\toctal|oct:                                      set register dumps to print out values in octal (base 8).")
            print("\tbinary|bin:                                     set register dumps to print out values in binary (base 2).")
            print("\tstatus|settings|s:                              display current interpreter settings.")
            print("\thelp|h|?:                                       display the help message.")
            print("\tabout:                                          display information about this software.")
            print("\tcommands|cmds:                                  display this message.")
            print("\tnoop|n:                                         do nothing.")
            print("\tfile|f|use|usefile|openfile|open|o [file]:      open a file to read instructions from (auto-execution will be paused).")
            print("\texit|quit|q:                                    exit the interpreter.")
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
			print("\t\(instruction.description.stringByPaddingToLength(48, withString: " ", startingAtIndex: 0))\(instruction.numericEncoding.format(PrintOption.Binary.rawValue))")
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
        case let .Memory(storing, unsigned, size, memReg, offset, addrReg):
            let addrRegValue = self.registers.get(addrReg.name)
			if memoryLimit - addrRegValue < offset.signExtended {
				// This operation would cause integer overflow, thereby attempting to access invalid memory space above the memory limit
				print("Cannot access memory space above \(memoryLimit.hexWith0x).")
				break // Terminate here in the future?
			}
            let address = addrRegValue + offset.signExtended // Immediate is offset in bytes
            if address % Int32(1 << size) != 0 {
                print("Unaligned memory address: \(address.hexWith0x)")
				break // Terminate here in the future?
            }
            if storing {
                // Storing the value in memReg to memory
                let valueToStore = self.registers.get(memReg.name)
                switch(size) {
                case 0:
                    // Storing a single byte (from low-order bits)
                    self.memory[address] = valueToStore.lowestByte
                case 1:
                    // Storing a half-word (from low-order bits)
                    self.memory[address] = valueToStore.lowerByte
                    self.memory[address + 1] = valueToStore.lowestByte
                default:
                    // Storing a word
                    self.memory[address] = valueToStore.highestByte
                    self.memory[address + 1] = valueToStore.higherByte
                    self.memory[address + 2] = valueToStore.lowerByte
                    self.memory[address + 3] = valueToStore.lowestByte
                }
            } else {
                // Loading a value from memory into memReg
                let loadedValue: Int32
                switch(size) {
                case 0:
                    // Loading a single byte
					loadedValue = Int32(highest: 0, higher: 0, lower: 0, lowest: self.memory[address] ?? 0, extendValue: unsigned ? 0 : 1)
					print(loadedValue.hexWith0x)
                case 1:
                    // Loading a half-word
					loadedValue = Int32(highest: 0, higher: 0, lower: self.memory[address] ?? 0, lowest: self.memory[address + 1] ?? 0, extendValue: unsigned ? 0 : 2)
					print(loadedValue.hexWith0x)
                default:
                    // Loading a word
                    let highest = self.memory[address] ?? 0
                    let higher = self.memory[address + 1] ?? 0
                    let lower = self.memory[address + 2] ?? 0
                    let lowest = self.memory[address + 3] ?? 0
					loadedValue = Int32(highest: highest, higher: higher, lower: lower, lowest: lowest, extendValue: 0)
                }
                self.registers.set(memReg.name, loadedValue)
            }
        case let .Jump(link, dest):
            let destinationAddress: Int32
            switch(dest) {
            case .Left(let reg):
                destinationAddress = self.registers.get(reg.name)
				if destinationAddress == beginningRa {
					// The user has jumped back to the initial return address, assume this means termination
					print("Program terminated with exit code 0.")
					executeCommand(.Exit(code: 0))
				}
            case .Right(let addr):
                destinationAddress = addr << 2
            }
            if link {
                self.registers.set(ra.name, self.currentTextLocation)
            }
            self.registers.set(pc.name, destinationAddress)
            self.currentTextLocation = destinationAddress
        case let .Branch(op, link, src1, src2, offset):
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
				let destinationAddress = instruction.location + (offset.signExtended << 2)
                if link {
                    self.registers.set(ra.name, self.currentTextLocation)
                }
                self.registers.set(pc.name, destinationAddress)
                self.currentTextLocation = destinationAddress
            }
        case .Syscall:
            // Abstract this away; large amount of parsing required
            executeSyscall()
        }
                
        if self.autodump {
            executeCommand(.RegisterDump)
        }
		
		if !self.currentlyResuming && self.currentWriteLocation != instruction.location + instruction.pcIncrement {
			// A jump of some kind has occurred
			resumeExecution(true)
		}
    }
	
	/// Execute a syscall.
    func executeSyscall() {
        guard let syscallCode = SyscallCode(rawValue: self.registers.get(v0.name)) else {
            // Don't fatalError() for now, just output
            print("Invalid syscall code: \(self.registers.get(v0.name))")
            return
        }
        switch(syscallCode) {
        case .PrintInt: // Syscall 1
            // Print the integer currently in $a0
            print(self.registers.get(a0.name))
        case .PrintString: // Syscall 4
            // Print the string that starts at address $a0 and go until '\0' (0x00) is found
            var address = self.registers.get(a0.name)
			var charValue = self.memory[address] ?? 0
			while charValue != 0 {
				print(UnicodeScalar(charValue), terminator: "")
				charValue = self.memory[++address] ?? 0
			}
        case .ReadInt: // Syscall 5
            // Read an integer from standard input and return it in $v0
            // 32 bits, maximum of 2147483647, minimum of -2147483648
            let inputString: String = NSString(data: stdIn.availableData, encoding: NSASCIIStringEncoding)!.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
			if let value = Int32(inputString) {
				self.registers.set(v0.name, value)
			} else {
				// Don't print anything, just return 0 in the v0 register
				self.registers.set(v0.name, 0)
            }
		case .ReadString: // Syscall 8
			// Reads input, storing it in the address supplied in $a0, up to a maximum of
			// n - 1 characters, padding with '\0' wherever reading stops.
			let inputString = NSString(data: stdIn.availableData, encoding: NSASCIIStringEncoding) as! String
			let address = self.registers.get(a0.name)
			let maxChars = Int(self.registers.get(a1.name) - 1)
			if maxChars < 1 {
				// Can't read 0 or negative number of characters; input will just be ignored
				break
			}
			for (index, char) in inputString.unicodeScalars.enumerate() {
				if index == maxChars {
					// Write a '\0' character then break
					self.memory[address + index] = UInt8.allZeros
					break
				}
				self.memory[address + index] = UInt8(char.value)
			}
		case .Exit: // Syscall 10
			// The assembly program has exited, so exit the interpreter as well
			print("Program terminated with exit code 0.")
			self.executeCommand(.Exit(code: 0))
		case .PrintChar: // Syscall 11
			// Print the ASCII representation of the lowest byte of $a0
			let byte = self.registers.get(a0.name).lowestByte
			print(UnicodeScalar(byte), terminator: "")
		case .ReadChar: // Syscall 12
			// Read an ASCII character into $v0
			let inputString = NSString(data: stdIn.availableData, encoding: NSASCIIStringEncoding) as! String
			if inputString.unicodeScalars.count == 0 {
				break
			}
			let char = inputString.unicodeScalars[inputString.unicodeScalars.startIndex]
			self.registers.set(v0.name, char.value.signed)
		// Syscalls 13-16 are scary file stuff
        case .Exit2: // Syscall 17
            // The assembly program has exited with exit code in $a0
            print("Program terminated with exit code \(self.registers.get(a0.name)).")
			self.executeCommand(.Exit(code: self.registers.get(a0.name)))
		case .Time: // Syscall 30
			// Return the low-order bits of the system time in $a0, high-order bits in $a1
			let current = NSDate().timeIntervalSince1970 as Double // Number of seconds since 1/1/1970
			let int = Int64(current*1000) // Number of milliseconds (rounded) since 1/1/1970
			self.registers.set(a0.name, int.unsignedLower32.signed)
			self.registers.set(a1.name, int.unsignedUpper32.signed)
		/*
		case .MidiOut: // Syscall 31
			// $a0 = pitch, $a1 = duration (milliseconds), $a2 = instrument, $a3 = volume
			let pitch: Int
			let a0Value = self.registers.get(a0.name)
			if 0...127 ~= a0Value {
				pitch = Int(a0Value)
			} else {
				pitch = 60 // Middle C
			}
			let duration: Int
			let a1Value = self.registers.get(a1.name)
			if a1Value < 0 {
				duration = 1000
			} else {
				duration = Int(a1Value)
			}
			let instrument: Int
			let a2Value = self.registers.get(a2.name)
			if 0...127 ~= a2Value {
				instrument = Int(a2Value)
			} else {
				instrument = 0 // Acoustic grand piano
			}
			let volume: Int
			let a3Value = self.registers.get(a3.name)
			if 0...127 ~= a3Value {
				volume = Int(a3Value)
			} else {
				volume = 100
			}
			// soundManager.play(440.0, modulatorFrequency: 679.0, modulatorAmplitude: 0.8)
		*/
		case .Sleep: // Syscall 32
			// Sleep for $a0 milliseconds
			let time = self.registers.get(a0.name).unsigned
			sleep(time)
		case .PrintIntHex: // Syscall 34
			// Print $a0 in hex
			let value = self.registers.get(a0.name)
			print(value.format(PrintOption.Hex.rawValue), terminator: "")
		case .PrintIntBinary: // Syscall 35
			// Print $a0 in binary
			let value = self.registers.get(a0.name)
			print(value.format(PrintOption.Binary.rawValue), terminator: "")
		case .PrintIntUnsigned: // Syscall 36
			// Print $a0 as an unsigned value in decimal
			let value = self.registers.get(a0.name).unsigned
			print(value, terminator: "")
        default:
			// Either actually invalid or just unimplemented
            print("Invalid syscall code: \(self.registers.get(v0.name))")
        }
    }
	
	/// Execute an assembler directive.
	func executeDirective(directive: Directive) {
		switch(directive) {
		case .Text:
			self.writingData = false
		case .Data:
			self.writingData = true
		case .Global(_):
			// This directive has no real effect in MIPSwift. If the label is already
			// defined, we don't need to do anything. If it isn't already defined,
			// there's nothing we can do since we still don't know its location.
			break
		case .Align(let n):
			// Align current counter to a 2^n-byte boundary
			let boundary = 1 << n // n = 0 -> boundary = 1, n = 1 -> boundary = 2, n = 2 -> boundary = 4
			while self.currentWriteLocation % boundary != 0 {
				self.currentWriteLocation++
			}
		case .Space(let n):
			// Allocate n bytes, which essentially amounts to skipping forward n bytes
			self.currentWriteLocation += n
		case .Word(let values):
			for value in values {
				self.memory[self.currentWriteLocation++] = value.highestByte
				self.memory[self.currentWriteLocation++] = value.higherByte
				self.memory[self.currentWriteLocation++] = value.lowerByte
				self.memory[self.currentWriteLocation++] = value.lowestByte
			}
		case .Half(let values):
			for value in values {
				self.memory[self.currentWriteLocation++] = value.upperByte
				self.memory[self.currentWriteLocation++] = value.lowerByte
			}
		case .Byte(let values):
			for value in values {
				self.memory[self.currentWriteLocation++] = UInt8(bitPattern: value)
			}
		case .Ascii(let string):
			for char in string.unicodeScalars {
				self.memory[self.currentWriteLocation++] = UInt8(char.value)
			}
		case .Asciiz(let string):
			for char in string.unicodeScalars {
				self.memory[self.currentWriteLocation++] = UInt8(char.value)
			}
		case .Equals(let name, let value):
			// The name and value are guaranteed valid, but the name may not be unique
			if self.constantsToValues[name] != nil {
				print("Name already defined: \(name)")
				break
			}
			self.constantsToValues[name] = value
		}
    }
}