import Foundation
import XCTest

class MockURLProtocol: URLProtocol {
    static let scheme = "mock"
    
    static var urlSessionConfiguration: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.protocolClasses = [MockURLProtocol.self]
        return configuration
    }
    
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
        
    override class func canInit(with request: URLRequest) -> Bool {
        return request.url?.scheme == scheme
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
        
    override func startLoading() {
        DispatchQueue.main.async {
            let result = self.getResult() ?? .missingStub
            self.reportResult(result)
        }
    }
    override func stopLoading() {}
    
    private func getResult() -> MockURLResult? {
        let request = self.request
        guard
            let url = request.url?.absoluteString,
            var stub = MockURLProtocol.stubs[url]
            else {
                print("No stub for \(request.url?.absoluteString ?? "")")
                return nil
        }
        if !stub.used {
            stub.used = true
            MockURLProtocol.stubs[url] = stub
        }
        return stub.handler(request)
    }
    
    private func reportResult(_ result: MockURLResult) {
        if let client = self.client {
            if let response = result.response {
                client.urlProtocol(self, didReceive: response.0, cacheStoragePolicy: response.1)
            }
            if let data = result.data {
                client.urlProtocol(self, didLoad: data)
            }
            if let error = result.error {
                client.urlProtocol(self, didFailWithError: error)
            }
            client.urlProtocolDidFinishLoading(self)
        }
    }
}
