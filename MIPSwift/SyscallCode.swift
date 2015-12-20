//
//  SyscallCode.swift
//  MIPSwift
//
//  Created by Hunter Knepshield on 12/13/15.
//  Copyright © 2015 Hunter Knepshield. All rights reserved.
//

// All syscall codes and return values:
// http://courses.missouristate.edu/kenvollmar/mars/help/syscallhelp.html

import Foundation

/// Representation of a syscall. The raw values are the value stored in $v0 at
/// the time of the syscall's execution. Additional arguments and return values
/// are dependent on the type of syscall.
enum SyscallCode: Int32 {
	/// $a0 = value to print.
    case PrintInt = 1
	/// $f12 = value to print.
    case PrintFloat
	/// $f12 = value to print.
    case PrintDouble
	/// $a0 = value to print.
    case PrintString
	/// $v0 = value read.
    case ReadInt
	/// $f0 = value read.
    case ReadFloat // $f0
	/// $f0 = value read.
    case ReadDouble // $f0
	/// $a0 = address of string to read into, $a1 = maximum number of characters
	/// to read. Reads up to n - 1 characters and pads with '\0' (this is the
	/// standard UNIX behavior).
    case ReadString
	/// $a0 = number of bytes to allocate, $v0 = address of allocated space.
    case SBRK
	/// No arguments.
    case Exit
	/// $a0 = value to print.
    case PrintChar
	/// $v0 = value read.
    case ReadChar
	/// $a0 = address of file name, $a1 = flags, $a2 = mode, $v0 = descriptor.
    case OpenFile
	/// $a0 = descriptor, $a1 = address of buffer to read into, $a2 = maximum
	/// number of characters to read, $v0 = number of characters read.
    case ReadFile
	/// $a0 = descriptor, $a1 = address of buffer to read into, $a2 = maximum
	/// number of characters to read, $v0 = number of characters written.
    case WriteFile
	/// $a0 = descriptor.
    case CloseFile
	/// $a0 = exit code.
    case Exit2
	
	/// $a0 = low order bits, $a1 = high order bits
    case Time = 30
	/// $a0 = pitch, $a1 = duration (milliseconds), $a2 = instrument, $a3 =
	/// volume.
    case MidiOut
	/// $a0 = duration (milliseconds)
    case Sleep
	/// $a0 = pitch, $a1 = duration (milliseconds), $a2 = instrument, $a3 =
	/// volume.
    case MidiOutSynchronous
	/// $a0 = value to print.
    case PrintIntHex
	/// $a0 = value to print.
	case PrintIntBinary
	/// $a0 = value to print.
	case PrintIntUnsigned
	
	/// $a0 = id, $a1 = seed.
    case SetSeed = 40
	/// $a0 = id, $a0 = next value.
    case RandomInt
	/// $a0 = id, $a1 = upper bound, $a0 = next value.
    case RandomIntRange
	/// $a0 = id, $f0 = next value.
    case RandomFloat
	/// $a0 = id, $f0 = next value.
    case RandomDouble
	
	/// $a0 = string address, $a0 = response
    case ConfirmDialog = 50
	/// $a0 = string address, $a0 = value read, $a1 = status
    case InputDialogInt
	/// $a0 = string address, $f0 = value read, $a1 = status
    case InputDialogFloat
	/// $a0 = string address, $f0 = value read, $a1 = status
    case InputDialogDouble
	/// $a0 = string address, $a1 = input buffer address, $a2 = maximum number
	/// of characters, $a1 = status.
    case InputDialogString
	/// $a0 = string address, $a1 = message type.
    case MessageDialog
	/// $a0 = string address, $a1 = value to print.
    case MessageDialogInt
	/// $a0 = string address, $f12 = value to print.
    case MessageDialogFloat
	/// $a0 = string address, $f12 = value to print.
    case MessageDialogDouble
	/// $a0 = string address, $a1 = string address.
    case MessageDialogString
}