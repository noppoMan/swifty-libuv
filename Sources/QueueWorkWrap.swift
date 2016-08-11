//
//  QueueWorkWrap.swift
//  SwiftyLibuv
//
//  Created by Yuki Takei on 6/12/16.
//
//

import CLibUv

private typealias WorkQueueTask = () -> ()

private func work_cb(req: UnsafeMutablePointer<uv_work_t>?) {
    guard let req = req else {
        return
    }
    let ctx: QueueWorkerContext = releaseVoidPointer(req.pointee.data)
    ctx.workCB()
    req.pointee.data = retainedVoidPointer(ctx)
}

private func after_work_cb(req: UnsafeMutablePointer<uv_work_t>?, status: Int32){
    guard let req = req else {
        return
    }
    
    defer {
        dealloc(req)
    }
    
    let ctx: QueueWorkerContext = releaseVoidPointer(req.pointee.data)
    ctx.afterWorkCB()
}

private struct QueueWorkerContext {
    let workCB: () -> ()
    let afterWorkCB: () -> ()
    
    init(workCB: @escaping () -> (), afterWorkCB: @escaping () -> ()) {
        self.workCB = workCB
        self.afterWorkCB = afterWorkCB
    }
}

public class QueueWorkWrap {
    
    let req: UnsafeMutablePointer<uv_work_t>
    
    public var workCallback: (Void) -> Void = { _ in }
    
    public var afterWorkCallback: (Void) -> Void = { _ in }
    
    let loop: Loop
    
    public init(loop: Loop = Loop.defaultLoop) {
        self.loop = loop
        self.req = UnsafeMutablePointer<uv_work_t>.allocate(capacity: MemoryLayout<uv_work_t>.size)
    }
    
    public func execute(){
        let context = QueueWorkerContext(workCB: workCallback, afterWorkCB: afterWorkCallback)
        req.pointee.data = retainedVoidPointer(context)
        uv_queue_work(loop.loopPtr, req, work_cb, after_work_cb)
    }
    
    public func cancel(){
        uv_cancel(req.cast(to: UnsafeMutablePointer<uv_req_t>.self))
    }
}
