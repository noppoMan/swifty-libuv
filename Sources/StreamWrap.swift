//
//  StreamWrap.swift
//  SwiftyLibuv
//
//  Created by Yuki Takei on 6/12/16.
//
//

import CLibUv
import Foundation

/**
 Base wrapper class of Stream and Handle
 */
public class StreamWrap: HandleWrap {
    
    fileprivate var onRead: (Result<Data>) -> Void = { _ in }
    
    fileprivate var onRead2: (Result<PipeWrap>) -> Void = { _ in }
    
    fileprivate var onWrite: (Result<Void>) -> Void = { _ in }
    
    /**
     Initialize with Pointer of the uv_stream_t
     - parameter stream: Pointer of the uv_stream_t
     */
    public init(_ stream: UnsafeMutablePointer<uv_stream_t>){
        super.init(stream.cast(to: UnsafeMutablePointer<uv_handle_t>.self))
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
        return handlePtr.cast(to: UnsafeMutablePointer<uv_stream_t>.self)
    }
    
    internal var pipePtr: UnsafeMutablePointer<uv_pipe_t> {
        return handlePtr.cast(to: UnsafeMutablePointer<uv_pipe_t>.self)
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
        
        let req = UnsafeMutablePointer<uv_shutdown_t>.allocate(capacity: MemoryLayout<uv_shutdown_t>.size)
        req.pointee.data =  retainedVoidPointer(completion)
        uv_shutdown(req, streamPtr) { req, status in
            guard let req = req else {
                return
            }
            let completion: () -> () = releaseVoidPointer(req.pointee.data)
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
            throw UVError.rawUvError(code: result)
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
    public func write2(ipcPipe: PipeWrap, completion: @escaping (Result<Void>) -> Void = { _ in }){
        var dummy_buf = uv_buf_init(UnsafeMutablePointer<Int8>(mutating: [97]), 1)
        
        withUnsafePointer(to: &dummy_buf) {
            let writeReq = UnsafeMutablePointer<uv_write_t>.allocate(capacity: MemoryLayout<uv_write_t>.size)
            let r = uv_write2(writeReq, ipcPipe.streamPtr, $0, 1, self.streamPtr) { req, _ in
                if let req = req {
                    destroy_write_req(req)
                }
            }
            
            if r < 0 {
                destroy_write_req(writeReq)
                completion(.failure(UVError.rawUvError(code: r)))
            }
        }
    }
    
    /**
     Write data to stream. Buffers are written in order
     
     - parameter data: Buffer to write
     - parameter onWrite: Completion handler
     */
    public func write(_ data: Data, completion: @escaping (Result<Void>) -> Void = { _ in }) {
        let bytePtr = data.withUnsafeBytes { (bytes: UnsafePointer<Int8>) in
            UnsafeMutablePointer(mutating: UnsafeRawPointer(bytes).assumingMemoryBound(to: Int8.self))
        }
        write(bytePtr, length: UInt32(data.count), completion: completion)
    }
    
    public func write(_ bytes: UnsafeMutablePointer<Int8>, length: UInt32, completion: @escaping (Result<Void>) -> Void = { _ in }){
        var data = uv_buf_init(bytes, length)
        
        self.onWrite = completion
        
        withUnsafePointer(to: &data) {
            let writeReq = UnsafeMutablePointer<uv_write_t>.allocate(capacity: MemoryLayout<uv_write_t>.size)
            writeReq.pointee.data = Unmanaged.passUnretained(self).toOpaque()
            
            let r = uv_write(writeReq, streamPtr, $0, 1) { req, _ in
                let stream: StreamWrap = Unmanaged.fromOpaque(req!.pointee.data).takeUnretainedValue()
                destroy_write_req(req!)
                stream.onWrite(.success())
            }
            
            if r < 0 {
                destroy_write_req(writeReq)
                onWrite(.failure(UVError.rawUvError(code: r)))
            }
        }
    }
}


extension StreamWrap {
    /**
     Extended read function for reading handles over a pipe
     
     - parameter pendingType: uv_handle_type
     - parameter callback: Completion handler
     */
    public func read2(pendingType: PendingType, completion: @escaping (Result<PipeWrap>) -> Void) {
        self.onRead2 = { result in
            switch result {
            case .failure(let error):
                completion(.failure(error))
            case .success(let queue):
                if uv_pipe_pending_count(queue.pipePtr) <= 0 {
                    return completion(.failure(StreamWrapError.noPendingCount))
                }

                if uv_pipe_pending_type(queue.pipePtr) != pendingType.rawValue {
                    return completion(.failure(StreamWrapError.pendingTypeIsMismatched))
                }
                
                completion(.success(queue))
            }
        }
        
        streamPtr.pointee.data = Unmanaged.passUnretained(self).toOpaque()
        
        let r = uv_read_start(streamPtr, alloc_buffer) { queue, nread, buf in
            defer {
                dealloc(buf!.pointee.base, capacity: nread)
            }
            
            let stream: StreamWrap = Unmanaged.fromOpaque(queue!.pointee.data).takeUnretainedValue()
            
            if (nread == Int(UV_EOF.rawValue)) {
                stream.onRead2(.failure(StreamWrapError.eof))
            } else if (nread < 0) {
                stream.onRead2(.failure(UVError.rawUvError(code: Int32(nread))))
            } else {
                let queue = PipeWrap(pipe: queue!.cast(to: UnsafeMutablePointer<uv_pipe_t>.self))
                stream.onRead2(.success(queue))
            }
        }
        
        if r < 0 {
            completion(.failure(UVError.rawUvError(code: r)))
        }
    }
    
    /**
     Read data from an incoming stream
     
     - parameter callback: Completion handler
     */
    public func read(_ completion: @escaping (Result<Data>) -> Void) {
        self.onRead = completion
        streamPtr.pointee.data = Unmanaged.passUnretained(self).toOpaque()
        
        let r = uv_read_start(streamPtr, alloc_buffer) { streamPtr, nread, buf in
            defer {
                dealloc(buf!.pointee.base, capacity: nread)
            }
            
            let stream: StreamWrap = Unmanaged.fromOpaque(streamPtr!.pointee.data).takeUnretainedValue()
            
            if (nread == Int(UV_EOF.rawValue)) {
                stream.onRead(.failure(StreamWrapError.eof))
            } else if (nread < 0) {
                stream.onRead(.failure(UVError.rawUvError(code: Int32(nread))))
            } else {
                stream.onRead(.success(Data(bytes: buf!.pointee.base, count: nread)))
            }
        }
        
        if r < 0 {
            onRead(.failure(UVError.rawUvError(code: r)))
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
            throw UVError.rawUvError(code: r)
        }
    }
}
