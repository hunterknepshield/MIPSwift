//
//  Either.swift
//  MIPSwift
//
//  Created by Hunter Knepshield on 12/12/15.
//  Copyright © 2015 Hunter Knepshield. All rights reserved.
//

import Foundation

enum Either<L, R> {
    case Left(L)
    case Right(R)
}