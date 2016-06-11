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
    case UVError(code: Int32)
    case EOF
    case NoPendingCount
    case PendingTypeIsMismatched
    case ClosedStream
    case ArgumentError(message: String)
    case BindRequired
}

extension Error {
    /**
     Returns errorno for UVError
     */
    public var errorno: uv_errno_t? {
        switch(self) {
        case .UVError(let code):
            return uv_errno_t(code)
        default:
            return nil
        }
    }
    
    /**
     Returns error type for UVError
     */
    public var type: String {
        switch(self) {
        case .UVError(let code):
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
        case .UVError(let code):
            return String(validatingUTF8: uv_strerror(code)) ?? "Unknow Error"
        case .EOF:
            return "EOF"
        case .NoPendingCount:
            return "No pending count"
        case .PendingTypeIsMismatched:
            return "Penging type is mismatched"
        case .ClosedStream:
            return "The stream was alreay closed"
        case .ArgumentError(let message):
            return message
        case .BindRequired:
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
