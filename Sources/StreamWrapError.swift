//
//  StreamWrapError.swift
//  Slimane
//
//  Created by Yuki Takei on 8/12/16.
//
//

public enum StreamWrapError: Error {
    case eof
    case noPendingCount
    case pendingTypeIsMismatched
}
