import Foundation
import XCTest

class MockURLProtocol: URLProtocol {
    static let scheme = "mock"
    
    private struct Stub {
        let handler: (URLRequest) -> MockURLResult
        var used = false
    }
    
    private static var stubs: [String: Stub] = [:]
    
    static func assertNoUnusedStubs() {
        for (url, stub) in stubs {
            XCTAssert(stub.used, "Unused stub \(url)")
        }
    }
    
    static func reset() {
        stubs.removeAll()
    }
    
    static func stub(url: URL, handler: @escaping (URLRequest) -> MockURLResult) {
        XCTAssert(url.scheme == scheme, "\(url) has wrong scheme (expected \(scheme))")
        stubs[url.absoluteString] = Stub(handler: handler)
    }
    
    static func stubError(url: URL, error: Error = StubbedURLError()) {
        stub(url: url) { _ in MockURLResult(error: error) }
    }
    
    static func stubJson(url: URL, json: Any) {
        stub(url: url, handler: { _ -> MockURLResult in
            let data = try! JSONSerialization.data(withJSONObject: json)
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
            return MockURLResult(response: response, data: data)
        })
    }
    
    private let handler: (URLRequest) -> MockURLResult
        
    override class func canInit(with request: URLRequest) -> Bool {
        return request.url?.scheme == scheme
    }
    
    override init(request: URLRequest, cachedResponse: CachedURLResponse?, client: URLProtocolClient?) {
        do {
            let url = request.url!.absoluteString
            var stub = try XCTUnwrap(MockURLProtocol.stubs[url], "Unexpected request for \(url). Possibly missing a stub?")
            if !stub.used {
                stub.used = true
                MockURLProtocol.stubs[url] = stub
            }
            self.handler = stub.handler
        } catch let error {
            self.handler = { _ in MockURLResult(error: error) }
        }
        super.init(request: request, cachedResponse: cachedResponse, client: client)
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        let stub = handler(request)
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
