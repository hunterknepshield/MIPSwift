//
//  Command.swift
//  MIPSwift
//
//  Created by Hunter Knepshield on 12/10/15.
//  Copyright © 2015 Hunter Knepshield. All rights reserved.
//

import Foundation

/// Representation of an interpreter command.
enum Command {
	/// Toggle auto-execution of instructions. If auto-execute was just enabled
	/// by this command, call resumeExecution() to ensure no instructions are
	/// skipped.
    case AutoExecute
	/// Execute all previously stored and as-of-yet unexecuted instructions.
    case Execute
	/// Toggle printing of every unstruction as it is executed.
    case Trace
	/// Toggle verbose parsing of instructions.
    case Verbose
	/// Print the current values of all registers.
    case RegisterDump
	/// Print the current value of a register.
	///
	/// - Parameter register: The name of the register whose value will be printed.
	case SingleRegister(register: String)
	/// Toggle auto-dump of registers after execution of every instruction.
    case AutoDump
	/// Print all labels as well as their locations.
    case LabelDump
	/// Print the location of a label.
	///
	/// - Parameter label: The name of the label whose information will be printed.
	case SingleLabel(label: String)
	/// Print all as-of-yet unresolved labels.
	case Unresolved
	/// Print all instructions as well as their locations.
    case InstructionDump
	/// Print the instruction at a location.
	///
	/// - Parameter location: A location in memory.
	case SingleInstruction(location: Int32)
	/// Print a number of words beginning at a location in memory.
	///
	/// - Parameters:
	///		- location: The location, label, or register whose value at which
	///		memory values will be printed.
	///		- numWords: The number of words to print.
	case Memory(location: Either3<Int32, Register, String>, numWords: Int)
	/// Set register dumps to print out values in hexadecimal.
	case Hex
	/// Set register dumps to print out values in decimal.
	case Decimal
	/// Set register dumps to print out values in octal.
	case Octal
	/// Set register dumps to print out values in binary.
	case Binary
	/// Display current interpreter settings.
    case Status
	/// Display the help message.
    case Help
	/// Display the about message.
    case About
	/// Display the commands message.
    case Commands
	/// Do nothing
    case NoOp
	/// Open a file to read instructions from, pausing auto-execution first.
	///
	/// - Parameter file: The file name to be opened.
	case UseFile(file: String)
	/// Exit the interpreter.
	///
	/// - Parameter code: The code with which to exit.
	case Exit(code: Int32)
	
