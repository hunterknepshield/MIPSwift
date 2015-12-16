//
//  Regex.swift
//  MIPSwift
//
//  Created by Hunter Knepshield on 12/11/15.
//  Copyright © 2015 Hunter Knepshield. All rights reserved.
//

import Foundation

/// A wrapper for regular expressions.
class Regex {
    let expression: NSRegularExpression
    let pattern: String
	
	/// Initialize with a supplied pattern. Fails if NSRegularExpression
	/// initializer fails.
    init?(_ pattern : String) {
        self.pattern = pattern
        do {
            try self.expression = NSRegularExpression(pattern: pattern, options: [])
        } catch {
            // Fail
            self.expression = NSRegularExpression() // Required by compiler
            return nil
        }
    }
	
	/// Return whether self matches the supplied string or not.
    func test(testString: String) -> Bool {
        let matches = self.expression.matchesInString(testString, options: [], range: NSMakeRange(0, testString.characters.count))
        return matches.count > 0
    }
	
	/// Remove any portions of the supplied string that match self.
    func remove(string: String) -> String {
        return self.replace(string, replacementString: "")
    }
	
	/// Replace any portions of the supplied string that match self.
    func replace(string: String, replacementString: String) -> String {
        return self.expression.stringByReplacingMatchesInString(string, options: [], range: NSMakeRange(0, string.characters.count), withTemplate: replacementString)
    }
}