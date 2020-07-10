//
//  ExampleNetworkClientTests.swift
//  SomeNetworkAppTests
//
//  Created by Sasmito Adibowo on 6/7/20.
//  Copyright © 2020 Basil Salad Software. All rights reserved.
//

import XCTest
@testable import SomeNetworkApp

class ExampleNetworkClientTests : XCTestCase {
    
    let baseURL = URL(string:"https://example.com")!

    override func tearDownWithError() throws {
        BlockTestProtocolHandler.removeHandlers(byHost: baseURL.host!)
    }

    func testSuccess() {
        let testName = "found.json"
        let targetURL = baseURL.appendingPathComponent(testName)

        BlockTestProtocolHandler.register(url: targetURL) { (request: URLRequest) -> (response: HTTPURLResponse, data:Data?) in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: BlockTestProtocolHandler.httpVersion, headerFields: nil)!
            return (response,Data())
        }
        
        let fetchCompleted = XCTestExpectation(description: "Success Fetch Completed")
        defer {
            self.wait(for: [fetchCompleted], timeout: 7)
        }

        let client = makeExampleNetworkClient()
        client.fetchItem(named: testName) { (data: Data?, error: Error?) in
            defer {
                fetchCompleted.fulfill()
            }
            XCTAssertNil(error, "Error not expected")
            XCTAssertNotNil(data, "Data expected")
        }
    }
    
    func testFailure() {
        let testName = "not-found.json"
        let targetURL = baseURL.appendingPathComponent(testName)

        BlockTestProtocolHandler.register(url: targetURL) { (request: URLRequest) -> (response: HTTPURLResponse, data:Data?) in
            let response = HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: BlockTestProtocolHandler.httpVersion, headerFields: nil)!
            return (response,Data())
        }
        
        let fetchCompleted = XCTestExpectation(description: "Failure Fetch Completed")
        defer {
            self.wait(for: [fetchCompleted], timeout: 7)
        }

        let client = makeExampleNetworkClient()
        client.fetchItem(named: testName) { (data: Data?, error: Error?) in
            defer {
                fetchCompleted.fulfill()
            }
            XCTAssertNotNil(error, "Error expected")
            XCTAssertNil(data, "Data expected")
            if let cocoaError = error as NSError? {
                XCTAssertEqual(cocoaError.domain, ExampleNetworkClient.ErrorDomain, "Unexpected error domain")
                XCTAssertEqual(cocoaError.code, ExampleNetworkClient.ErrorCode.invalidStatus.rawValue, "Unexpected error code")
            }
        }
    }
    
    func makeExampleNetworkClient() -> ExampleNetworkClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [
            BlockTestProtocolHandler.self
        ]
        return ExampleNetworkClient(baseURL: baseURL, configuration: config)
    }
}
