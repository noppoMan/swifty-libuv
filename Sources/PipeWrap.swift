//
//  PipeWrap.swift
//  SwiftyLibuv
//
//  Created by Yuki Takei on 6/12/16.
//
//

import CLibUv

/**
 Pipe handle type
 */
public class PipeWrap: StreamWrap {
    
    private var onConnection: (Result<Void>) -> Void = { _ in }
    
    private var onConnect: (Result<Void>) -> Void = { _ in }
    
    public init(pipe: UnsafeMutablePointer<uv_pipe_t>){
        super.init(pipe.cast(to: UnsafeMutablePointer<uv_stream_t>.self))
    }
    
    public init(loop: Loop = Loop.defaultLoop, ipcEnable: Bool = false){
        let pipe = UnsafeMutablePointer<uv_pipe_t>.allocate(capacity: MemoryLayout<uv_pipe_t>.size)
        uv_pipe_init(loop.loopPtr, pipe, ipcEnable ? 1 : 0)
        super.init(pipe.cast(to: UnsafeMutablePointer<uv_stream_t>.self))
    }
    
    /**
     Open an existing file descriptor or HANDLE as a pipe
     
     - parameter stdio: Number of fd to open (Int32)
     */
    public func open(_ stdio: Int) -> Self {
        uv_pipe_open(pipePtr, Int32(stdio))
        return self
    }
    
    public func bind(_ sockName: String) throws {
        let r = uv_pipe_bind(pipePtr, sockName)
        
        if r < 0 {
            throw UVError.rawUvError(code: r)
        }
    }
    
    public func listen(_ backlog: UInt = 128, completion: @escaping (Result<Void>) -> Void) throws {
        self.onConnection = completion
        streamPtr.pointee.data = Unmanaged.passUnretained(self).toOpaque()
        
        let result = uv_listen(streamPtr, Int32(backlog)) { streamPtr, status in
            let stream: PipeWrap = Unmanaged.fromOpaque(streamPtr!.pointee.data).takeUnretainedValue()
            guard status >= 0 else {
                stream.onConnection(.failure(UVError.rawUvError(code: status)))
                return
            }
            stream.onConnection(.success())
        }
        
        if result < 0 {
            onConnection(.failure(UVError.rawUvError(code: result)))
        }
    }
    
    /**
     Connect to the Unix domain socket or the named pipe.
     
     - parameter sockName: Socket name to connect
     - parameter onConnect: Will be called when the connection is succeeded or failed
     */
    public func connect(_ sockName: String, completion: @escaping (Result<Void>) -> Void){
        self.onConnect = completion
        
        let req = UnsafeMutablePointer<uv_connect_t>.allocate(capacity: MemoryLayout<uv_connect_t>.size)
        req.pointee.data = Unmanaged.passUnretained(self).toOpaque()
        
        uv_pipe_connect(req, pipePtr, sockName) { req, status in
            let stream: PipeWrap = Unmanaged.fromOpaque(req!.pointee.data).takeUnretainedValue()
            if status < 0 {
                stream.onConnect(.failure(UVError.rawUvError(code: status)))
            }
            stream.onConnect(.success())
        }
    }
}
