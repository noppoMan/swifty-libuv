//
//  TCPWrap.swift
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

/**
 Stream handle type for TCP reading/writing
 */
public class TCPWrap: StreamWrap {
    
    private let socket: UnsafeMutablePointer<uv_tcp_t>
    
    public private(set) var keepAlived = false
    
    public private(set) var noDelayed = false
    
    /**
     - parameter loop: event loop. Default is Loop.defaultLoop
     */
    public init(loop: Loop = Loop.defaultLoop){
        self.socket = UnsafeMutablePointer<uv_tcp_t>.allocate(capacity: 1)
        uv_tcp_init(loop.loopPtr, socket)
        super.init(socket.cast(to: UnsafeMutablePointer<uv_stream_t>.self))
    }
    
    /**
     - parameter socket: Initialized uv_tcp_t pointer
     */
    public init(socket: UnsafeMutablePointer<uv_tcp_t>){
        self.socket = socket
        super.init(self.socket.cast(to: UnsafeMutablePointer<uv_stream_t>.self))
    }
    
    /**
     Enable / disable Nagle’s algorithm.
     */
    public func setNoDelay(_ enable: Bool) throws {
        let r = uv_tcp_nodelay(socket, enable ? 1: 0)
        if r < 0 {
            throw UVError.rawUvError(code: r)
        }
        
        noDelayed = enable
    }
    
    /**
     Enable / disable TCP keep-alive
     
     - parameter enable: if ture enable tcp keepalive, false disable it
     - parameter delay: the initial delay in seconds, ignored when disable.
     */
    public func setKeepAlive(_ enable: Bool, delay: UInt) throws {
        let r = uv_tcp_keepalive(socket, enable ? 1: 0, UInt32(delay))
        if r < 0 {
            throw UVError.rawUvError(code: r)
        }
        
        keepAlived = enable
    }
    
    
    public func bind(_ addr: Address) throws {
        let r = uv_tcp_bind(self.streamPtr.cast(to: UnsafeMutablePointer<uv_tcp_t>.self), addr.address, 0)
        if r < 0 {
            throw UVError.rawUvError(code: r)
        }
    }
    
    public func listen(_ backlog: UInt = 128, onConnection: ((Void) throws -> Void) -> Void) throws -> () {
        streamPtr.pointee.data = retainedVoidPointer(onConnection)
        
        let result = uv_listen(streamPtr, Int32(backlog)) { stream, status in
            guard let stream = stream else {
                return
            }
            
            let onConnection: ((Void) throws -> Void) -> Void = releaseVoidPointer(stream.pointee.data)
            stream.pointee.data = retainedVoidPointer(onConnection)
            guard status >= 0 else {
                onConnection {
                    throw UVError.rawUvError(code: status)
                }
                return
            }
            
            onConnection {}
        }
        
        if result < 0 {
            throw UVError.rawUvError(code: result)
        }
    }
    
    /**
     - parameter addr: Address to bind
     - parameter completion: Completion handler
     */
    public func connect(_ addr: Address, completion: ((Void) throws -> Void) -> Void) {
        let con = UnsafeMutablePointer<uv_connect_t>.allocate(capacity: MemoryLayout<uv_connect_t>.size)
        con.pointee.data = retainedVoidPointer(completion)
        
        let r = uv_tcp_connect(con, self.socket, addr.address) { connection, status in
            guard let connection = connection else {
                return
            }
            
            defer {
                dealloc(connection)
            }
            
            let calllback: ((Void) throws -> Void) -> Void = releaseVoidPointer(connection.pointee.data)
            
            if status < 0 {
                calllback {
                    throw UVError.rawUvError(code: status)
                }
            }
            
            calllback {}
        }
        
        if r < 0 {
            completion {
                throw UVError.rawUvError(code: r)
            }
        }
    }
}
