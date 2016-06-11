//
//  FileStat.swift
//  SwiftyLibuv
//
//  Created by Yuki Takei on 6/12/16.
//
//

import CLibUv

struct FileStatContext {
    var completion: ((Void) throws -> Void) -> Void
}

internal class FileStatWrap {
    
    let context: FileStatContext
    
    let path: String
    
    let loop: Loop
    
    init(loop: Loop = Loop.defaultLoop, path: String, completion: ((Void) throws -> Void) -> Void){
        self.loop = loop
        self.path = path
        self.context = FileStatContext(completion: completion)
        
        var req = UnsafeMutablePointer<uv_fs_t>(allocatingCapacity: sizeof(uv_fs_t))
        req.pointee.data = retainedVoidPointer(context)
        
        let r = uv_fs_stat(loop.loopPtr, req, path) { req in
            guard let req = req else { return }
            
            let context: FileStatContext = releaseVoidPointer(req.pointee.data)!
            
            defer {
                fs_req_cleanup(req)
            }
            
            if(req.pointee.result < 0) {
                return context.completion {
                    throw Error.UVError(code: Int32(req.pointee.result))
                }
            }
            
            context.completion { }
        }
        
        if r < 0 {
            fs_req_cleanup(req)
            context.completion {
                throw Error.UVError(code: r)
            }
        }
    }
}

