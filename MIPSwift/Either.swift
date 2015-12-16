//
//  Either.swift
//  MIPSwift
//
//  Created by Hunter Knepshield on 12/12/15.
//  Copyright © 2015 Hunter Knepshield. All rights reserved.
//

import Foundation

/// A simple wrapper to allow efficient passing of a parameter that may have two
/// different types.
enum Either<L, R> {
	/// This value was of the first type that this enumeration wraps.
	///
	/// Associated values:
	/// - `L`: The value of the first type that this enumeration wraps.
    case Left(L)
	/// This value was of the second type that this enumeration wraps.
	///
	/// Associated values:
	/// - `R`: The value of the second type that this enumeration wraps.
    case Right(R)
}