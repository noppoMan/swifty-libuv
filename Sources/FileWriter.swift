//
//  FileWriter.swift
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

private class FileWriterContext {
    var writeReq: UnsafeMutablePointer<uv_fs_t>? = nil
    
    var onWrite: ((Void) throws -> Int) -> Void = {_ in }
    
    var bytesWritten: Int64 = 0
    
    var data: Buffer
    
    var buf: uv_buf_t? = nil
    
    let loop: Loop
    
    let fd: Int32
    
    let offset: Int  // Not implemented yet
    
    var length: Int? // Not implemented yet
    
    var position: Int
    
    var curPos: Int {
        return position + Int(bytesWritten)
    }
    
    init(loop: Loop = Loop.defaultLoop, fd: Int32, data: Buffer, offset: Int, length: Int? = nil, position: Int, completion: ((Void) throws -> Int) -> Void){
        self.loop = loop
        self.fd = fd
        self.data = data
        self.offset = offset
        self.length = length
        self.position = position
        self.onWrite = completion
    }
}

public class FileWriter {
    
    private var context: FileWriterContext
    
    public init(loop: Loop = Loop.defaultLoop, fd: Int32, data: Buffer, offset: Int, length: Int? = nil, position: Int, completion: ((Void) throws -> Int) -> Void){
        context = FileWriterContext(
            loop: loop,
            fd: fd,
            data: data,
            offset: offset,
            length: length,
            position: position,
            completion: completion
        )
    }
    
    public func start(){
        if(context.data.bytes.count <= 0) {
            return context.onWrite { [unowned self] in
                0+self.context.offset
            }
        }
        attemptWrite(context)
    }
}

private func attemptWrite(_ context: FileWriterContext){
    var writeReq = UnsafeMutablePointer<uv_fs_t>(allocatingCapacity: sizeof(uv_fs_t.self))
    
    var bytes = context.data.bytes.map { Int8(bitPattern: $0) }
    context.buf = uv_buf_init(&bytes, UInt32(context.data.bytes.count))
    
    withUnsafePointer(&context.buf!) {
        writeReq.pointee.data = retainedVoidPointer(context)
        
        let r = uv_fs_write(context.loop.loopPtr, writeReq, uv_file(context.fd), $0, UInt32(context.buf!.len), Int64(context.curPos)) { req in
            if let req = req {
                onWriteEach(req)
            }
        }
        
        if r < 0 {
            defer {
                fs_req_cleanup(writeReq)
            }
            context.onWrite {
                throw Error.uvError(code: r)
            }
            return
        }
    }
}

private func onWriteEach(_ req: UnsafeMutablePointer<uv_fs_t>){
    defer {
        fs_req_cleanup(req)
    }
    
    let context: FileWriterContext = releaseVoidPointer(req.pointee.data)!
    
    if(req.pointee.result < 0) {
        return context.onWrite {
            throw Error.uvError(code: Int32(req.pointee.result))
        }
    }
    
    if(req.pointee.result == 0) {
        return context.onWrite {
            context.curPos
        }
    }
    
    context.bytesWritten += req.pointee.result
    
    if Int(context.bytesWritten) >= Int(context.data.bytes.count) {
        return context.onWrite {
            context.curPos
        }
    }
    
    attemptWrite(context)
}
