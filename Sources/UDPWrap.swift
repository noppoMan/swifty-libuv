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
    case None = 0
    case UDP_IPV6ONLY = 1
    case UDP_PARTIAL = 2
    case UDP_REUSEADDR = 4
}

public enum UVMembership {
    case LEAVE_GROUP
    case JOIN_GROUP
}

extension UVMembership {
    public var rawValue: uv_membership {
        switch self {
        case .JOIN_GROUP:
            return UV_JOIN_GROUP
        default:
            return UV_LEAVE_GROUP
        }
    }
}

public class UDPWrap: HandleWrap {
    private var socket: UnsafeMutablePointer<uv_udp_t>
    
    public init(loop: Loop = Loop.defaultLoop) {
        self.socket = UnsafeMutablePointer<uv_udp_t>(allocatingCapacity: sizeof(uv_udp_t))
        uv_udp_init(loop.loopPtr, socket)
        super.init(UnsafeMutablePointer<uv_handle_t>(socket))
    }
    
    public func bind(_ addr: Address, flags: UVUdpFlags = .None) throws {
        let r = uv_udp_bind(socket, addr.address, flags.rawValue)
        if r < 0 {
            throw Error.UVError(code: r)
        }
    }
    
    public func setBroadcast(_ on: Bool) throws {
        let r = uv_udp_set_broadcast(socket, on ? 1: 0)
        if r < 0 {
            throw Error.UVError(code: r)
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
    
    public func setMembership(multicastAddr: String, interfaceAddr: String, membership: UVMembership = .JOIN_GROUP){
        uv_udp_set_membership(socket, multicastAddr.withCString{$0}, interfaceAddr.withCString{$0}, membership.rawValue)
    }
    
    public func send(bytes data: [Int8], addr: Address, onSend: ((Void) throws -> Void) -> Void = { _ in }) {
        let bytes = UnsafeMutablePointer<Int8>(data)
        sendBytes(bytes, length: UInt32(data.count), addr: addr, onSend: onSend)
    }
    
    public func send(buffer data: Buffer, addr: Address, onSend: ((Void) throws -> Void) -> Void =  { _ in }) {
        let bytes = UnsafeMutablePointer<Int8>(data.bytes)
        sendBytes(bytes, length: UInt32(data.bytes.count), addr: addr, onSend: onSend)
    }
    
    private func sendBytes(_ bytes: UnsafeMutablePointer<Int8>, length: UInt32, addr: Address, onSend: ((Void) throws -> Void) -> Void = {
        _ in }) {
        
        let req = UnsafeMutablePointer<uv_udp_send_t>(allocatingCapacity: sizeof(uv_udp_send_t))
        req.pointee.data = retainedVoidPointer(onSend)
        var data = uv_buf_init(bytes, length)
        
        let r = uv_udp_send(req, socket, &data, 1, addr.address) { req, status in
            let onSend: ((Void) throws -> Void) -> Void = releaseVoidPointer(req?.pointee.data)!
            onSend {
                if status > 0 {
                    throw Error.UVError(code: status)
                }
            }
        }
        
        if r < 0 {
            onSend {
                throw Error.UVError(code: r)
            }
        }
    }
    
    public func recv(onRecv: ((Void) throws -> (Buffer, Address)) -> Void) {
        socket.pointee.data = retainedVoidPointer(onRecv)
        
        let r = uv_udp_recv_start(socket, alloc_buffer) { req, nread, buf, sockaddr, flags in
            guard let req = req, buf = buf, sockaddr = sockaddr else {
                return
            }
            
            defer {
                dealloc(buf.pointee.base, capacity: nread)
            }
            
            let onRecv: ((Void) throws -> (Buffer, Address)) -> Void = releaseVoidPointer(req.pointee.data)!
            
            if (nread == Int(UV_EOF.rawValue)) {
                onRecv {
                    throw Error.EOF
                }
            } else if (nread < 0) {
                onRecv {
                    throw Error.UVError(code: Int32(nread))
                }
            } else {
                req.pointee.data = retainedVoidPointer(onRecv)
                
                // Get DHCP info
                var sender = [Int8](repeating: 0, count: 17)
                let addrin = UnsafePointer<sockaddr_in>(sockaddr)
                uv_ip4_name(addrin, &sender, 16)
                
                let addr = Address(host: String(validatingUTF8: sender)!, port:
                    Int(NSSwapBigShortToHost(addrin.pointee.sin_port)))
                let buf = Buffer(buffer: UnsafePointer<UInt8>(buf.pointee.base), length: nread)
                onRecv {
                    (buf, addr)
                }
            }
        }
        
        if r < 0 {
            onRecv {
                throw Error.UVError(code: r)
            }
        }
    }
    
    public func stop() throws {
        if isClosing() { return }
        
        let r = uv_udp_recv_stop(socket)
        if r < 0 {
            throw Error.UVError(code: r)
        }
    }
    
}
