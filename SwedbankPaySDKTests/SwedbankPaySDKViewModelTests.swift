//
//  SwedbackPaySDKViewModelTests.swift
//  SwedbankPaySDKTests
//
//  Created by Pertti Kroger on 21/11/2019.
//  Copyright © 2019 Swedbank. All rights reserved.
//

import Alamofire
import XCTest
@testable import SwedbankPaySDK

enum TestConstants {
    static let backendUrl = "\(MockURLProtocol.scheme)://backendurl.invalid/"
    static let absoluteConsumersUrl = "\(MockURLProtocol.scheme)://backendurl.invalid/consumersurl"
    static let relativeToDomainConsumersUrl = "/consumersurl"
    static let relativeToPathConsumersUrl = "consumersurl"
    static let consumerData = SwedbankPaySDK.Consumer(consumerCountryCode: "SE", msisdn: nil, email: nil, nationalIdentifier: nil)
}

class SwedbankPaySDKViewModelTests: XCTestCase {
    
    private var viewModel: SwedbankPaySDKViewModel!
        
    override func setUp() {
        viewModel = SwedbankPaySDKViewModel()
        viewModel.setConfiguration(SwedbankPaySDK.Configuration(backendUrl: TestConstants.backendUrl, headers: ["HeaderName": "HeaderValue"]))
        
        let sessionConf = URLSessionConfiguration.default
        sessionConf.protocolClasses = [MockURLProtocol.self]
        viewModel.sessionManager = Alamofire.SessionManager(configuration: sessionConf)
    }
    
    func testItShouldPostConsumersAfterIdentifyConsumers1() {
        doShouldPostIdentifyConsumers(backendUrl: TestConstants.backendUrl, consumersUrl: TestConstants.relativeToPathConsumersUrl)
    }
    
    func testItShouldPostConsumersAfterIdentifyConsumers2() {
        doShouldPostIdentifyConsumers(backendUrl: TestConstants.backendUrl, consumersUrl: TestConstants.relativeToDomainConsumersUrl)
    }
    
    func testItShouldPostConsumersAfterIdentifyConsumers3() {
        doShouldPostIdentifyConsumers(backendUrl: TestConstants.backendUrl, consumersUrl: TestConstants.absoluteConsumersUrl)
    }
    
    private func doShouldPostIdentifyConsumers(backendUrl: String, consumersUrl: String) {
        let expectation = XCTestExpectation(description: "A POST request is made to \(TestConstants.absoluteConsumersUrl)")
        
        MockURLProtocol.with {
            MockURLProtocol.stubJson(url: backendUrl, json: [
                "consumers": consumersUrl
            ])
            MockURLProtocol.stub(url: TestConstants.absoluteConsumersUrl) { request -> MockURLStub in
                if (request.httpMethod == "POST") {
                    expectation.fulfill()
                }
                return MockURLStub(error: StubURLError())
            }
            viewModel.setConsumerData(TestConstants.consumerData)
            viewModel.identifyConsumer(backendUrl)
        }
        wait(for: [expectation], timeout: 5)
    }
}

struct StubURLError: Error {}

struct MockURLStub {
    var response: (URLResponse, URLCache.StoragePolicy)? = nil
    var data: Data? = nil
    var error: Error? = nil
}

extension MockURLStub {
    init(
        response: URLResponse,
        data: Data
    ) {
        self.init(response: (response, .notAllowed), data: data, error: nil)
    }
    
    init(
        response: URLResponse,
        error: Error
    ) {
        self.init(response: (response, .notAllowed), data: nil, error: error)
    }
    
    init(error: Error) {
        self.init(response: nil, data: nil, error: error)
    }
}

class MockURLProtocol: URLProtocol {
    static let scheme = "mock"
    
    private static var stubs: [String: (URLRequest) -> MockURLStub] = [:]
    
    static func reset() {
        stubs.removeAll()
    }
    
    static func with(_ f: () -> Void) {
        reset()
        registerClass(self)
        f()
        unregisterClass(self)
    }
    
    static func stub(url: String, stub: @escaping (URLRequest) -> MockURLStub) {
        XCTAssert(URL(string: url)?.scheme == scheme, "\(url) has wrong scheme (expected \(scheme))")
        stubs[url] = stub
    }
    
    static func stubJson(url: String, json: Any) {
        stub(url: url, stub: { _ -> MockURLStub in
            let data = try! JSONSerialization.data(withJSONObject: json)
            let response = HTTPURLResponse(url: URL(string: url)!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
            return MockURLStub(response: response, data: data)
        })
    }
    
    private let stub: (URLRequest) -> MockURLStub
    
    override class func canInit(with request: URLRequest) -> Bool {
        return request.url?.scheme == scheme
    }
    
    override init(request: URLRequest, cachedResponse: CachedURLResponse?, client: URLProtocolClient?) {
        let url = request.url!
        do {
            self.stub = try XCTUnwrap(MockURLProtocol.stubs[url.absoluteString], "Unexpected request for \(url). Possibly missing a stub?")
        } catch let error {
            self.stub = { _ in MockURLStub(error: error) }
        }
        super.init(request: request, cachedResponse: cachedResponse, client: client)
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        let stub = self.stub(self.request)
        if let response = stub.response {
            client?.urlProtocol(self, didReceive: response.0, cacheStoragePolicy: response.1)
        }
        if let data = stub.data {
            client?.urlProtocol(self, didLoad: data)
        }
        if let error = stub.error {
            client?.urlProtocol(self, didFailWithError: error)
        }
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
