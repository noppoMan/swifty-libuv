//
//  FSWrap.swift
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

import CLibUv

private struct FSContext {
    var onOpen: ((Void) throws -> Int32) -> Void = {_ in}
}


/**
 The Base of File System Operation class that has Posix Like interface
 */
public class FSWrap {
    /**
     Equivalent to unlink(2).
     
     - Throws:
     Error.uvError
     */
    public static func unlink(_ path: String, loop: Loop = Loop.defaultLoop) throws {
        let req = UnsafeMutablePointer<uv_fs_t>(allocatingCapacity: sizeof(uv_fs_t.self))
        let r = uv_fs_unlink(loop.loopPtr, req, path, nil)
        fs_req_cleanup(req)
        if r < 0 {
            throw Error.uvError(code: r)
        }
    }
    
    /**
     Returns the current value of the position indicator of the stream.
     
     - parameter fd: The file descriptor
     - parameter loop: Event Loop
     - parameter length: Not implemented yet
     - parameter position: Not implemented yet
     - parameter completion: Completion handler
     */
    public static func read(_ fd: Int32, loop: Loop = Loop.defaultLoop, length: Int? = nil, position: Int = 0, completion: ((Void) throws -> Buffer) -> Void){
        let reader = FileReader(
            loop: loop,
            fd: fd,
            length: length,
            position: position
        ) { res in
            switch(res) {
            case .error(let e):
                completion {
                    throw e
                }
            case .data(let buf):
                completion {
                    return buf
                }
            case .end(let pos):
                if pos == 0 {
                    completion {
                        []
                    }
                }
            }
        }
        reader.start()
    }
    
    /**
     Returns the current value of the position indicator of the stream.
     
     - parameter fd: The file descriptor
     - parameter loop: Event Loop
     - parameter data: buffer to write
     - parameter offset: Not implemented yet
     - parameter length: Not implemented yet
     - parameter position: Position to start writing
     - parameter completion: Completion handler
     */
    public static func write(_ fd: Int32, loop: Loop = Loop.defaultLoop, data: Buffer, offset: Int = 0, length: Int? = nil, position: Int = 0, completion: ((Void) throws -> Void) ->  Void){
        let writer = FileWriter(
            loop: loop,
            fd: fd,
            data: data,
            offset: offset,
            length: length,
            position: position
        ) { result in
            completion {
                _ = try result()
            }
        }
        writer.start()
    }
    
    /**
     Equivalent to open(2).
     
     - parameter flag: flag for uv_fs_open
     - parameter loop: Event Loop
     - parameter mode: mode for uv_fs_open
     - parameter completion: Completion handler
     */
    public static func open(_ path: String, loop: Loop = Loop.defaultLoop, flags: Flags = .r, mode: Int32? = nil, completion: ((Void) throws -> Int32) -> Void) {
        
        let context = FSContext(onOpen: completion)
        
        var req = UnsafeMutablePointer<uv_fs_t>(allocatingCapacity: sizeof(uv_fs_t.self))
        req.pointee.data = retainedVoidPointer(context)
        
        let r = uv_fs_open(loop.loopPtr, req, path, flags.rawValue, mode != nil ? mode! : flags.mode) { req in
            guard let req = req else {
                return
            }
            
            let ctx: FSContext = releaseVoidPointer(req.pointee.data)!
            defer {
                fs_req_cleanup(req)
            }
            
            if(req.pointee.result < 0) {
                return ctx.onOpen {
                    throw Error.uvError(code: Int32(req.pointee.result))
                }
            }
            
            ctx.onOpen {
                Int32(req.pointee.result)
            }
        }
        
        if r < 0 {
            fs_req_cleanup(req)
            completion {
                throw Error.uvError(code: r)
            }
        }
    }
    
    /**
     Take file stat
     
     - parameter completion: Completion handler
     - parameter loop: Event Loop
     */
    public static func stat(_ path: String, loop: Loop = Loop.defaultLoop, completion: ((Void) throws -> Void) -> Void) {
        _ = FileStatWrap(loop: loop, path: path, completion: completion)
    }
    
    /**
     Equivalent to close(2).
     
     - parameter fd: The file descriptor
     - parameter loop: Event Loop
     - parameter completion: Completion handler
     */
    public static func close(_ fd: Int32, loop: Loop = Loop.defaultLoop, completion: ((Void) throws -> Void) -> Void = { _ in }){
        let req = UnsafeMutablePointer<uv_fs_t>(allocatingCapacity: sizeof(uv_fs_t.self))
        uv_fs_close(loop.loopPtr, req, uv_file(fd), nil)
        fs_req_cleanup(req)
    }
}
