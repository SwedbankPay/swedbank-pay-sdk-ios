//
//  SwedbankPayWebViewController.swift
//  SwedbankPaySDK
//
//  Created by Pertti Kroger on 12.12.2019.
//  Copyright © 2019 Swedbank. All rights reserved.
//

import UIKit
import WebKit

protocol SwedbankPayWebViewControllerDelegate : class {
    func add(webViewController: SwedbankPayWebViewController)
    func remove(webViewController: SwedbankPayWebViewController)
    func overrideNavigation(request: URLRequest) -> Bool
    func webViewControllerDidNavigateOutOfRoot(_ webViewController: SwedbankPayWebViewController)
}

class SwedbankPayWebViewController : UIViewController {
    private weak var delegate: SwedbankPayWebViewControllerDelegate?
    
    private let webView: WKWebView
    private var lastRootNavigation: WKNavigation?
    
    var isAtRoot: Bool {
        return lastRootNavigation != nil
    }
    
    init(configuration: WKWebViewConfiguration, delegate: SwedbankPayWebViewControllerDelegate) {
        webView = WKWebView(frame: .zero, configuration: configuration)
        self.delegate = delegate
        super.init(nibName: nil, bundle: nil)
        webView.navigationDelegate = self
        webView.uiDelegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    override func loadView() {
        self.view = webView
    }
    
    func load(htmlString: String, baseURL: URL?) {
        lastRootNavigation = webView.loadHTMLString(htmlString, baseURL: baseURL)
    }
}

extension SwedbankPayWebViewController : WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let handledByDelegate = navigationAction.targetFrame?.isMainFrame == true
            && delegate?.overrideNavigation(request: navigationAction.request) == true
        if handledByDelegate {
            decisionHandler(.cancel)
        } else {
            attemptOpenExternalApp(request: navigationAction.request) { openedInExternalApp in
                let policy: WKNavigationActionPolicy = openedInExternalApp ? .cancel : .allow
                decisionHandler(policy)
            }
        }
    }
    
    private func attemptOpenExternalApp(request: URLRequest, completionHandler: @escaping (Bool) -> Void) {
        guard let url = request.url, let scheme = url.scheme, scheme != "http" && scheme != "https" else {
            completionHandler(false)
            return
        }
        
        if #available(iOS 10, *) {
            UIApplication.shared.open(url, options: [:], completionHandler: completionHandler)
        } else {
            let success = UIApplication.shared.openURL(url)
            completionHandler(success)
        }
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        if navigation != lastRootNavigation {
            lastRootNavigation = nil
            delegate?.webViewControllerDidNavigateOutOfRoot(self)
        }
    }
}

extension SwedbankPayWebViewController : WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard let delegate = delegate,
            !delegate.overrideNavigation(request: navigationAction.request)
            else {
                return nil
        }
        
        let viewController = SwedbankPayWebViewController(configuration: configuration, delegate: delegate)
        delegate.add(webViewController: viewController)
        let webView = viewController.webView
        webView.load(navigationAction.request)
        return webView
    }
    
    func webViewDidClose(_ webView: WKWebView) {
        delegate?.remove(webViewController: self)
    }
}
