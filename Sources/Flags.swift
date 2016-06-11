//
//  Flags.swift
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

/**
 Open Flag for FileSystem.open
 
 - R: fopen's r
 - W: fopen's w
 - A: fopen's a
 - RP: fopen's r+
 - WP: fopen's w+
 - AP: fopen's a+
 */
public enum Flags: Int32 {
    case r   // r
    case w   // w
    case a   // a
    case rp  // r+
    case wp  // w+
    case ap  // a+
}


// Refere from node.js's fs.js #stringToFlags
extension Flags {
    /**
     Returns raw value of OR Operated Flags
     */
    public var rawValue: Int32 {
        switch(self) {
        case .r:
            return O_RDONLY
        case .rp:
            return O_RDWR
        case .w:
            return O_TRUNC | O_CREAT | O_WRONLY
        case .wp:
            return O_TRUNC | O_CREAT | O_RDWR
        case .a:
            return O_APPEND | O_CREAT | O_WRONLY
        case .ap:
            return O_APPEND | O_CREAT | O_RDWR
        }
    }
    
    /**
     Default mode that related with flags
     */
    public var mode: Int32 {
        switch(self) {
        case .r:
            return 0
        case .rp:
            return 0
        case .w:
            return 0o666
        case .wp:
            return 0o666
        case .a:
            return 0o666
        case .ap:
            return 0o666
        }
    }
}

