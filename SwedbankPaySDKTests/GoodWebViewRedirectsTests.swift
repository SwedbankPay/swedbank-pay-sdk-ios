import XCTest
import Foundation
@testable import SwedbankPaySDK

class GoodWebViewRedirectsTests: XCTestCase {
    
    let defaultTimeout: TimeInterval = 15
    private var redirects: GoodWebViewRedirects!
    
    private func parse(_ text: String) {
        redirects = GoodWebViewRedirects(openDataFile: FileUtils.factory(text))
    }
    
    private func expect(url: String, allowed: Bool) {
        let expectation = self.expectation(description: "\(url) is \(allowed ? "" : "not ") allowed")
        redirects.allows(url: URL(string: url)!) {
            XCTAssertEqual($0, allowed, "Unexpected result for \(url)")
            expectation.fulfill()
        }
    }
    
    private func waitForExpectations() {
        waitForExpectations(timeout: defaultTimeout, handler: nil)
    }
    
    func testItParsesDomains() {
        parse("example.com")
        expect(url: "https://example.com/", allowed: true)
        expect(url: "https://example.com/path", allowed: true)
        expect(url: "https://sub.example.com/", allowed: false)
        expect(url: "https://other.com/", allowed: false)
        waitForExpectations()
    }
    
    func testItParsesSingleWildcards() {
        parse("*.example.com")
        expect(url: "https://example.com/", allowed: true)
        expect(url: "https://sub.example.com/", allowed: true)
        expect(url: "https://sub.example.com/path", allowed: true)
        expect(url: "https://double.sub.example.com/", allowed: false)
        expect(url: "https://other.com/", allowed: false)
        waitForExpectations()
    }
    
    func testItParsesDoubleWildcards() {
        parse("**.example.com")
        expect(url: "https://example.com/", allowed: true)
        expect(url: "https://sub.example.com/", allowed: true)
        expect(url: "https://double.sub.example.com/", allowed: true)
        expect(url: "https://double.sub.example.com/path", allowed: true)
        expect(url: "https://other.com/", allowed: false)
        waitForExpectations()
    }
    
    func testItParsesComments() {
        parse("#example.com")
        expect(url: "https://example.com/", allowed: false)
        expect(url: "https://other.com/", allowed: false)
        waitForExpectations()
    }
    
    func testEnsemble() {
        parse("""
# Comment
domain.com
 sub.domain.com

#not.this.com
*.subdomains.org  


    **.anything.net

""")
        expect(url: "https://domain.com/", allowed: true)
        expect(url: "https://sub.domain.com/", allowed: true)
        expect(url: "https://double.sub.domain.com/", allowed: false)
        expect(url: "https://other.domain.com/", allowed: false)
        
        expect(url: "https://not.this.com/", allowed: false)

        expect(url: "https://subdomains.org/", allowed: true)
        expect(url: "https://sub.subdomains.org/", allowed: true)
        expect(url: "https://double.sub.subdomains.org/", allowed: false)
        expect(url: "https://other.subdomains.org/", allowed: true)

        expect(url: "https://anything.net/", allowed: true)
        expect(url: "https://sub.anything.net/", allowed: true)
        expect(url: "https://double.sub.anything.net/", allowed: true)
        expect(url: "https://how.long.can.we.go.on.anything.net/quite/long?apparently=true", allowed: true)
        expect(url: "https://something.net/", allowed: false)

        waitForExpectations()
    }
}
