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

public extension Process {
    
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
        #if os(Linux)
            return NSProcessInfo.processInfo().environment
        #else
            return ProcessInfo.processInfo.environment
        #endif
    }
    
    /**
     Returns current working directory
     */
    public static var cwd: String {
        #if os(Linux)
            return NSFileManager.defaultManager().currentDirectoryPath
        #else
            return FileManager.default.currentDirectoryPath
        #endif
    }
    
    /**
     Current execPath including file name
     */
    public static var execPath: String {
        let exepath = UnsafeMutablePointer<Int8>(allocatingCapacity: Int(PATH_MAX))
        defer {
            dealloc(exepath, capacity: Int(PATH_MAX))
        }
        
        var size = Int(PATH_MAX)
        uv_exepath(exepath, &size)
        
        return String(validatingUTF8: exepath)!
    }
}
