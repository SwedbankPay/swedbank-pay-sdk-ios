import XCTest

extension MockURLProtocol {
    static func stubBackendUrl(for testCase: XCTestCase) {
        stubJson(url: MockMerchantBackend.backendUrl(for: testCase), json: TestConstants.rootBody)
    }
    
    static func stubConsumers(for testCase: XCTestCase) {
        stubJson(url: MockMerchantBackend.absoluteConsumersUrl(for: testCase), json: TestConstants.consumersBody)
    }
    
    static func stubPaymentorders(for testCase: XCTestCase) {
        stubJson(url: MockMerchantBackend.absolutePaymentordersUrl(for: testCase), json: TestConstants.paymentordersBody)
    }
}
