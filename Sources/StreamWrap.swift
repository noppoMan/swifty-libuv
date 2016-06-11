//
//  StreamWrap.swift
//  SwiftyLibuv
//
//  Created by Yuki Takei on 6/12/16.
//
//

import CLibUv

public enum SocketState {
    case Ready, Connecting, Connected, Closing, Closed
}

/**
 Base wrapper class of Stream and Handle
 */
public class StreamWrap: HandleWrap {
    
    /**
     Initialize with Pointer of the uv_stream_t
     - parameter stream: Pointer of the uv_stream_t
     */
    public init(_ stream: UnsafeMutablePointer<uv_stream_t>){
        super.init(UnsafeMutablePointer<uv_handle_t>(stream))
    }
}

extension StreamWrap {
    
    /**
     Returns true if the pipe is ipc, 0 otherwise.
     */
    public var ipcEnable: Bool {
        return pipePtr.pointee.ipc == 1
    }
    
    /**
     C lang Pointer to the uv_stream_t
     */
    internal var streamPtr: UnsafeMutablePointer<uv_stream_t> {
        return UnsafeMutablePointer<uv_stream_t>(handlePtr)
    }
    
    internal var pipePtr: UnsafeMutablePointer<uv_pipe_t> {
        return UnsafeMutablePointer<uv_pipe_t>(handlePtr)
    }
    
    /**
     Returns true if the stream is writable, 0 otherwise.
     - returns: bool
     */
    public func isWritable() -> Bool {
        if(uv_is_writable(streamPtr) == 1) {
            return true
        }
        
        return false
    }
    
    /**
     Returns true if the stream is readable, 0 otherwise.
     - returns: bool
     */
    public func isReadable() -> Bool {
        if(uv_is_readable(streamPtr) == 1) {
            return true
        }
        
        return false
    }
}

extension StreamWrap {
    /**
     shoutdown connection
     */
    public func shutdown(_ completion: () -> () = { _ in }) {
        if isClosing() { return }
        
        let req = UnsafeMutablePointer<uv_shutdown_t>(allocatingCapacity: sizeof(uv_shutdown_t))
        req.pointee.data =  retainedVoidPointer(completion)
        uv_shutdown(req, streamPtr) { req, status in
            guard let req = req else {
                return
            }
            let completion: () -> () = releaseVoidPointer(req.pointee.data)!
            completion()
            dealloc(req)
        }
    }
    
    public func accept(_ client: StreamWrap, queue: StreamWrap? = nil) throws {
        let stream: StreamWrap
        if let queue = queue {
            stream = queue
        } else {
            stream = self
        }
        
        let result = uv_accept(stream.streamPtr, client.streamPtr)
        if(result < 0) {
            throw Error.UVError(code: result)
        }
    }
}

private func destroy_write_req(_ req: UnsafeMutablePointer<uv_write_t>){
    dealloc(req)
}

extension StreamWrap {
    /**
     Extended write function for sending handles over a pipe
     
     - parameter ipcPipe: Pipe Instance for ipc
     - paramter  data: Buffer to write
     - parameter onWrite: Completion handler(Not implemented yet)
     */
    public func write2(ipcPipe: PipeWrap, onWrite: ((Void) throws -> Void) -> Void = { _ in }){
        let bytes: [Int8] = [97]
        var dummy_buf = uv_buf_init(UnsafeMutablePointer<Int8>(bytes), 1)
        
        withUnsafePointer(&dummy_buf) {
            let writeReq = UnsafeMutablePointer<uv_write_t>(allocatingCapacity: sizeof(uv_write_t))
            let r = uv_write2(writeReq, ipcPipe.streamPtr, $0, 1, self.streamPtr) { req, _ in
                if let req = req {
                    destroy_write_req(req)
                }
            }
            
            if r < 0 {
                destroy_write_req(writeReq)
                onWrite {
                    throw Error.UVError(code: r)
                }
            }
        }
    }
    
    /**
     Write data to stream. Buffers are written in order
     
     - parameter data: Int8 Array bytes to write
     - parameter onWrite: Completion handler
     */
    public func write(bytes data: [Int8], onWrite: ((Void) throws -> Void) -> Void = { _ in }) {
        let bytes = UnsafeMutablePointer<Int8>(data)
        writeBytes(bytes, length: UInt32(data.count), onWrite: onWrite)
    }
    
