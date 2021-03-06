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
    case Left(L)
	/// This value was of the second type that this enumeration wraps.
    case Right(R)
}

/// A simple wrapper to allow efficient passing of a parameter that may have
/// three different types.
enum Either3<L, M, R> {
	/// This value was of the first type that this enumeration wraps.
	case Left(L)
	/// This value was of the second type that this enumeration wraps.
	case Middle(M)
	/// This value was of the third type that this enumeration wraps.
	case Right(R)
}