//
//  Error.swift
//  SwiftyLibuv
//
//  Created by Yuki Takei on 6/12/16.
//
//

import CLibUv

/**
 Common Error enum for Suv
 */
public enum Error: ErrorProtocol, CustomStringConvertible {
    // Error from libuv's errorno
    case uvError(code: Int32)
    case eof
    case noPendingCount
    case pendingTypeIsMismatched
    case argumentError(message: String)
    case bindRequired
}

extension Error {
    /**
     Returns errorno for uvError
     */
    public var errorno: uv_errno_t? {
        switch(self) {
        case .uvError(let code):
            return uv_errno_t(code)
        default:
            return nil
        }
    }
    
    /**
     Returns error type for uvError
     */
    public var type: String {
        switch(self) {
        case .uvError(let code):
            return String(validatingUTF8: uv_err_name(code)) ??  "UNKNOWN"
        default:
            return "SwiftyLibuvError"
        }
    }
    
    /**
     Returns error message
     */
    public var message: String {
        switch(self) {
        case .uvError(let code):
            return String(validatingUTF8: uv_strerror(code)) ?? "Unknow Error"
        case .eof:
            return "EOF"
        case .noPendingCount:
            return "No pending count"
        case .pendingTypeIsMismatched:
            return "Penging type is mismatched"
        case .argumentError(let message):
            return message
        case .bindRequired:
            return "First, You need to call `bind`"
        }
    }
    
    /**
     Returns error description
     */
    public var description: String {
        return "\(type): \(message)"
    }
}