    /**
     Write data to stream. Buffers are written in order
     
     - parameter data: Buffer to write
     - parameter onWrite: Completion handler
     */
    public func write(buffer data: Buffer, onWrite: ((Void) throws -> Void) -> Void) {
        let bytes = UnsafeMutablePointer<Int8>(data.bytes)
        writeBytes(bytes, length: UInt32(data.bytes.count), onWrite: onWrite)
    }
    
    private func writeBytes(_ bytes: UnsafeMutablePointer<Int8>, length: UInt32, onWrite: ((Void) throws -> Void) -> Void = { _ in }){
        var data = uv_buf_init(bytes, length)
        
        withUnsafePointer(&data) {
            let writeReq = UnsafeMutablePointer<uv_write_t>(allocatingCapacity: sizeof(uv_write_t))
            writeReq.pointee.data = retainedVoidPointer(onWrite)
            
            let r = uv_write(writeReq, streamPtr, $0, 1) { req, _ in
                guard let req = req else {
                    return
                }
                
                let onWrite: ((Void) throws -> Void) -> Void = releaseVoidPointer(req.pointee.data)!
                destroy_write_req(req)
                onWrite {}
            }
            
            if r < 0 {
                destroy_write_req(writeReq)
                onWrite {
                    throw Error.UVError(code: r)
                }
            }
        }
    }
}


extension StreamWrap {
    /**
     Stop reading data from the stream
     */
    public func stop() throws {
        if isClosing() { return }
        
        let r = uv_read_stop(streamPtr)
        if r < 0 {
            throw Error.UVError(code: r)
        }
    }
    
    /**
     Extended read function for reading handles over a pipe
     
     - parameter pendingType: uv_handle_type
     - parameter callback: Completion handler
     */
    public func read2(pendingType: PendingType, callback: ((Void) throws -> PipeWrap) -> Void) {
        
        let onRead: ((Void) throws -> PipeWrap) -> Void = { getQueue in
            callback {
                let queue = try getQueue()
                
                if uv_pipe_pending_count(queue.pipePtr) <= 0 {
                    throw Error.NoPendingCount
                }
                
                if uv_pipe_pending_type(queue.pipePtr) != pendingType.rawValue {
                    throw Error.PendingTypeIsMismatched
                }
                
                return queue
            }
        }
        
        streamPtr.pointee.data = retainedVoidPointer(onRead)
        
        let r = uv_read_start(streamPtr, alloc_buffer) { queue, nread, buf in
            guard let queue = queue, buf = buf else {
                return
            }
            
            defer {
                dealloc(buf.pointee.base, capacity: nread)
            }
            
            let callback: ((Void) throws -> PipeWrap) -> Void = releaseVoidPointer(queue.pointee.data)!
            
            if (nread == Int(UV_EOF.rawValue)) {
                callback {
                    throw Error.ClosedStream
                }
            } else if (nread < 0) {
                callback {
                    throw Error.UVError(code: Int32(nread))
                }
            } else {
                queue.pointee.data = retainedVoidPointer(callback)
                callback {
                    PipeWrap(pipe: UnsafeMutablePointer<uv_pipe_t>(queue))
                }
            }
        }
        
        if r < 0 {
            callback {
                throw Error.UVError(code: r)
            }
        }
    }
    
    /**
     Read data from an incoming stream
     
     - parameter callback: Completion handler
     */
    public func read(_ callback: ((Void) throws -> Buffer) -> Void) {
        streamPtr.pointee.data = retainedVoidPointer(callback)
        
        let r = uv_read_start(streamPtr, alloc_buffer) { stream, nread, buf in
            guard let stream = stream, buf = buf else {
                return
            }
            
            defer {
                dealloc(buf.pointee.base, capacity: nread)
            }
            
            let onRead: ((Void) throws -> Buffer) -> Void = releaseVoidPointer(stream.pointee.data)!
            
            if (nread == Int(UV_EOF.rawValue)) {
                onRead {
                    throw Error.EOF
                }
            } else if (nread < 0) {
                onRead {
                    throw Error.UVError(code: Int32(nread))
                }
            } else {
                stream.pointee.data = retainedVoidPointer(onRead)
                onRead {
                    Buffer(buffer: UnsafePointer<UInt8>(buf.pointee.base), length: nread)
                }
            }
        }
        
        if r < 0 {
            callback {
                throw Error.UVError(code: r)
            }
        }
    }
}
