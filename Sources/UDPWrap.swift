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
    
    public enum UDPWrapError: Error {
        case eof
    }
    
    private var socket: UnsafeMutablePointer<uv_udp_t>
    
    public init(loop: Loop = Loop.defaultLoop) {
        self.socket = UnsafeMutablePointer<uv_udp_t>.allocate(capacity: MemoryLayout<uv_udp_t>.size)
        uv_udp_init(loop.loopPtr, socket)
        super.init(self.socket.cast(to: UnsafeMutablePointer<uv_handle_t>.self))
    }
    
    public func bind(_ addr: Address, flags: UVUdpFlags = .none) throws {
        let r = uv_udp_bind(socket, addr.address, flags.rawValue)
        if r < 0 {
            throw SwiftyLibUvError.uvError(code: r)
        }
    }
    
    public func setBroadcast(_ on: Bool) throws {
        let r = uv_udp_set_broadcast(socket, on ? 1: 0)
        if r < 0 {
            throw SwiftyLibUvError.uvError(code: r)
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
    
    public func send(bytes data: [Int8], addr: Address, onSend: ((Void) throws -> Void) -> Void = { _ in }) {
        let bytes = UnsafeMutablePointer<Int8>(mutating: data)
        sendBytes(bytes, length: UInt32(data.count), addr: addr, onSend: onSend)
    }
    
    public func send(buffer data: Buffer, addr: Address, onSend: ((Void) throws -> Void) -> Void =  { _ in }) {
        let bytes = UnsafeMutablePointer<Int8>(mutating: data.bytes.map({Int8(bitPattern: $0)}))
        sendBytes(bytes, length: UInt32(data.bytes.count), addr: addr, onSend: onSend)
    }
    
    private func sendBytes(_ bytes: UnsafeMutablePointer<Int8>, length: UInt32, addr: Address, onSend: ((Void) throws -> Void) -> Void = {
        _ in }) {
        
        let req = UnsafeMutablePointer<uv_udp_send_t>.allocate(capacity: MemoryLayout<uv_udp_send_t>.size)
        req.pointee.data = retainedVoidPointer(onSend)
        var data = uv_buf_init(bytes, length)
        
        let r = uv_udp_send(req, socket, &data, 1, addr.address) { req, status in
            let onSend: ((Void) throws -> Void) -> Void = releaseVoidPointer(req!.pointee.data)
            onSend {
                if status > 0 {
                    throw SwiftyLibUvError.uvError(code: status)
                }
            }
        }
        
        if r < 0 {
            onSend {
                throw SwiftyLibUvError.uvError(code: r)
            }
        }
    }
    
    public func recv(onRecv: ((Void) throws -> (Buffer, Address)) -> Void) {
        socket.pointee.data = retainedVoidPointer(onRecv)
        
        let r = uv_udp_recv_start(socket, alloc_buffer) { req, nread, buf, sockaddr, flags in
            guard let req = req, let buf = buf, let sockaddr = sockaddr else {
                return
            }
            
            defer {
                dealloc(buf.pointee.base, capacity: nread)
            }
            
            let onRecv: ((Void) throws -> (Buffer, Address)) -> Void = releaseVoidPointer(req.pointee.data)
            
            if (nread == Int(UV_EOF.rawValue)) {
                onRecv {
                    throw UDPWrapError.eof
                }
            } else if (nread < 0) {
                onRecv {
                    throw SwiftyLibUvError.uvError(code: Int32(nread))
                }
            } else {
                req.pointee.data = retainedVoidPointer(onRecv)
                
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
                
                let buf = Buffer(buffer: buf.pointee.base.cast(to: UnsafePointer<UInt8>.self), length: nread)
                onRecv {
                    (buf, addr)
                }
            }
        }
        
        if r < 0 {
            onRecv {
                throw SwiftyLibUvError.uvError(code: r)
            }
        }
    }
    
    public func stop() throws {
        if isClosing() { return }
        
        let r = uv_udp_recv_stop(socket)
        if r < 0 {
            throw SwiftyLibUvError.uvError(code: r)
        }
    }
    
}
