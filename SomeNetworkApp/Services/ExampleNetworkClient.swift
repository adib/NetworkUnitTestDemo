//
//  ExampleNetworkClient.swift
//  SomeNetworkApp
//
//  Created by Sasmito Adibowo on 6/7/20.
//  Copyright © 2020 Basil Salad Software. All rights reserved.
//

import Foundation


public class ExampleNetworkClient {
    
    public init(baseURL: URL, configuration: URLSessionConfiguration = URLSessionConfiguration.default) {
        self.baseURL = baseURL
        self.sessionConfiguration = configuration
    }
    
    var baseURL: URL
    
    var networkServiceType = NSURLRequest.NetworkServiceType.responsiveData
    
    var sessionConfiguration: URLSessionConfiguration
    
    lazy var urlSession = URLSession(configuration: sessionConfiguration)
    
    public func fetchItem(named itemName: String, completionHandler: @escaping (_ success: Data?, _ failure: Error?) -> Void) {
        let url = baseURL.appendingPathComponent(itemName)
        var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
        request.networkServiceType = networkServiceType

        let task = urlSession.dataTask(with: request) { (data: Data?, response: URLResponse?, error: Error?) in
            guard let receivedResponse = response as? HTTPURLResponse else {
                completionHandler(nil, NSError(code:.unknownError))
                return
            }
            guard receivedResponse.statusCode == 200 else {
                completionHandler(nil, NSError(code:.invalidStatus))
                return
            }
            guard let receivedData = data else {
                completionHandler(nil, NSError(code: .missingData))
                return
            }
            completionHandler(receivedData, nil)
        }
        task.resume()
    }
    
    public enum ErrorCode: Int {
        case noError
        case invalidStatus
        case missingData
        case unknownError
    }
    
    public static let ErrorDomain = "com.basilsalad.ExampleNetworkClient.ErrorDomain"
}


extension NSError {
    convenience init(code: ExampleNetworkClient.ErrorCode, userInfo: [String : Any]? = nil, underlying: Error? = nil) {
        var chainInfo = userInfo ?? [:]
        if let chainError = underlying {
            chainInfo[NSUnderlyingErrorKey] = chainError
        }
        self.init(domain: ExampleNetworkClient.ErrorDomain, code: code.rawValue, userInfo: chainInfo)
    }
}
