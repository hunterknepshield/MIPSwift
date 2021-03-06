//
//  Directive.swift
//  MIPSwift
//
//  Created by Hunter Knepshield on 12/13/15.
//  Copyright © 2015 Hunter Knepshield. All rights reserved.
//

// All directives with descriptions:
// http://students.cs.tamu.edu/tanzir/csce350/reference/assembler_dir.html

import Foundation

/// Representation of an assembler directive. All arguments are wrapped as
/// associated values and are guaranteed to be valid to the extent that they can
/// be without having knowledge from the outside world (e.g. a .Equals directive
/// is guaranteed to wrap a valid name, but that name may be already defined).
enum Directive {
	/// Change to the text segment.
    case Text
	/// Change to the data segment.
    case Data
	/// Declare a global label.
	case Global(label: String)
	/// Align to a 2^n-byte boundary.
	case Align(n: Int32)
	/// Allocate n bytes of space.
	case Space(n: Int32)
	/// Store 1-byte values with initial values supplied.
	case Byte(values: [Int8])
	/// Store 2-byte values with initial values supplied.
	case Half(values: [Int16])
	/// Store 4-byte values with initial values supplied.
	case Word(values: [Int32])
	/// Store a non-null-terminated string.
	case Ascii(string: String)
	/// Store a null-terminated string.
	case Asciiz(string: String)
	/// Store a named constant.
	case Equals(name: String, value: Int32)
	
	init?(_ args: [String]) {
		if args.count == 3 && args[1] == "=" {
			// This is an equals directive, which declares a constant, e.g. PRINT_INT_SYSCALL = 1
			// The constant's name has the same constraints as labels, and the constant must fit in a 32-bit integer
			if !validLabelRegex.test(args[0]) {
				print("Invalid constant name: \(args[0])")
				return nil
			}
			guard validNumericRegex.test(args[2]), let _ = Immediate.parseString(args[2], canReturnTwo: true) else {
				print("Invalid constant value: \(args[2])")
				return nil
			}
			let value: Int32
			if let decimal = Int32(args[2]) {
				value = decimal
			} else {
				value = Int32(args[2].stringByReplacingOccurrencesOfString("0x", withString: ""), radix: 16)!
			}
			self = .Equals(name: args[0], value: value)
			return
		}
		
		let strippedString = String(args[0].characters.dropFirst())
		let argCount = args.count - 1
		switch(strippedString) {
		case "text":
			if argCount != 0 {
				print("Directive \(strippedString) expects 0 arguments, got \(argCount).")
				return nil
			}
			self = .Text
		case "data":
			if argCount != 0 {
				print("Directive \(strippedString) expects 0 arguments, got \(argCount).")
				return nil
			}
			self = .Data
		case "globl":
			if argCount != 1 {
				print("Directive \(strippedString) expects 1 argument, got \(argCount).")
				return nil
			} else if !validLabelRegex.test(args[1]) {
				print("Invalid label: \(args[1])")
				return nil
			}
			self = .Global(label: args[1])
		case "align":
			if argCount != 1 {
				print("Directive \(strippedString) expects 1 argument, got \(argCount).")
				return nil
			} else if !["0", "1", "2"].contains(args[1]) {
				print("Invalid alignment factor: \(args[1])")
				return nil
			}
			let n = Int32(args[1])! // Can safely force this optional
			self = .Align(n: n)
		case "space":
			if argCount != 1 {
				print("Directive \(strippedString) expects 1 argument, got \(argCount).")
				return nil
			}
			guard let n = Int32(args[1]) where n >= 0 else {
				print("Invalid number of bytes to allocate: \(args[1])")
				return nil
			}
			self = .Space(n: n)
		case "byte":
			if argCount == 0 {
				print("Directive \(strippedString) expects 1 or more arguments, got 0.")
				return nil
			}
			var invalid = [String]()
			var values = [Int8]()
			for arg in args.dropFirst() {
				guard let byte = Int8(arg) else {
					invalid.append(arg)
					continue
				}
				values.append(byte)
			}
			if invalid.count > 0 {
				print("Invalid argument\(invalid.count > 1 ? "s" : ""): \(invalid.joinWithSeparator(", "))")
				return nil
			}
			self = .Byte(values: values)
		case "half":
			if argCount == 0 {
				print("Directive \(strippedString) expects 1 or more arguments, got 0.")
				return nil
			}
			var invalid = [String]()
			var values = [Int16]()
			for arg in args.dropFirst() {
				guard let half = Int16(arg) else {
					invalid.append(arg)
					continue
				}
				values.append(half)
			}
			if invalid.count > 0 {
				print("Invalid argument\(invalid.count > 1 ? "s" : ""): \(invalid.joinWithSeparator(", "))")
				return nil
			}
			self = .Half(values: values)
		case "word":
			if argCount == 0 {
				print("Directive \(strippedString) expects 1 or more arguments, got 0.")
				return nil
			}
			var invalid = [String]()
			var values = [Int32]()
			for arg in args.dropFirst() {
				guard let word = Int32(arg) else {
					invalid.append(arg)
					continue
				}
				values.append(word)
			}
			if invalid.count > 0 {
				print("Invalid argument\(invalid.count > 1 ? "s" : ""): \(invalid.joinWithSeparator(", "))")
				return nil
			}
			self = .Word(values: values)
		case "ascii", "asciiz":
			if argCount != 1 {
				print("Directive \(strippedString) expects 1 argument, got \(argCount).")
				return nil
			}
			let noDelimiters = args[1][1..<args[1].characters.count - 1]
			guard let escapedArgument = noDelimiters.compressedEscapes else {
				print("Invalid string literal: \(args[1])")
				return nil
			}
			self = (args[0] == ".ascii" ? .Ascii(string: escapedArgument) : .Asciiz(string: escapedArgument + "\0"))
		default:
			print("Invalid directive: \(args[0])")
			return nil
		}
	}
}