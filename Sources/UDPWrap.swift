//
//  UDPWrap.swift
//  SwiftyLibuv
//
//  Created by Yuki Takei on 6/12/16.
//
//

import Foundation
import CLibUv

public enum UVUdpFlags: UInt32 {
    case none = 0
    case ipv6Only = 1
    case partial = 2
    case reuseaddr = 4
}

public enum UVMembership {
    case leaveGroup
    case joinGroup
}

extension UVMembership {
    public var rawValue: uv_membership {
        switch self {
        case .joinGroup:
            return UV_JOIN_GROUP
        default:
            return UV_LEAVE_GROUP
        }
    }
}

public class UDPWrap: HandleWrap {
    
    private var socket: UnsafeMutablePointer<uv_udp_t>
    
    private var onRecv: (Result<(Data, Address)>) -> Void = { _ in }
    
    private var onSend: (Result<Void>) -> Void = { _ in }
    
    public init(loop: Loop = Loop.defaultLoop) {
        self.socket = UnsafeMutablePointer<uv_udp_t>.allocate(capacity: MemoryLayout<uv_udp_t>.size)
        uv_udp_init(loop.loopPtr, socket)
        super.init(self.socket.cast(to: UnsafeMutablePointer<uv_handle_t>.self))
    }
    
    public func bind(_ addr: Address, flags: UVUdpFlags = .none) throws {
        let r = uv_udp_bind(socket, addr.address, flags.rawValue)
        if r < 0 {
            throw UVError.rawUvError(code: r)
        }
    }
    
    public func setBroadcast(_ on: Bool) throws {
        let r = uv_udp_set_broadcast(socket, on ? 1: 0)
        if r < 0 {
            throw UVError.rawUvError(code: r)
        }
    }
    
    public func setTTL(ttl: Int){
        uv_udp_set_ttl(socket, Int32(ttl))
    }
    
    public func setMulticastInterface(interfaceAddr: String) {
        uv_udp_set_multicast_interface(socket, interfaceAddr.withCString{$0})
    }
    
    public func setMulticastTTL (ttl: Int){
        uv_udp_set_multicast_ttl(socket, Int32(ttl))
    }
    
    public func setMembership(multicastAddr: String, interfaceAddr: String, membership: UVMembership = .joinGroup){
        uv_udp_set_membership(socket, multicastAddr.withCString{$0}, interfaceAddr.withCString{$0}, membership.rawValue)
    }
    
    public func send(buffer data: Data, addr: Address, completion: @escaping (Result<Void>) -> Void =  { _ in }) {
        let bytePtr = data.withUnsafeBytes { (bytes: UnsafePointer<Int8>) in
            UnsafeMutablePointer(mutating: UnsafeRawPointer(bytes).assumingMemoryBound(to: Int8.self))
        }
        send(bytePtr, length: UInt32(data.count), addr: addr, completion: completion)
    }
    
    public func send(_ bytes: UnsafeMutablePointer<Int8>, length: UInt32, addr: Address, completion: @escaping (Result<Void>) -> Void) {
        self.onSend = completion
        let req = UnsafeMutablePointer<uv_udp_send_t>.allocate(capacity: MemoryLayout<uv_udp_send_t>.size)
        req.pointee.data = Unmanaged.passUnretained(self).toOpaque()
        var data = uv_buf_init(bytes, length)
        
        let r = uv_udp_send(req, socket, &data, 1, addr.address) { req, status in
            let stream: UDPWrap = Unmanaged.fromOpaque(req!.pointee.data).takeUnretainedValue()
            if status > 0 {
                stream.onSend(.failure(UVError.rawUvError(code: status)))
                return
            }
            stream.onSend(.success())
        }
        
        if r < 0 {
            completion(.failure(UVError.rawUvError(code: r)))
        }
    }
    
    public func recv(completion: @escaping (Result<(Data, Address)>) -> Void) {
        self.onRecv = completion
        socket.pointee.data = Unmanaged.passUnretained(self).toOpaque()
        
        let r = uv_udp_recv_start(socket, alloc_buffer) { req, nread, buf, sockaddr, flags in
            guard let req = req, let buf = buf, let sockaddr = sockaddr else {
                return
            }
            
            defer {
                dealloc(buf.pointee.base, capacity: nread)
            }
            
            let stream: UDPWrap = Unmanaged.fromOpaque(req.pointee.data).takeUnretainedValue()
            
            if (nread == Int(UV_EOF.rawValue)) {
                stream.onRecv(.failure(StreamWrapError.eof))
            } else if (nread < 0) {
                stream.onRecv(.failure(UVError.rawUvError(code: Int32(nread))))
            } else {
                // Get DHCP info
                var sender = [Int8](repeating: 0, count: 17)
                let addrin = unsafeBitCast(sockaddr, to: UnsafePointer<sockaddr_in>.self)
                uv_ip4_name(addrin, &sender, 16)
                #if os(Linux)
                    let port = Int(ntohs(addrin.pointee.sin_port))
                #else
                    let port = Int(NSSwapBigShortToHost(addrin.pointee.sin_port))
                #endif
                
                let addr = Address(host: String(validatingUTF8: sender)!, port: port)
                stream.onRecv(.success((Data(bytes: buf.pointee.base, count: nread), addr)))
            }
        }
        
        if r < 0 {
            completion(.failure(UVError.rawUvError(code: r)))
        }
    }
    
    public func stop() throws {
        if isClosing() { return }
        
        let r = uv_udp_recv_stop(socket)
        if r < 0 {
            throw UVError.rawUvError(code: r)
        }
    }
    
}
