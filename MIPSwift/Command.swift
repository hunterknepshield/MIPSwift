//
//  Command.swift
//  MIPSwift
//
//  Created by Hunter Knepshield on 12/10/15.
//  Copyright © 2015 Hunter Knepshield. All rights reserved.
//

import Foundation

enum Command {
    // Representation of a user-entered command, like :dump or :exit
    // These are not instructions and do not affect the register file,
    // and are only executed for effect
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
        let strippedString = string[1..<string.characters.count] // Remove the commandBeginning character
        let commandAndArgs = strippedString.componentsSeparatedByCharactersInSet(NSCharacterSet.whitespaceCharacterSet()) // In case there are arguments to this command
        switch(commandAndArgs[0]) {
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
                if validLabelRegex.test(commandAndArgs[1]) {
                    self = .Label(commandAndArgs[1])
                } else {
                    self = .Invalid("Invalid label: \(commandAndArgs[1])")
                }
            }
        case "instructions", "insts", "instructiondump", "instdump", "id":
            self = .InstructionDump
        case "instruction", "inst", "i":
            if commandAndArgs.count == 1 {
                self = .Invalid("No location supplied.")
            } else {
                let scanner = NSScanner(string: commandAndArgs[1])
                let pointer = UnsafeMutablePointer<UInt32>.alloc(1)
                if scanner.scanHexInt(pointer) {
                    if pointer.memory != 0 && pointer.memory < UINT32_MAX {
                        // Safe to make an Int32 from this value
                        self = .Instruction(Int32(pointer.memory))
                    } else {
                        // Unsafe to make an Int32 from this value, just complain
                        self = .Invalid("Invalid location: \(commandAndArgs[1])")
                    }
                } else {
                    self = .Invalid("Invalid location: \(commandAndArgs[1])")
                }
                pointer.dealloc(1)
            }
        case "registerdump", "regdump", "registers", "regs", "rd":
            self = .RegisterDump
        case "register", "reg", "r":
            if commandAndArgs.count == 1 {
                self = .Invalid("No register supplied.")
            } else {
                if validRegisters.contains(commandAndArgs[1]) {
                    self = .Register(commandAndArgs[1])
                } else {
                    self = .Invalid("Invalid register reference: \(commandAndArgs[1])")
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
            if commandAndArgs.count == 1 {
                self = .Invalid("No file name supplied.")
            } else {
                self = .UseFile(commandAndArgs[1])
            }
        case "exit", "quit", "q":
            self = .Exit
        default:
            self = .Invalid(strippedString)
        }
    }
}