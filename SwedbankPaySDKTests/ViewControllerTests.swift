import XCTest
import WebKit
@testable import SwedbankPaySDK

class ViewControllerTests : SwedbankPaySDKControllerTestCase {
    private let timeout = 5 as TimeInterval
    
    override func createController() -> SwedbankPaySDKController {
        return SwedbankPaySDKController(configuration: TestConstants.configuration, paymentOrder: TestConstants.paymentOrder)
    }
    
    func testItShouldStartWithoutCrashing() {
        startViewController()
        MockURLProtocol.assertNoUnusedStubs()
    }
    
    func testItShouldShowViewPaymentorderPage() {
        MockURLProtocol.stubBackendUrl()
        MockURLProtocol.stubPaymentorders()
        startViewController()
        waitForWebViewLoaded()
        
        expectViewPaymentorderPageInWebView()
        waitForExpectations(timeout: timeout, handler: nil)
        
        MockURLProtocol.assertNoUnusedStubs()
    }
    
    func testItShouldReportSuccessAfterNavigationToCompleteUrl() {
        MockURLProtocol.stubBackendUrl()
        MockURLProtocol.stubPaymentorders()
        let paymentCompleted = expectation(description: "Payment completed")
        delegate.onComplete = {
            paymentCompleted.fulfill()
        }
        startViewController()
        waitForWebViewLoaded()
        
        webView.evaluateJavaScript("window.location = '\(TestConstants.paymentOrder.urls.completeUrl.absoluteString)'", completionHandler: nil)
        waitForExpectations(timeout: timeout, handler: nil)
        
        MockURLProtocol.assertNoUnusedStubs()
    }
    
    func testItShouldReloadViewPaymentorderPageWhenItNavigatesToPaymentUrl() {
        MockURLProtocol.stubBackendUrl()
        MockURLProtocol.stubPaymentorders()
        
        startViewController()
        waitForWebViewLoaded()
        wait(for: [expectViewPaymentorderPageInWebView()], timeout: timeout)
        
        webView.evaluateJavaScript("window.location = 'about:blank'", completionHandler: nil)
        waitForWebViewLoaded()
        wait(for: [expectEmptyWebView()], timeout: timeout)
        
        webView.evaluateJavaScript("window.location = '\(TestConstants.paymentOrder.urls.paymentUrl!.absoluteString)'", completionHandler: nil)
        waitForWebViewLoaded()
        wait(for: [expectViewPaymentorderPageInWebView()], timeout: timeout)
        
        MockURLProtocol.assertNoUnusedStubs()
    }
    
    func testItShouldReportFailureAfterOnError() {
        MockURLProtocol.stubBackendUrl()
        MockURLProtocol.stubPaymentorders()
        
        let paymentFailed = expectation(description: "Payment failed")
        delegate.onFailed = { _ in
            paymentFailed.fulfill()
        }
        startViewController()
        waitForWebViewLoaded()
        
        webView.evaluateJavaScript("webkit.messageHandlers.\(SwedbankPayWebContent.scriptMessageHandlerName).postMessage({msg:'\(SwedbankPayWebContent.PaymentEvent.onError)'})", completionHandler: nil)
        waitForExpectations(timeout: timeout, handler: nil)
        
        MockURLProtocol.assertNoUnusedStubs()
    }
}
