import XCTest
import WebKit
@testable import SwedbankPaySDK

class ViewControllerTests : SwedbankPaySDKControllerTestCase {
    private let timeout = 15 as TimeInterval
    
    private var testConfiguration: TestConfiguration?
    
    private func startViewController(testConfiguration: TestConfiguration, setupPaymentorders: Bool = true) {
        self.testConfiguration = testConfiguration
        if setupPaymentorders {
            testConfiguration.setupPaymentorders(testCase: self)
        }
        viewController = SwedbankPaySDKController(
            configuration: testConfiguration.sdkConfiguration(for: self),
            paymentOrder: MockMerchantBackend.paymentOrder(for: self)
        )
    }
    
    override func tearDown() {
        testConfiguration?.teardown()
        super.tearDown()
    }
    
    private func testItShouldStartWithoutCrashing(testConfiguration: TestConfiguration) {
        startViewController(testConfiguration: testConfiguration, setupPaymentorders: false)
    }
    func testItShouldStartWithoutCrashing() {
        testItShouldStartWithoutCrashing(testConfiguration: .merchantBackend)
    }
    func testItShouldStartWithoutCrashingAsync() throws {
        try testItShouldStartWithoutCrashing(testConfiguration: .getAsyncConfigOrSkipTest())
    }
    
    private func testItShouldShowViewPaymentorderPage(testConfiguration: TestConfiguration) {
        startViewController(testConfiguration: testConfiguration)
        waitForWebViewLoaded()
        
        expectViewPaymentorderPageInWebView()
        waitForExpectations(timeout: timeout, handler: nil)
    }
    func testItShouldShowViewPaymentorderPage() {
        testItShouldShowViewPaymentorderPage(testConfiguration: .merchantBackend)
    }
    func testItShouldShowViewPaymentorderPageAsync() throws {
        try testItShouldShowViewPaymentorderPage(testConfiguration: .getAsyncConfigOrSkipTest())
    }
    
    private func testItShouldReportSuccessAfterNavigationToCompleteUrl(testConfiguration: TestConfiguration) {
        let paymentCompleted = expectation(description: "Payment completed")
        delegate.onComplete = {
            paymentCompleted.fulfill()
        }
        startViewController(testConfiguration: testConfiguration)
        waitForWebViewLoaded()
        
        let completeUrl = MockMerchantBackend.paymentOrder(for: self).urls.completeUrl.absoluteString
        webView.evaluateJavaScript("window.location = '\(completeUrl)'", completionHandler: nil)
        waitForExpectations(timeout: timeout, handler: nil)
    }
    func testItShouldReportSuccessAfterNavigationToCompleteUrl() {
        testItShouldReportSuccessAfterNavigationToCompleteUrl(testConfiguration: .merchantBackend)
    }
    func testItShouldReportSuccessAfterNavigationToCompleteUrlAsync() throws {
        try testItShouldReportSuccessAfterNavigationToCompleteUrl(testConfiguration: .getAsyncConfigOrSkipTest())
    }
    
    private func testItShouldReloadViewPaymentorderPageWhenItNavigatesToPaymentUrl(testConfiguration: TestConfiguration) {
        startViewController(testConfiguration: testConfiguration)
        waitForWebViewLoaded()
        wait(for: [expectViewPaymentorderPageInWebView()], timeout: timeout)
        
        webView.evaluateJavaScript("window.location = 'about:blank'", completionHandler: nil)
        waitForWebViewLoaded()
        wait(for: [expectEmptyWebView()], timeout: timeout)
        
        let paymentUrl = MockMerchantBackend.paymentOrder(for: self).urls.paymentUrl!.absoluteString
        webView.evaluateJavaScript("window.location = '\(paymentUrl)'", completionHandler: nil)
        waitForWebViewLoaded()
        wait(for: [expectViewPaymentorderPageInWebView()], timeout: timeout)
    }
    func testItShouldReloadViewPaymentorderPageWhenItNavigatesToPaymentUrl() {
        testItShouldReloadViewPaymentorderPageWhenItNavigatesToPaymentUrl(testConfiguration: .merchantBackend)
    }
    func testItShouldReloadViewPaymentorderPageWhenItNavigatesToPaymentUrlAsync() throws {
        try testItShouldReloadViewPaymentorderPageWhenItNavigatesToPaymentUrl(testConfiguration: .getAsyncConfigOrSkipTest())
    }
    
    private func testItShouldReportFailureAfterOnError(testConfiguration: TestConfiguration) {
        let paymentFailed = expectation(description: "Payment failed")
        delegate.onFailed = { _ in
            paymentFailed.fulfill()
        }
        startViewController(testConfiguration: testConfiguration)
        waitForWebViewLoaded()
        
        webView.evaluateJavaScript("webkit.messageHandlers.\(SwedbankPayWebContent.scriptMessageHandlerName).postMessage({msg:'\(SwedbankPayWebContent.PaymentEvent.onError)'})", completionHandler: nil)
        waitForExpectations(timeout: timeout, handler: nil)
    }
    func testItShouldReportFailureAfterOnError() {
        testItShouldReportFailureAfterOnError(testConfiguration: .merchantBackend)
    }
    func testItShouldReportFailureAfterOnErrorAsync() throws {
        try testItShouldReportFailureAfterOnError(testConfiguration: .getAsyncConfigOrSkipTest())
    }
}

private extension TestConfiguration {
    func setupPaymentorders(testCase: XCTestCase) {
        switch self {
        case .merchantBackend:
            MockURLProtocol.stubBackendUrl(for: testCase)
            MockURLProtocol.stubPaymentorders(for: testCase)
            
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
