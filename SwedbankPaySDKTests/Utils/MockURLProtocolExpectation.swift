import Foundation
import XCTest

extension XCTestCase {
    @discardableResult
    func expectRequest(to url: URL, expectedRequest: ExpectedRequest) -> XCTestExpectation {
        let expectation = self.expectation(description: "\(expectedRequest) request is made to \(url)")
        MockURLProtocol.stub(url: url) { request in
            expectedRequest.checkAndAssertNoThrow(request: request)
            expectation.fulfill()
            return MockURLResult(error: StubbedURLError())
        }
        return expectation
    }
}

enum ExpectedRequest : CustomStringConvertible {
    case get
    case postJson(([String : Any]) throws -> Void)
    
    var description: String {
        switch self {
        case .get: return "GET"
        case .postJson: return "POST <json>"
        }
    }
    
    func checkAndAssertNoThrow(request: URLRequest) {
        XCTAssertNoThrow(try check(request: request))
    }
    
    private func check(request: URLRequest) throws {
        switch self {
        case .get:
            XCTAssert(request.httpMethod == "GET")
        case .postJson(let checkBody):
            XCTAssert(request.httpMethod == "POST")
            if let body = request.httpBody {
                try checkJsonBody(body, JSONSerialization.jsonObject, checkBody)
            } else if let stream = request.httpBodyStream {
                stream.open()
                defer {
                    stream.close()
                }
                try checkJsonBody(stream, JSONSerialization.jsonObject, checkBody)
            } else {
                XCTFail("No body in POST request")
            }
        }
    }
    
    private func checkJsonBody<T>(
        _ source: T,
        _ parser: (T, JSONSerialization.ReadingOptions) throws -> Any,
        _ checker: ([String : Any]) throws -> Void
    ) throws {
        let value = try parser(source, [])
        let object = try XCTUnwrap(value as? [String : Any])
        try checker(object)
    }
}
