//
//  String.swift
//  SwiftyLibuv
//
//  Created by Yuki Takei on 6/12/16.
//
//

import Foundation


extension String {
    var buffer: UnsafePointer<Int8>? {
        return NSString(string: self).utf8String
    }
}
