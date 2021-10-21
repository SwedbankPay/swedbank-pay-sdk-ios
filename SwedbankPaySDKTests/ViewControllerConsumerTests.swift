import XCTest
import WebKit
@testable import SwedbankPaySDK

class ViewControllerConsumerTests : SwedbankPaySDKControllerTestCase {
    private let timeout = 5 as TimeInterval
    
    private var testConfiguration: TestConfiguration?
    
    private func startViewController(
        testConfiguration: TestConfiguration,
        setupConsumers: Bool = true,
        setupPaymentorders: Bool = false
    ) {
        self.testConfiguration = testConfiguration
        testConfiguration.setup(testCase: self, consumers: setupConsumers, paymentorders: setupPaymentorders)
        viewController = SwedbankPaySDKController(
            configuration: testConfiguration.sdkConfiguration(for: self),
            consumer: TestConstants.consumerData,
            paymentOrder: MockMerchantBackend.paymentOrder(for: self)
        )
    }
    
    override func tearDown() {
        testConfiguration?.teardown()
        super.tearDown()
    }
    
    private func testItShouldStartWithoutCrashing(testConfiguration: TestConfiguration) {
        startViewController(testConfiguration: testConfiguration, setupConsumers: false)
    }
    func testItShouldStartWithoutCrashing() {
        testItShouldStartWithoutCrashing(testConfiguration: .merchantBackend)
    }
    func testItShouldStartWithoutCrashingAsync() throws {
        try testItShouldStartWithoutCrashing(testConfiguration: .getAsyncConfigOrSkipTest())
    }
    
    private func testItShouldShowViewConsumerIdentificationPage(testConfiguration: TestConfiguration) {
        startViewController(testConfiguration: testConfiguration)
        waitForWebViewLoaded()
        
        expectViewConsumerIdentificationPageInWebView()
        waitForExpectations(timeout: timeout, handler: nil)
    }
    func testItShouldShowViewConsumerIdentificationPage() {
        testItShouldShowViewConsumerIdentificationPage(testConfiguration: .merchantBackend)
    }
    func testItShouldShowViewConsumerIdentificationPageAsync() throws {
        try testItShouldShowViewConsumerIdentificationPage(testConfiguration: .getAsyncConfigOrSkipTest())
    }
    
    // The .async configuration does not make URL requests,
    // so this test only makes sense for the .merchantBackend configuration.
    func testItShouldMakePostRequestToPaymentOrdersUrlAfterIdentificationSuccess() {
        startViewController(testConfiguration: .merchantBackend)
        waitForWebViewLoaded()
        
        let onConsumerIdentifiedCalled = expectation(description: "consumerProfileRef set in viewModel")
        webView.evaluateJavaScript("webkit.messageHandlers.\(SwedbankPayWebContent.scriptMessageHandlerName).postMessage({msg:'\(SwedbankPayWebContent.ConsumerEvent.onConsumerIdentified)',arg:'\(TestConstants.consumerProfileRef)'})") { _, _ in
            onConsumerIdentifiedCalled.fulfill()
        }
        
        expectRequest(to: MockMerchantBackend.absolutePaymentordersUrl(for: self), expectedRequest: .postJson({
            let paymentorder = $0["paymentorder"]
            let paymentorderObj = try XCTUnwrap(paymentorder as? [String : Any])
            let payer = paymentorderObj["payer"]
            let payerObj = try XCTUnwrap(payer as? [String : Any])
            let profile = payerObj["consumerProfileRef"]
            let profileString = try XCTUnwrap(profile as? String)
            XCTAssertEqual(profileString, TestConstants.consumerProfileRef)
        }))
        waitForExpectations(timeout: timeout, handler: nil)
    }
    
    private func testItShouldShowViewPaymentorderPageAfterIdentificationSuccess(testConfiguration: TestConfiguration) {
        startViewController(testConfiguration: testConfiguration, setupPaymentorders: true)
        waitForWebViewLoaded()
        
        webView.evaluateJavaScript("webkit.messageHandlers.\(SwedbankPayWebContent.scriptMessageHandlerName).postMessage({msg:'\(SwedbankPayWebContent.ConsumerEvent.onConsumerIdentified)',arg:'\(TestConstants.consumerProfileRef)'})", completionHandler: nil)
        waitForWebViewLoaded()
        
        expectViewPaymentorderPageInWebView()
        waitForExpectations(timeout: timeout, handler: nil)
        
        MockURLProtocol.assertNoUnusedStubs()
    }
    func testItShouldShowViewPaymentorderPageAfterIdentificationSuccess() {
        testItShouldShowViewPaymentorderPageAfterIdentificationSuccess(testConfiguration: .merchantBackend)
    }
    func testItShouldShowViewPaymentorderPageAfterIdentificationSuccessAsync() throws {
        try testItShouldShowViewPaymentorderPageAfterIdentificationSuccess(testConfiguration: .getAsyncConfigOrSkipTest())
    }
    
    private func testItShouldReportFailureAfterConsumerError(testConfiguration: TestConfiguration) {
        let paymentFailed = expectation(description: "Payment failed")
        delegate.onFailed = { _ in
            paymentFailed.fulfill()
        }
        startViewController(testConfiguration: testConfiguration)
        waitForWebViewLoaded()
        
        webView.evaluateJavaScript("webkit.messageHandlers.\(SwedbankPayWebContent.scriptMessageHandlerName).postMessage({msg:'\(SwedbankPayWebContent.ConsumerEvent.onError)'})", completionHandler: nil)
        waitForExpectations(timeout: timeout, handler: nil)
        
        MockURLProtocol.assertNoUnusedStubs()
    }
    func testItShouldReportFailureAfterConsumerError() {
        testItShouldReportFailureAfterConsumerError(testConfiguration: .merchantBackend)
    }
    func testItShouldReportFailureAfterConsumerErrorAsync() throws {
        try testItShouldReportFailureAfterConsumerError(testConfiguration: .getAsyncConfigOrSkipTest())
    }
}

private extension TestConfiguration {
    func setup(testCase: XCTestCase, consumers: Bool, paymentorders: Bool) {
        switch self {
        case .merchantBackend:
            if consumers {
                MockURLProtocol.stubBackendUrl(for: testCase)
                MockURLProtocol.stubConsumers(for: testCase)
            }
            if paymentorders {
                MockURLProtocol.stubPaymentorders(for: testCase)
            }
            
#if swift(>=5.5)
        case .async:
            break
#endif // swift(>=5.5)
        }
    }
    
    func teardown() {
        switch self {
        case .merchantBackend:
            MockURLProtocol.assertNoUnusedStubs()
            
#if swift(>=5.5)
        case .async:
            break
#endif // swift(>=5.5)
        }
    }
}
