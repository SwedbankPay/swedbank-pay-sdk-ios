import XCTest
import WebKit
@testable import SwedbankPaySDK

class PaymentUrlTests : SwedbankPaySDKControllerTestCase {
    private let timeout = 5 as TimeInterval
    
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
    
    private func testPaymentUrl(testConfiguration: TestConfiguration, invokePaymentUrl: () -> Void) {
        testConfiguration.setup()
        
        var paymentOrder = TestConstants.paymentOrder
        paymentOrder.urls.paymentUrl = originalPaymentUrl
        
        viewController = SwedbankPaySDKController(
            configuration: testConfiguration.sdkConfiguration,
            paymentOrder: paymentOrder
        )
        waitForWebViewLoaded()
        wait(for: [expectViewPaymentorderPageInWebView()], timeout: timeout)
        
        webView.evaluateJavaScript("window.location = 'about:blank'", completionHandler: nil)
        waitForWebViewLoaded()
        wait(for: [expectEmptyWebView()], timeout: timeout)
        
        invokePaymentUrl()
        waitForWebViewLoaded()
        wait(for: [expectViewPaymentorderPageInWebView()], timeout: timeout)
        
        testConfiguration.teardown()
    }
    
    private func testOpen(testConfiguration: TestConfiguration, url: URL) {
        testPaymentUrl(testConfiguration: testConfiguration) {
            _ = SwedbankPaySDK.open(url: url)
        }
    }
    
    private func testContinueUserActivity(testConfiguration: TestConfiguration, url: URL) {
        let userActivity = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
        userActivity.webpageURL = url
        testPaymentUrl(testConfiguration: testConfiguration) {
            _ = SwedbankPaySDK.continue(userActivity: userActivity)
        }
    }
    
    func testOpenOriginalPaymentUrl() {
        testOpen(testConfiguration: .merchantBackend, url: originalPaymentUrl)
    }
    func testOpenOriginalPaymentUrlAsync() throws {
        try testOpen(testConfiguration: .getAsyncConfigOrSkipTest(), url: originalPaymentUrl)
    }
    
    func testContinueUserActivityOriginalPaymentUrl() {
        testContinueUserActivity(testConfiguration: .merchantBackend, url: originalPaymentUrl)
    }
    func testContinueUserActivityOriginalPaymentUrlAsync() throws {
        try testContinueUserActivity(testConfiguration: .getAsyncConfigOrSkipTest(), url: originalPaymentUrl)
    }
    
    func testOpenAugmentedPaymentUrl() {
        testOpen(testConfiguration: .merchantBackend, url: augmentedPaymentUrl)
    }
    func testOpenAugmentedPaymentUrlAsync() throws {
        try testOpen(testConfiguration: .getAsyncConfigOrSkipTest(), url: augmentedPaymentUrl)
    }
    
    func testContinueUserActivityAugmentedPaymentUrl() {
        testContinueUserActivity(testConfiguration: .merchantBackend, url: augmentedPaymentUrl)
    }
    func testContinueUserActivityAugmentedPaymentUrlAsync() throws {
        try testContinueUserActivity(testConfiguration: .getAsyncConfigOrSkipTest(), url: augmentedPaymentUrl)
    }
    
    func testOpenCustomSchemePaymentUrl() {
        testOpen(testConfiguration: .merchantBackend, url: customSchemePaymentUrl)
    }
    func testOpenCustomSchemePaymentUrlAsync() throws {
        try testOpen(testConfiguration: .getAsyncConfigOrSkipTest(), url: customSchemePaymentUrl)
    }
    
    func testOpenAugmentedCustomSchemePaymentUrl() {
        testOpen(testConfiguration: .merchantBackend, url: augmentedCustomSchemePaymentUrl)
    }
    func testOpenAugmentedCustomSchemePaymentUrlAsync() throws {
        try testOpen(testConfiguration: .getAsyncConfigOrSkipTest(), url: augmentedCustomSchemePaymentUrl)
    }
}

private extension TestConfiguration {
    func setup() {
        switch self {
        case .merchantBackend:
            MockURLProtocol.stubBackendUrl()
            MockURLProtocol.stubPaymentorders()
            
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
