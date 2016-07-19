//
//  Timer.swift
//  SwiftyLibuv
//
//  Created by Yuki Takei on 6/12/16.
//
//

import CLibUv

private func timer_start_cb(handle: UnsafeMutablePointer<uv_timer_t>?){
    if let handle = handle, context = UnsafeMutablePointer<TimerContext>(handle.pointee.data) {
        context.pointee.callback()
    }
}

struct TimerContext {
    let callback: () -> ()
}


/**
 Timer state enum
 */
public enum TimerState {
    case pause
    case running
    case stop
    case end
}

/**
 Timer mode
 */
public enum TimerMode {
    case interval
    case timeout
}

/**
 Timer handle
 */
public class TimerWrap {
    
    /**
     Current timer state
     */
    public private(set) var state: TimerState = .pause
    
    public let mode: TimerMode
    
    public private(set) var tick: UInt64 = 0
    
    private let handle: UnsafeMutablePointer<uv_timer_t>
    
    private var context: UnsafeMutablePointer<TimerContext>?
    
    private var initalized = false
    
    /**
     - parameter mode: .Interval or Timeout
     - parameter tick: Micro sec for timer tick.
     */
    public init(loop: Loop = Loop.defaultLoop, mode: TimerMode = .timeout, tick: UInt64){
        self.mode = mode
        self.tick = tick
        self.handle = UnsafeMutablePointer<uv_timer_t>(allocatingCapacity: sizeof(uv_timer_t.self))
        uv_timer_init(loop.loopPtr, handle)
    }
    
    /**
     Reference the internal uv_timer_t handle
     */
    public func ref(){
        uv_ref(UnsafeMutablePointer<uv_handle_t>(handle))
    }
    
    /**
     Un-reference the internal uv_timer_t handle
     */
    public func unref(){
        uv_unref(UnsafeMutablePointer<uv_handle_t>(handle))
    }
    
    /**
     Stop the timer. If you stop the timer, it can restart with calling resume.
     */
    public func stop() {
        if case .end = state { return }
        uv_timer_stop(handle)
        state = .stop
    }
    
    /**
     Start the timer with specific mode
     */
    public func start(_ callback: () -> ()){
        if case .end = state { return }
        if initalized { return }
        
        context = UnsafeMutablePointer<TimerContext>(allocatingCapacity: 1)
        context?.initialize(with: TimerContext(callback: callback))
        
        handle.pointee.data = UnsafeMutablePointer(context)
        
        switch(mode) {
        case .timeout:
            uv_timer_start(handle, timer_start_cb, UInt64(tick), 0)
        case .interval:
            uv_timer_start(handle, timer_start_cb, 0, UInt64(tick))
        }
        state = .running
        initalized = true
    }
    
    /**
     Resume the timer that is initialized once
     */
    public func resume() {
        if case .end = state { return }
        uv_timer_again(handle)
        state = .running
    }
    
    /**
     End the timer.
     Anyways, You must call end in both of Interval and Timeout mode to release resource, when the timing that timer should be ended.
     If you forgot to call end, memory leak will be occured.
     */
    public func end(){
        if case .end = state { return }
        stop()
        unref()
        self.state = .end
        dealloc(handle)
    }
}
