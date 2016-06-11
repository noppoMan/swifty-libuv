//
//  Buffer.swift
//  SwiftyLibuv
//
//  Created by Yuki Takei on 6/12/16.
//
//

public struct Buffer {
    public var bytes: [UInt8]
    
    public init() {
        self.bytes = []
    }
    
    public init(_ bytes: [UInt8]) {
        self.bytes = bytes
    }
    
    public init(buffer buf: UnsafePointer<UInt8>, length: Int) {
        var bytes: [UInt8] = []
        for i in stride(from: 0, to: length, by: 1) {
            bytes.append(buf[i])
        }
        self.bytes = bytes
    }
    
    public mutating func append(_ byte: UInt8) {
        self.bytes.append(byte)
    }
    
    internal mutating func append(_ byte: Int8) {
        self.bytes.append(UInt8(bitPattern: byte))
    }
}

extension Buffer: ArrayLiteralConvertible {
    public init(arrayLiteral bytes: UInt8...) {
        self.init(bytes)
    }
}
