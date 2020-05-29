import XCTest
import WebKit
@testable import SwedbankPaySDK

class ViewControllerConsumerTests : SwedbankPaySDKControllerTestCase {
    private let timeout = 1 as TimeInterval
    
    override func createController() -> SwedbankPaySDKController {
        return SwedbankPaySDKController(configuration: TestConstants.configuration, consumer: TestConstants.consumerData, paymentOrder: TestConstants.paymentOrder)
    }
    
    func testItShouldStartWithoutCrashing() {
        startViewController()
        MockURLProtocol.assertNoUnusedStubs()
    }
    
    func testItShouldShowViewConsumerIdentificationPage() {
        MockURLProtocol.stubBackendUrl()
        MockURLProtocol.stubConsumers()
        startViewController()
        waitForWebViewLoaded()
        
        let expectation = self.expectation(description: "view-consumer-identification page loaded in web view")
        webView.evaluateJavaScript("document.evaluate('//script[1]', document, null, XPathResult.ANY_UNORDERED_NODE_TYPE).singleNodeValue.textContent") { script, error in
            XCTAssertNil(error)
            if let s = script as? String, s.contains("var url = '\(TestConstants.viewConsumerSessionLink)'") && s.contains("payex.hostedView.consumer(") {
                expectation.fulfill()
            }
        }
        waitForExpectations(timeout: timeout, handler: nil)
        
        MockURLProtocol.assertNoUnusedStubs()
    }
    
    func testItShouldMakePostRequestToPaymentOrdersUrlAfterIdentificationSuccess() {
        MockURLProtocol.stubBackendUrl()
        MockURLProtocol.stubConsumers()
        
        startViewController()
        waitForWebViewLoaded()
        
        let onConsumerIdentifiedCalled = expectation(description: "consumerProfileRef set in viewModel")
        webView.evaluateJavaScript("webkit.messageHandlers.\(SwedbankPayWebContent.scriptMessageHandlerName).postMessage({msg:'\(SwedbankPayWebContent.ConsumerEvent.onConsumerIdentified)',arg:'\(TestConstants.consumerProfileRef)'})") { _, _ in
            onConsumerIdentifiedCalled.fulfill()
        }
        
        expectRequest(to: TestConstants.absolutePaymentordersUrl, expectedRequest: .postJson({
            let paymentorder = $0["paymentorder"]
            let paymentorderObj = try XCTUnwrap(paymentorder as? [String : Any])
            let payer = paymentorderObj["payer"]
            let payerObj = try XCTUnwrap(payer as? [String : Any])
            let profile = payerObj["consumerProfileRef"]
            let profileString = try XCTUnwrap(profile as? String)
            XCTAssertEqual(profileString, TestConstants.consumerProfileRef)
        }))
        waitForExpectations(timeout: timeout, handler: nil)
        
        MockURLProtocol.assertNoUnusedStubs()
    }
    
    func testItShouldShowViewPaymentorderPageAfterIdentificationSuccess() {
        MockURLProtocol.stubBackendUrl()
        MockURLProtocol.stubConsumers()
        MockURLProtocol.stubPaymentorders()
        
        startViewController()
        waitForWebViewLoaded()
        
        webView.evaluateJavaScript("webkit.messageHandlers.\(SwedbankPayWebContent.scriptMessageHandlerName).postMessage({msg:'\(SwedbankPayWebContent.ConsumerEvent.onConsumerIdentified)',arg:'\(TestConstants.consumerProfileRef)'})", completionHandler: nil)
        waitForWebViewLoaded()
        
        expectViewPaymentorderPageInWebView()
        waitForExpectations(timeout: timeout, handler: nil)
        
        MockURLProtocol.assertNoUnusedStubs()
    }
    
    func testItShouldReportFailureAfterConsumerError() {
        MockURLProtocol.stubBackendUrl()
        MockURLProtocol.stubConsumers()
        
        let paymentFailed = expectation(description: "Payment failed")
        delegate.onFailed = { _ in
            paymentFailed.fulfill()
        }
        startViewController()
        waitForWebViewLoaded()
        
        webView.evaluateJavaScript("webkit.messageHandlers.\(SwedbankPayWebContent.scriptMessageHandlerName).postMessage({msg:'\(SwedbankPayWebContent.ConsumerEvent.onError)'})", completionHandler: nil)
        waitForExpectations(timeout: timeout, handler: nil)
        
        MockURLProtocol.assertNoUnusedStubs()
    }
    
}
