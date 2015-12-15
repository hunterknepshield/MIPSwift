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
    case Register(String)
    case AutoDump
    case Hex
    case Decimal
    case Octal
    case Binary
    case LabelDump
    case Label(String)
    case InstructionDump
    case Instruction(Int32)
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
        let args = commandAndArgs[1..<commandAndArgs.count]
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
            if commandAndArgs.count == 1 {
                self = .Invalid("No label name supplied.")
            } else {
                if validLabelRegex.test(args[0]) {
                    self = .Label(args[0])
                } else {
                    self = .Invalid("Invalid label: \(args[0])")
                }
            }
        case "instructions", "insts", "instructiondump", "instdump", "id":
            self = .InstructionDump
        case "instruction", "inst", "i":
            if commandAndArgs.count == 1 {
                self = .Invalid("No location supplied.")
            } else {
                let scanner = NSScanner(string: args[0])
                let pointer = UnsafeMutablePointer<UInt32>.alloc(1)
                if scanner.scanHexInt(pointer) {
                    if pointer.memory != 0 && pointer.memory < UINT32_MAX {
                        // Safe to make an Int32 from this value
                        self = .Instruction(Int32(pointer.memory))
                    } else {
                        // Unsafe to make an Int32 from this value, just complain
                        self = .Invalid("Invalid location: \(args[0])")
                    }
                } else {
                    self = .Invalid("Invalid location: \(args[0])")
                }
                pointer.dealloc(1)
            }
        case "registerdump", "regdump", "registers", "regs", "rd":
            self = .RegisterDump
        case "register", "reg", "r":
            if commandAndArgs.count == 1 {
                self = .Invalid("No register supplied.")
            } else {
                if validRegisters.contains(args[0]) {
                    self = .Register(args[0])
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