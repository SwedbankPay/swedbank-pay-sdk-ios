import XCTest
import WebKit
@testable import SwedbankPaySDK

class PaymentUrlTests : SwedbankPaySDKControllerTestCase {
    private let timeout = 1 as TimeInterval
    
    private func makePaymentUrl(scheme: String, extraQueryItems: [URLQueryItem]? = nil) -> URL {
        var paymentUrl = URLComponents(url: TestConstants.paymentOrder.urls.paymentUrl!, resolvingAgainstBaseURL: true)!
        paymentUrl.scheme = scheme
        if let extraQueryItems = extraQueryItems {
            var query = paymentUrl.queryItems ?? []
            query += extraQueryItems
            paymentUrl.queryItems = query
        }
        return paymentUrl.url!
    }
    
    private var originalPaymentUrl: URL {
        // need to use https for paymentUrl scheme to test SwedbankPaySDK.continue(userActivity:)
        makePaymentUrl(scheme: "https")
    }
    private var augmentedPaymentUrl: URL {
        makePaymentUrl(scheme: "https", extraQueryItems: [.init(name: "foo", value: "bar")])
    }
    private var customSchemePaymentUrl: URL {
        makePaymentUrl(scheme: TestConstants.callbackScheme)
    }
    private var augmentedCustomSchemePaymentUrl: URL {
        makePaymentUrl(scheme: TestConstants.callbackScheme, extraQueryItems: [.init(name: "foo", value: "bar")])
    }
    
    override func createController() -> SwedbankPaySDKController {
        var paymentOrder = TestConstants.paymentOrder
        paymentOrder.urls.paymentUrl = originalPaymentUrl
        return SwedbankPaySDKController(configuration: TestConstants.configuration, paymentOrder: paymentOrder)
    }
    
    private func testPaymentUrl(invokePaymentUrl: () -> Void) {
        MockURLProtocol.stubBackendUrl()
        MockURLProtocol.stubPaymentorders()
        
        startViewController()
        waitForWebViewLoaded()
        wait(for: [expectViewPaymentorderPageInWebView()], timeout: timeout)
        
        webView.evaluateJavaScript("window.location = 'about:blank'", completionHandler: nil)
        waitForWebViewLoaded()
        wait(for: [expectEmptyWebView()], timeout: timeout)
        
        invokePaymentUrl()
        waitForWebViewLoaded()
        wait(for: [expectViewPaymentorderPageInWebView()], timeout: timeout)
        
        MockURLProtocol.assertNoUnusedStubs()
    }
    
    private func testOpen(url: URL) {
        testPaymentUrl {
            _ = SwedbankPaySDK.open(url: url)
        }
    }
    
    private func testContinueUserActivity(url: URL) {
        let userActivity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
        userActivity.webpageURL = url
        testPaymentUrl {
            _ = SwedbankPaySDK.continue(userActivity: userActivity)
        }
    }
    
    func testOpenOriginalPaymentUrl() {
        testOpen(url: originalPaymentUrl)
    }
    
    func testContinueUserActivityOriginalPaymentUrl() {
        testContinueUserActivity(url: originalPaymentUrl)
    }
    
    func testOpenAugmentedPaymentUrl() {
        testOpen(url: augmentedPaymentUrl)
    }
    
    func testContinueUserActivityAugmentedPaymentUrl() {
        testContinueUserActivity(url: augmentedPaymentUrl)
    }
    
    func testOpenCustomSchemePaymentUrl() {
        testOpen(url: customSchemePaymentUrl)
    }
    
    func testOpenAugmentedCustomSchemePaymentUrl() {
        testOpen(url: augmentedCustomSchemePaymentUrl)
    }
}
