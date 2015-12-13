//
//  main.swift
//  MIPSwift
//
//  Created by Hunter Knepshield on 12/10/15.
//  Copyright © 2015 Hunter Knepshield. All rights reserved.
//

import Foundation

print("MIPSwift v\(mipswiftVersion)")

let args = Process.arguments
var printUsage = false
var useDeveloperOptions = false
var defaultOptions = REPLOptions() // verbose = false, autodump = false, autoexecute = true, trace = false, printSetting = .Hex, inputSource = stdIn, usingFile = false
var developerOptions = REPLOptions(verbose: false, autodump: true, autoexecute: false, trace: true, printSetting: .Hex, inputSource: stdIn, usingFile: false)

// Parse command line arguments if there are any
for (index, argument) in args.enumerate() {
    // print("\(index): \(argument)")
    if index == 0 {
        // This is the executable's name, nothing exciting to parse
        continue
    } else {
        if ["-f", "--file", "--filename"].contains(args[index - 1]) {
            // This was the file's name, just skip it
            continue
        }
    }
    switch(argument) {
    case "-d", "--developer":
        useDeveloperOptions = true
    case "-noae", "--noautoexecute":
        defaultOptions.autoexecute = false
        // developerOptions.autoexecute is already false
    case "-f", "--file", "--filename":
        // The user is specifying a file name to read from
        if index < args.count - 1 {
            // There's at least 1 more argument, assume it's the file name
            let filename = args[index + 1]
            if let fileHandle = NSFileHandle(forReadingAtPath: filename) {
                defaultOptions.inputSource = fileHandle
                defaultOptions.usingFile = true
                developerOptions.inputSource = fileHandle
                developerOptions.usingFile = true
            } else {
                assertionFailure("Unable to open file: \(filename)")
            }
            // Also turn off auto-execute, as labels may be used before they're defined within a file
            defaultOptions.autoexecute = false
            // developerOptions.autoexecute is already false
        } else {
            assertionFailure("Input file \(argument) argument specified, but no file name present.")
        }
    default:
        print("Illegal argument: \(argument)")
        printUsage = true
    }
}

if printUsage {
    print("Usage: \(args[0]) \(commandLineOptions)")
    print("\td: start with 'developer' interpreter settings by default (auto-dump on, auto-execute off, trace on).")
    print("\tnoae: start auto-execute off.")
    print("\tf file: open file instead of reading instructions from standard input.")
} else {
    _ = REPL(options: useDeveloperOptions ? developerOptions : defaultOptions)
}