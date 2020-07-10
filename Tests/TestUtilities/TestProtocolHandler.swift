//
//  TestProtocolHandler.swift
//  SomeNetworkAppTests
//
//  Created by Sasmito Adibowo on 6/7/20.
//  Copyright © 2020 Basil Salad Software. All rights reserved.
//

import Foundation


public class BlockTestProtocolHandler: URLProtocol {
    
    public typealias ProtocolHandlerBlock = (_ request: URLRequest) -> (response: HTTPURLResponse, data: Data?)
    
    public enum ErrorCode: Int {
        case noError
        case missingTask
        case missingRequest
        case missingURL
        case missingHandler
        case incompliantURL
    }

    public static let httpVersion = "HTTP/1.1"

    public static let ErrorDomain = "com.basilsalad.BlockTestProtocolHandler.ErrorDomain"

    static var handlerMappings = [TestURLResourceKey:ProtocolHandlerBlock]()
    
    static let classLockQueue = DispatchQueue(label:"BlockTestProtocolHandler-classLockQueue")

    let delegateQueue = DispatchQueue(label: "BlockTestProtocolHandler-delegate")
    
    let processingQueue = DispatchQueue(label: "BlockTestProtocolHandler-processing")

    var _task: URLSessionTask?
    
    override public class func canInit(with task: URLSessionTask) -> Bool {
        guard let request = task.currentRequest else {
            return false
        }
        guard let url = request.url else {
            return false
        }
        guard let key = TestURLResourceKey(url: url) else {
            return false
        }
        return classLockQueue.sync {
            handlerMappings[key] != nil
        }
    }
    
    override public class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }
    
    public init(task: URLSessionTask, cachedResponse: CachedURLResponse?, client: URLProtocolClient?) {
        super.init(request: task.originalRequest!, cachedResponse: cachedResponse, client: client)
        _task = task
    }
    
    override public var task: URLSessionTask? {
        get {
            _task
        }
    }

    override public func startLoading() {
        guard let client = self.client else {
            return
        }
        func returnError(code: ErrorCode) {
            let error = NSError(code: code)
            self.delegateQueue.async {
                client.urlProtocol(self, didFailWithError: error)
            }
        }
        processingQueue.async {
            guard let task = self.task else {
                returnError(code: .missingTask)
                return
            }
            guard let currentRequest = task.currentRequest else {
                returnError(code: .missingRequest)
                return
            }
            guard let requestURL = task.currentRequest?.url else {
                returnError(code: .missingURL)
                return
            }
            guard let key = TestURLResourceKey(url: requestURL) else {
                returnError(code: .incompliantURL)
                return
            }
            
            guard let handler = type(of: self).classLockQueue.sync(execute:{
                type(of: self).handlerMappings[key]
            }) else {
                returnError(code: .missingHandler)
                return
            }
            let (response, data) = handler(currentRequest)

            self.delegateQueue.async {
                client.urlProtocol(self, didReceive: response, cacheStoragePolicy: .allowedInMemoryOnly)
                if let resultData = data {
                    client.urlProtocol(self, didLoad: resultData)
                }
                client.urlProtocolDidFinishLoading(self)
            }
        }
    }
    
    override public func stopLoading() {
        // empty for now
    }
    
    public class func register(url: URL, handler: @escaping ProtocolHandlerBlock) {
        guard let key = TestURLResourceKey(url: url) else {
            return
        }
        
        classLockQueue.sync {
            handlerMappings[key] = handler
        }
    }
    
    public class func unregister(url: URL) {
        guard let key = TestURLResourceKey(url: url) else {
            return
        }
        classLockQueue.sync {
            _ = handlerMappings.removeValue(forKey: key)
        }
    }
    
    public class func removeHandlers(byHost hostName: String) {
        classLockQueue.sync {
            let filtered = handlerMappings.filter { (element) -> Bool in
                element.key.host != hostName
            }
            handlerMappings = filtered
        }
    }
}


struct TestURLResourceKey: Equatable, Hashable {
    var scheme: String
    var host: String
    var path: String
    var port: Int?
    
    init?(url: URL) {
        guard let scheme = url.scheme else {
            return nil
        }
        guard let host = url.host else {
            return nil
        }
        self.scheme = scheme
        self.host = host
        self.path = url.path
        self.port = url.port
    }
}


extension NSError {
    convenience init(code: BlockTestProtocolHandler.ErrorCode, userInfo: [String : Any]? = nil) {
        self.init(domain: BlockTestProtocolHandler.ErrorDomain, code: code.rawValue, userInfo: userInfo)
    }
}
