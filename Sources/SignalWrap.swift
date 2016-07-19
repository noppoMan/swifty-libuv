//
//  Signal.swift
//  SwiftyLibuv
//
//  Created by Yuki Takei on 6/12/16.
//
//

import CLibUv


/**
 Signal handle type
 
 #### List of signals
 
 * SIGABRT
 * SIGFPE
 * SIGILL
 * SIGINT
 * SIGSEGV
 * SIGTERM
 */
public class SignalWrap {
    
    private var signalHandler: (Int32) -> () = {_ in }
    
    public let loop: Loop
    
    public private(set) var signalPtr: UnsafeMutablePointer<uv_signal_t>
    
    public init(loop: Loop = Loop.defaultLoop){
        self.loop = loop
        self.signalPtr = UnsafeMutablePointer<uv_signal_t>(allocatingCapacity: sizeof(uv_signal_t.self))
        uv_signal_init(loop.loopPtr, signalPtr)
    }
    
    public func start(_ sig: Int32, signalHandler: (Int32) -> ()){
        self.signalHandler = signalHandler
        
        signalPtr.pointee.data = unsafeBitCast(self, to: UnsafeMutablePointer<Void>.self)
        uv_signal_start(signalPtr, { handle, sig in
            if let handle = handle {
                let _signal = unsafeBitCast(handle.pointee.data, to: SignalWrap.self)
                _signal.signalHandler(sig)
            }
            }, sig)
    }
    
    public func stop(){
        uv_signal_stop(signalPtr)
    }
    
    deinit {
        close_handle(signalPtr)
    }
}