    /// Construct a Command from an input string. May fail if the command or its
	/// necessary arguments are invalid.
    init?(_ string: String) {
        if string == "" {
            self = .NoOp
            return
        }
        let strippedString = string[1..<string.characters.count] // Remove the commandDelimiter character
        let commandAndArgs = strippedString.componentsSeparatedByCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        let command = commandAndArgs[0]
        let args = Array(commandAndArgs[1..<commandAndArgs.count])
		let argCount = args.count
        switch(command) {
        case "autoexecute", "ae":
            self = .AutoExecute
        case "execute", "exec", "ex", "e":
            self = .Execute
        case "trace", "t":
            self = .Trace
        case "verbose", "v":
            self = .Verbose
        case "labels", "labeldump", "ld":
            self = .LabelDump
        case "label", "l":
            if argCount != 1 {
				print("Command \(command) expects 1 argument, got \(argCount).")
				return nil
            } else {
                if validLabelRegex.test(args[0]) {
                    self = .SingleLabel(label: args.first!)
                } else {
					print("Invalid label: \(args[0])")
					return nil
                }
            }
		case "unresolved", "unres", "u":
			self = .Unresolved
        case "instructions", "insts", "instructiondump", "instdump", "id":
            self = .InstructionDump
        case "instruction", "inst", "i":
            if argCount != 1 {
				print("Command \(command) expects 1 argument, got \(argCount).")
				return nil
            } else if !valid32BitHexRegex.test(args[0]) {
				print("Invalid location: \(args[0])")
				return nil
			} else {
                // Attempt to read a hex value
                let scanner = NSScanner(string: args[0])
                let pointer = UnsafeMutablePointer<UInt32>.alloc(1)
                defer { pointer.dealloc(1) } // Called when execution leaves the current scope
                if scanner.scanHexInt(pointer) {
                    if pointer.memory != 0 && pointer.memory < UINT32_MAX {
                        // Safe to make an Int32 from this value
                        self = .SingleInstruction(location: Int32(pointer.memory))
                    } else {
                        // Unsafe to make an Int32 from this value, just complain
						print("Invalid location: \(args[0])")
						return nil
                    }
                } else {
					print("Invalid location: \(args[0])")
					return nil
                }
            }
        case "memory", "mem", "m":
            if argCount == 0 || argCount > 2 {
				print("Command \(command) expects 1 or 2 arguments, got \(argCount).")
				return nil
            } else {
				// Check first if the user entered a register, then a label, otherwise try to make a location from hex
				let location: Either3<Int32, Register, String>
                if args[0].containsString(registerDelimiter) {
                    guard let reg = Register(args[0], writing: false, user: false) else {
						print("Invalid location: \(args[0])")
						return nil
                    }
					location = .Middle(reg)
				} else if validLabelRegex.test(args[0]) {
					// Slight preference to labels over raw hex addresses
					location = .Right(args[0])
				} else if valid32BitHexRegex.test(args[0]) {
					// Attempt to read a hex value
                    let scanner = NSScanner(string: args[0])
                    let pointer = UnsafeMutablePointer<UInt32>.alloc(1)
                    defer { pointer.dealloc(1) } // Called when execution leaves the current scope
                    if scanner.scanHexInt(pointer) {
                        if pointer.memory < UINT32_MAX {
                            // Safe to make an Int32 from this value
                            let address = pointer.memory.signed()
                            if address % 4 != 0 {
								print("Unaligned memory address: \(address.toHexWith0x())")
								return nil
                            }
							location = .Left(address)
                        } else {
                            // Unsafe to make an Int32 from this value, just complain
							print("Invalid location: \(args[0])")
							return nil
                        }
                    } else {
						print("Invalid location: \(args[0])")
						return nil
                    }
				} else {
					print("Invalid location: \(args[0])")
					return nil
				}
				let numWords: Int
				if argCount > 1 {
					// User also specified a number of words to read
					guard let num = Int(args[1]) where num > 0 else {
						print("Invalid number of bytes specified: \(args[1])")
						return nil
					}
					numWords = num
				} else {
					numWords = 4
				}
				self = .Memory(location: location, numWords: numWords)
            }
        case "registerdump", "regdump", "registers", "regs", "rd":
            self = .RegisterDump
        case "register", "reg", "r":
            if argCount != 1 {
				print("Command \(command) expects 1 argument, got \(argCount).")
				return nil
            } else {
                if validRegisters.contains(args[0]) {
					self = .SingleRegister(register: args[0])
                } else {
					print("Invalid register reference: \(args[0])")
					return nil
                }
            }
        case "autodump", "ad":
            self = .AutoDump
        case "hex", "hexadecimal":
            self = .Hex
        case "dec", "decimal":
            self = .Decimal
        case "oct", "octal":
            self = .Octal
        case "bin", "binary":
            self = .Binary
        case "s", "settings", "status":
            self = .Status
        case "help", "h", "?":
            self = .Help
        case "commands", "cmds", "c":
            self = .Commands
        case "about":
            self = .About
        case "noop", "n", "":
            self = .NoOp
        case "file", "use", "usefile", "open", "openfile", "o", "f":
            if argCount != 1 {
				print("Command \(command) expects 1 argument, got \(argCount).")
				return nil
            } else {
                self = .UseFile(file: args[0])
            }
        case "exit", "quit", "q":
			self = .Exit(code: 0)
        default:
			return nil
        }
    }
}