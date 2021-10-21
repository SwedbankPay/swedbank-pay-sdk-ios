import XCTest
import WebKit
@testable import SwedbankPaySDK

private func mockAttemptOpenUniversalLink(_: URL, completionHandler: (Bool) -> Void) {
    completionHandler(false)
}

class SwedbankPaySDKControllerTestCase : XCTestCase {
    private let webviewLoadingTimeout = 5 as TimeInterval
    
    private var window: UIWindow?
    
    var viewController: SwedbankPaySDKController! {
        get {
            window?.rootViewController as? SwedbankPaySDKController
        }
        set {
            assert(window == nil, "viewController already set in this test")
            let window = UIWindow()
            self.window = window
            newValue.delegate = _delegate
            window.rootViewController = newValue
            window.isHidden = false
            
            // Mock UIApplication.open(_:options:completionHandler:)
            // to always fail on universal links, as UIApplication will not
            // call the completionHandler in tests, which ultimately results
            // in WKWebView throwing an exception.
            webViewController.attemptOpenUniversalLink = mockAttemptOpenUniversalLink
        }
    }
    
    private var _delegate: TestDelegate?
    var delegate: TestDelegate {
        if let delegate = _delegate {
            return delegate
        } else {
            let delegate = TestDelegate()
            _delegate = delegate
            viewController?.delegate = delegate
            return delegate
        }
    }
    func replaceViewController(viewController: SwedbankPaySDKController) {
        assert(window != nil, "viewController not yet set in this test")
        self.viewController.delegate = nil
        viewController.delegate = _delegate
        window!.rootViewController = viewController
        webViewController.attemptOpenUniversalLink = mockAttemptOpenUniversalLink
    }
    
    var webViewController: SwedbankPayWebViewController {
        viewController.loadViewIfNeeded()
        return viewController.children.lazy.compactMap { $0 as? SwedbankPayWebViewController }.first!
    }
    var webView: WKWebView {
        return webViewController.view as! WKWebView
    }
    
    override func tearDown() {
        _delegate = nil
        window?.rootViewController = nil
        window?.removeFromSuperview()
        window = nil
        
        MockURLProtocol.reset()
    }
    
    func waitForWebViewLoaded() {
        let webView = self.webView
        let loadingStarted = XCTKVOExpectation(keyPath: #keyPath(WKWebView.isLoading), object: webView, expectedValue: true)
        wait(for: [loadingStarted], timeout: webviewLoadingTimeout)
        let loadingFinished = XCTKVOExpectation(keyPath: #keyPath(WKWebView.isLoading), object: webView, expectedValue: false)
        wait(for: [loadingFinished], timeout: webviewLoadingTimeout)
    }
    
    func expectEmptyWebView() -> XCTestExpectation {
        let expectation = self.expectation(description: "empty page loaded in web view")
        webView.evaluateJavaScript("document.evaluate('count(//script)', document, null, XPathResult.NUMBER_TYPE).numberValue") { count, error in
            XCTAssertNil(error)
            if count as? Int == 0 {
                expectation.fulfill()
            }
        }
        return expectation
    }
    
    func expectViewConsumerIdentificationPageInWebView() {
        let expectation = self.expectation(description: "view-consumer-identification page loaded in web view")
        webView.evaluateJavaScript("document.evaluate('//script[1]', document, null, XPathResult.ANY_UNORDERED_NODE_TYPE).singleNodeValue.textContent") { script, error in
            XCTAssertNil(error)
            if let s = script as? String, s.contains("var url = '\(TestConstants.viewConsumerSessionLink)'") && s.contains("payex.hostedView.consumer(") {
                expectation.fulfill()
            }
        }
    }
    
    @discardableResult
    func expectViewPaymentorderPageInWebView() -> XCTestExpectation {
        let expectation = self.expectation(description: "view-paymentorder page loaded in web view")
        webView.evaluateJavaScript("document.evaluate('//script[1]', document, null, XPathResult.ANY_UNORDERED_NODE_TYPE).singleNodeValue.textContent") { script, error in
            XCTAssertNil(error)
            if let s = script as? String, s.contains("var url = '\(TestConstants.viewPaymentorderLink)'") && s.contains("payex.hostedView.paymentMenu(") {
                expectation.fulfill()
            }
        }
        return expectation
    }
        
    class TestDelegate : SwedbankPaySDKDelegate {
        var onComplete: (() -> Void)?
        var onFailed: ((Error) -> Void)?
        
        func paymentComplete() {
            onComplete?()
        }
        func paymentCanceled() {}
        func paymentFailed(error: Error) {
            onFailed?(error)
        }
    }
}
