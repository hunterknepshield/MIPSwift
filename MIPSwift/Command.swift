//
//  Command.swift
//  MIPSwift
//
//  Created by Hunter Knepshield on 12/10/15.
//  Copyright © 2015 Hunter Knepshield. All rights reserved.
//

import Foundation

// Representation of an interpreter command
enum Command {
    case AutoExecute
    case Execute
    case Trace
    case Verbose
    case RegisterDump
    case SingleRegister(String)
    case AutoDump
    case Hex
    case Decimal
    case Octal
    case Binary
    case LabelDump
    case SingleLabel(String)
    case InstructionDump
    case SingleInstruction(Int32)
    case Memory(Either<Int32, Register>, Int)
    case Status
    case Help
    case About
    case Commands
    case NoOp
    case UseFile(String)
    case Exit
    case Invalid(String)
    
    // Construct a Command from a given string; never fails, but may be .Invalid
    init(_ string: String) {
        if string == "" {
            self = .NoOp
            return
        }
        let strippedString = string[1..<string.characters.count] // Remove the commandDelimiter character
        let commandAndArgs = strippedString.componentsSeparatedByCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
        let command = commandAndArgs[0]
        let args = Array(commandAndArgs[1..<commandAndArgs.count])
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
            if args.count == 0 {
                self = .Invalid("No label name supplied.")
            } else {
                if validLabelRegex.test(args[0]) {
                    self = .SingleLabel(args.first!)
                } else {
                    self = .Invalid("Invalid label: \(args[0])")
                }
            }
        case "instructions", "insts", "instructiondump", "instdump", "id":
            self = .InstructionDump
        case "instruction", "inst", "i":
            if args.count == 0 {
                self = .Invalid("No location supplied.")
            } else {
                // To read a hex value
                let scanner = NSScanner(string: args[0])
                let pointer = UnsafeMutablePointer<UInt32>.alloc(1)
                defer { pointer.dealloc(1) } // Called when execution leaves the current scope
                if scanner.scanHexInt(pointer) {
                    if pointer.memory != 0 && pointer.memory < UINT32_MAX {
                        // Safe to make an Int32 from this value
                        self = .SingleInstruction(Int32(pointer.memory))
                    } else {
                        // Unsafe to make an Int32 from this value, just complain
                        self = .Invalid("Invalid location: \(args[0])")
                    }
                } else {
                    self = .Invalid("Invalid location: \(args[0])")
                }
            }
        case "memory", "mem", "m":
            if args.count == 0 {
                self = .Invalid("No location supplied.")
            } else {
                if args[0].containsString(registerDelimiter) {
                    guard let reg = Register(args[0], writing: false, user: false) else {
                        self = .Invalid("Invalid memory location: \(args[0])")
                        break
                    }
                    let numWords: Int
                    if args.count > 1 {
                        // User also specified a number of words to read
                        guard let num = Int(args[1]) where num > 0 else {
                            self = .Invalid("Invalid number of bytes specified: \(args[1])")
							break
                        }
						numWords = num
                    } else {
                        numWords = 4
                    }
                    self = .Memory(.Right(reg), numWords)
                } else {
                    // To read a hex value
                    let scanner = NSScanner(string: args[0])
                    let pointer = UnsafeMutablePointer<UInt32>.alloc(1)
                    defer { pointer.dealloc(1) } // Called when execution leaves the current scope
                    if scanner.scanHexInt(pointer) {
                        if pointer.memory < UINT32_MAX {
                            // Safe to make an Int32 from this value
                            let address = pointer.memory.signed()
                            if address % 4 != 0 {
                                self = .Invalid("Unaligned memory address: \(address.toHexWith0x())")
                            } else {
                                let numWords: Int
                                if args.count > 1 {
                                    // User also specified a number of words to read
                                    guard let num = Int(args[1]) where num > 0 else {
                                        self = .Invalid("Invalid number of bytes specified: \(args[1])")
                                        break
                                    }
									numWords = num
                                } else {
                                    numWords = 4
                                }
                                self = .Memory(.Left(address), numWords)
                            }
                        } else {
                            // Unsafe to make an Int32 from this value, just complain
                            self = .Invalid("Invalid location: \(args[0])")
                        }
                    } else {
                        self = .Invalid("Invalid location: \(args[0])")
                    }
                }
            }
        case "registerdump", "regdump", "registers", "regs", "rd":
            self = .RegisterDump
        case "register", "reg", "r":
            if args.count == 0 {
                self = .Invalid("No register supplied.")
            } else {
                if validRegisters.contains(args[0]) {
                    self = .SingleRegister(args[0])
                } else {
                    self = .Invalid("Invalid register reference: \(args[0])")
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
            if args.count == 0 {
                self = .Invalid("No file name supplied.")
            } else {
                self = .UseFile(args[0])
            }
        case "exit", "quit", "q":
            self = .Exit
        default:
            self = .Invalid(strippedString)
        }
    }
}