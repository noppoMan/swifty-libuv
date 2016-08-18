//
//  Runtime.swift
//  SwiftyLibuv
//
//  Created by Yuki Takei on 6/12/16.
//
//

#if os(Linux)
    import Glibc
#else
    import Darwin.C
#endif

// TODO Need to remove Foundation
import Foundation
import CLibUv

public extension CommandLine {
    
    /**
     Returns current pid
     */
    public static var pid: Int32 {
        return getpid()
    }
    
    /**
     Returns environment variables
     */
    public static var env: [String: String] {
        return ProcessInfo.processInfo.environment
    }
    
    /**
     Returns current working directory
     */
    public static var cwd: String {
        return FileManager.default.currentDirectoryPath
    }
    
    /**
     Current execPath including file name
     */
    public static var execPath: String {
        let exepath = UnsafeMutablePointer<Int8>.allocate(capacity: Int(PATH_MAX))
        defer {
            dealloc(exepath, capacity: Int(PATH_MAX))
        }
        
        var size = Int(PATH_MAX)
        uv_exepath(exepath, &size)
        
        return String(validatingUTF8: exepath)!
    }
}
