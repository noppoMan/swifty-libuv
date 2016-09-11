//
//  FileReader.swift
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

private class FileReaderContext {
    var onRead: ((Void) throws -> Buffer) -> Void = { _ in }
    
    var bytesRead: Int64 = 0
    
    var buf: uv_buf_t? = nil
    
    let loop: Loop
    
    var fd: Int32
    
    /**
     an integer specifying the number of bytes to read
     */
    var length: Int?
    
    /**
     an integer specifying where to begi1n reading from in the file.
     If position is null, data will be read from the current file position
     */
    var position: Int
    
    init(loop: Loop = Loop.defaultLoop, fd: Int32, length: Int? = nil, position: Int, completion: @escaping ((Void) throws -> Buffer) -> Void){
        self.loop = loop
        self.fd = fd
        self.position = position
        self.length = length
        self.onRead = completion
    }
}

public class FileReader {
    
    // TODO should be variable depends on resource availability
    public static var upTo = 1024
    
    private let context: FileReaderContext
    
    public init(loop: Loop = Loop.defaultLoop, fd: Int32, offset: Int = 0, length: Int? = nil, position: Int, completion: @escaping ((Void) throws -> Buffer) -> Void){
        context = FileReaderContext(
            loop: loop,
            fd: fd,
            length: length,
            position: position,
            completion: completion
        )
        
    }
    
    public func start(){
        readNext(context)
    }
}


private func readNext(_ context: FileReaderContext){
    let readReq = UnsafeMutablePointer<uv_fs_t>.allocate(capacity: MemoryLayout<uv_fs_t>.size)
    context.buf = uv_buf_init(UnsafeMutablePointer<Int8>.allocate(capacity: FileReader.upTo), UInt32(FileReader.upTo))
    
    readReq.pointee.data = retainedVoidPointer(context)
    let r = uv_fs_read(context.loop.loopPtr, readReq, uv_file(context.fd), &context.buf!, 1, -1, onReadEach)
    
    
    if r < 0 {
        fs_req_cleanup(readReq)
        context.onRead {
            throw UVError.rawUvError(code: r)
        }
    }
}

private func onReadEach(_ req: UnsafeMutablePointer<uv_fs_t>?) {
    guard let req = req else {
        return
    }
    
    defer {
        fs_req_cleanup(req)
    }
    
    let context: FileReaderContext = releaseVoidPointer(req.pointee.data)
    
    if(req.pointee.result < 0) {
        return context.onRead {
            throw UVError.rawUvError(code: Int32(req.pointee.result))
        }
    }
    
    var buf = Buffer()
    for i in stride(from: 0, to: req.pointee.result, by: 1) {
        buf.append(context.buf!.base[i])
    }
    
    context.bytesRead += req.pointee.result
    
    context.onRead {
        buf
    }
    
    if req.pointee.result < FileReader.upTo {
        return
    }
    
    readNext(context)
}
