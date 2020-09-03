import XCTest
import WebKit
@testable import SwedbankPaySDK

class SwedbankPaySDKControllerTestCase : XCTestCase {
    private static var webKitPrewarmed = false
    private static func prewarmWebKit() {
        if !webKitPrewarmed {
            let window = UIWindow()
            window.addSubview(WKWebView(frame: window.bounds))
            window.isHidden = false
            webKitPrewarmed = true
        }
    }
    
    private let webviewLoadingTimeout = 5 as TimeInterval
    
    private var window: UIWindow?
    
    var viewController: SwedbankPaySDKController! {
        window?.rootViewController as? SwedbankPaySDKController
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
    
    var webViewController: SwedbankPayWebViewController {
        viewController.loadViewIfNeeded()
        return viewController.children.lazy.compactMap { $0 as? SwedbankPayWebViewController }.first!
    }
    var webView: WKWebView {
        return webViewController.view as! WKWebView
    }
    
    override func setUp() {
        SwedbankPaySDKControllerTestCase.prewarmWebKit()
        SwedbankPaySDKViewModel.overrideUrlSessionConfigurationForTests = MockURLProtocol.urlSessionConfiguration
    }
    
    override func tearDown() {
        _delegate = nil
        window?.rootViewController = nil
        window?.removeFromSuperview()
        window = nil
        
        SwedbankPaySDKViewModel.overrideUrlSessionConfigurationForTests = nil
        MockURLProtocol.reset()
    }
    
    func createController() -> SwedbankPaySDKController {
        fatalError("Subclass must override createController")
    }
    
    func startViewController() {
        assert(window == nil, "View Controller already started in this test")
        let window = UIWindow()
        self.window = window
        let viewController = createController()
        viewController.delegate = _delegate
        window.rootViewController = viewController
        window.isHidden = false
        
        // Mock UIApplication.open(_:options:completionHandler:)
        // to always fail on universal links, as UIApplication will not
        // call the completionHandler in tests, which ultimately results
        // in WKWebView throwing an exception.
        webViewController.attemptOpenUniversalLink = { _, completionHandler in completionHandler(false) }
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
        var onFailed: ((SwedbankPaySDKController.FailureReason) -> Void)?
        
        func paymentComplete() {
            onComplete?()
        }
        func paymentCanceled() {}
        func paymentFailed(failureReason: SwedbankPaySDKController.FailureReason) {
            onFailed?(failureReason)
        }
    }
}
