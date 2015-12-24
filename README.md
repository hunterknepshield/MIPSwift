# MIPSwift
A MIPS interpreter written in Swift by Hunter Knepshield.

## General information
This project is a top-level MIPS interpreter. It runs MIPS 32-bit instructions, and as such uses Int32s prolifically. Originally created to avoid studying for winter finals for as long as possible. Or perhaps "practicing my Swift skills," whichever sounds better. /s

## What it can do
- Execute many MIPS assembly instructions.
- Expand several pseudo instructions into one or more real instructions, just like assemblers do.
- Perform a variety of syscall operations, including reading input and printing output.
- Execute assembler directives, such as .data, .word, .ascii, etc.
- Execute a number of MIPSwift-specific commands for viewing contents of memory and registers, locations of labels, etc.
- Dynamically pause and resume execution at will between input of instructions.
- Set a variety of options for verbose parsing and dumping of various information.
- Read a local file's contents, parse it, and execute instructions within.
- Execute safely - if something would cause an error if it went through to execution, you'll be warned and nothing bad will happen (in most cases; this is not guaranteed).

## What it can't do (yet...?), a.k.a. issues
- Can't generate executables or linkable object files.
- Floating point operations, directives, and instructions are not implemented.
- Overflow handling may still be messy; haven't done enough testing with that yet. No detection or exception handling implementation yet.
- No support yet for the = ("equals") directive, i.e. `PRINT_INT_SYSCALL = 1`; `li $v0, PRINT_INT_SYSCALL`.
- Errors like stack overflow are not checked.
- Simple C-style operations within immediate values are not supported (i.e. `li $t0, 4<<8`; `sw	$4, FRAME_SIZE-4($sp)`)

## License
Modification and redistribution of this software is permitted under the MIT License. See LICENSE.txt for more information.
