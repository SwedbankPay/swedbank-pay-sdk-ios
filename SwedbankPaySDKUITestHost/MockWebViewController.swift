//
//  MockWebViewController.swift
//  SwedbankPaySDKUITestHost
//
//  Created by Olof Thorén on 2022-11-07.
//

import Foundation
import WebKit
@testable import SwedbankPaySDK

///To mock the webViewController we need to also mock the SwedbankPaySDKController in order for it to get loaded. This subclass changes only that behaviour
class MockSwedbankPaySDKController: SwedbankPaySDKController {
    override func createRootWebViewController() -> SwedbankPayWebViewController {
        let config = WKWebViewConfiguration()
        config.userContentController = userContentController
        return MockWebViewController(configuration: config, delegate: self)
    }
}

///Mock the internal webview to test certain redirect mechanisms.
class MockWebViewController: SwedbankPayWebViewController {
    
    ///After initial load, load any random URL to trigger redirect
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let testURL = URL(string: "https://aggressive.se")!
        self.webView.load(URLRequest(url: testURL))
    }
    
    /// show the alert at once during testing
    override internal func earliestMaybeStuckDate(_ openDate: Date) -> Date {
        openDate
    }
    
    /// Simulate opening of external app when an external URL wants to load - and cancel it.
    override func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        let request = navigationAction.request
        
        if isBaseUrlNavigation(navigationAction: navigationAction) {
            navigationLog(request.url, "Link isBaseUrlNavigation")
            decisionHandler(.allow)
        } else if delegate?.overrideNavigation(request: request) == true {
            decisionHandler(.cancel)
        } else if let url = request.url {
            
            if navigationAction.targetFrame?.isMainFrame != false {
                
                // its an external URL unknown to the SDK, simulate opening in browser.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.navigationLog(url, "Random url opened in browser")
                    self.processHost = .externalApp(openDate: Date())
                }
                decisionHandler(.cancel)
                
            } else {
                let canOpen = WKWebView.canOpen(url: url)
                navigationLog(url, "New window navigation, \(canOpen ? "allowed" : "cancelled")")
                decisionHandler(canOpen ? .allow : .cancel)
            }
        } else {
            decisionHandler(.cancel)
        }
    }
}
