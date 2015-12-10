//
//  StringExtension.swift
//  MIPSwift
//
//  Created by Hunter Knepshield on 12/10/15.
//  Copyright © 2015 Hunter Knepshield. All rights reserved.
//

import Foundation

extension String {
    // Extend String to allow subscripting for easier input parsing
    subscript (i: Int) -> Character {
        return self[self.startIndex.advancedBy(i)]
    }
    
    subscript (i: Int) -> String {
        return String(self[i] as Character)
    }
    
    subscript (r: Range<Int>) -> String {
        return substringWithRange(Range(start: startIndex.advancedBy(r.startIndex), end: startIndex.advancedBy(r.endIndex)))
    }    
}

extension Int32 {
    // Extend Int32 with the capability to format printing
    func format(f: String) -> String {
        return NSString(format: f, self) as String
    }
}

extension Int16 {
    // Extend Int16 with the capability to format printing
    func format(f: String) -> String {
        return NSString(format: f, self) as String
    }
}