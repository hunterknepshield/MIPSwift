//
//  Regex.swift
//  MIPSwift
//
//  Created by Hunter Knepshield on 12/11/15.
//  Copyright © 2015 Hunter Knepshield. All rights reserved.
//

import Foundation

/// A wrapper for regular expressions with various utility methods for matching.
class Regex {
	/// The NSRegularExpression that this Regex wraps.
    let expression: NSRegularExpression
	
	/// Initialize with a supplied pattern. Fails if NSRegularExpression
	/// initializer fails.
    init?(_ pattern : String) {
        do {
            try self.expression = NSRegularExpression(pattern: pattern, options: [])
        } catch {
            // Failed to generate a valid NSRegularExpression, so fail
            self.expression = NSRegularExpression() // Required by compiler
            return nil
        }
    }
	
	/// Get all valid matches of self in the supplied string. Can optionally
	/// return a specific capture group's value. Will fail at run time if the
	/// capture group specified exceeds the number of capture groups within the
	/// regular expression.
	///
	/// - Parameters:
	///		- testString: The string to match.
	///		- captureGroup: The number (starting at 1) of the capture group to
	///		return. Defaults to no specific capture group (0), returning the entire
	///		match.
	func match(testString: String, captureGroup: Int = 0) -> [String] {
		let matches = self.expression.matchesInString(testString, options: [], range: NSMakeRange(0, testString.characters.count))
		var result = [String]()
		for match in matches {
			let nsrange = match.rangeAtIndex(captureGroup)
			if nsrange.location.toIntMax() == IntMax.max {
				// The capture group had an empty result for this match
				continue
			}
			let range = testString.startIndex.advancedBy(nsrange.location)..<testString.startIndex.advancedBy(nsrange.location + nsrange.length)
			result.append(testString.substringWithRange(range))
		}
		return result
	}
	
	/// Return whether self matches the supplied string or not.
	func test(testString: String) -> Bool {
		return self.match(testString).count > 0
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