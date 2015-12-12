//
//  main.swift
//  MIPSwift
//
//  Created by Hunter Knepshield on 12/10/15.
//  Copyright © 2015 Hunter Knepshield. All rights reserved.
//

import Foundation

print("MIPSwift v\(mipswiftVersion)")
var developerOptions = REPLOptions()
developerOptions.autoexecute = false
developerOptions.autodump = true
developerOptions.trace = true
_ = REPL(options: developerOptions)