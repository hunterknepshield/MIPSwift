//
//  Regex.swift
//  MIPSwift
//
//  Created by Hunter Knepshield on 12/11/15.
//  Copyright © 2015 Hunter Knepshield. All rights reserved.
//

import Foundation

class Regex {
    let expression: NSRegularExpression
    let pattern: String
    
    init(_ pattern : String){
        self.pattern = pattern
        do {
            try self.expression = NSRegularExpression(pattern: pattern, options: [.CaseInsensitive])
        } catch {
            // Do nothing
            self.expression = NSRegularExpression()
        }
    }
    
    func test(testString: String) -> Bool {
        let matches = self.expression.matchesInString(testString, options: [], range: NSMakeRange(0, testString.characters.count))
        return matches.count > 0
    }
    
    func remove(string: String) -> String {
        return self.expression.stringByReplacingMatchesInString(string, options: [], range: NSMakeRange(0, string.characters.count), withTemplate: "")
    }
    
    func replace(string: String, replacementString: String) -> String {
        return self.expression.stringByReplacingMatchesInString(string, options: [], range: NSMakeRange(0, string.characters.count), withTemplate: replacementString)
    }
}