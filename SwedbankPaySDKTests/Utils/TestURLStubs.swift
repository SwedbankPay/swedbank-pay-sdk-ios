extension MockURLProtocol {
    static func stubBackendUrl() {
        stubJson(url: TestConstants.backendUrl, json: TestConstants.rootBody)
    }
    
    static func stubConsumers() {
        stubJson(url: TestConstants.absoluteConsumersUrl, json: TestConstants.consumersBody)
    }
    
    static func stubPaymentorders() {
        stubJson(url: TestConstants.absolutePaymentordersUrl, json: TestConstants.paymentordersBody)
    }
}
