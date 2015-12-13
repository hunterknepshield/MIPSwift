//
//  SyscallCode.swift
//  MIPSwift
//
//  Created by Hunter Knepshield on 12/13/15.
//  Copyright © 2015 Hunter Knepshield. All rights reserved.
//

// Syscall codes and return values:
// http://courses.missouristate.edu/kenvollmar/mars/help/syscallhelp.html

import Foundation

enum SyscallCode: Int32 {
    case PrintInt = 1 // $a0
    case PrintFloat // $f12
    case PrintDouble // $f12
    case PrintString // $a0
    case ReadInt // $v0
    case ReadFloat // $f0
    case ReadDouble // $f0
    case ReadString // $a0 = address, $a1 = max chars
    case SBRK // $a0 = number of bytes, $v0 = address (allocates heap memory)
    case Exit
    case PrintChar // $a0
    case ReadChar // $v0
    case OpenFile // $a0 = address, $a1 = flags, $a2 = mode, $v0 = descriptor
    case ReadFile // $a0 = descriptor, $a1 = address of buffer, $a2 = max chars, $v0 = number of chars read
    case WriteFile // $a0 = descriptor, $a1 = address of buffer, $a2 = max chars, $v0 = number of chars written
    case CloseFile // $a0 = descriptor
    case Exit2 // $a0 = exit code
    
    case Time = 30 // $a0 = low order, $a1 = high order
    case MidiOut // $a0 = pitch, $a1 = duration, $a2 = instrument, $a3 = volume
    case Sleep // $a0
    case MidiOutSynchronous // $a0 = pitch, $a1 = duration, $a2 = instrument, $a3 = volume
    case PrintIntHex // $a0
    case PrintIntBinary // $a0
    case PrintIntUnsigned // $a0
    
    case SetSeed = 40 // $a0 = id, $a1 = seed
    case RandomInt // $a0 = id, $a0 = next value
    case RandomIntRange // $a0 = id, $a1 = upper bound, $a0 = next value
    case RandomFloat // $a0 = id, $f0 = next value
    case RandomDouble // $a0 = id, $f0 = next value
    
    case ConfirmDialog = 50 // $a0 = string address, $a0 = response
    case InputDialogInt // $a0 = string address, $a0 = int read, $a1 = status
    case InputDialogFloat // $a0 = string address, $f0 = float read, $a1 = status
    case InputDialogDouble // $a0 = string address, $f0 = double read, $a1 = status
    case InputDialogString // $a0 = string adress, $a1 = input buffer address, $a2 = max chars, $a1 = status
    case MessageDialog // $a0 = string address, $a1 = message type
    case MessageDialogInt // $a0 = string address, $a1 = int
    case MessageDialogFloat // $a0 = string address, $f12 = float
    case MessageDialogDouble // $a0 = string address, $f12 = double
    case MessageDialogString // $a0 = string address, $a1 = string address
}