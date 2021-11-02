//
// Copyright 2019 Swedbank AB
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit
import WebKit

final class SwedbankPayWebViewController: SwedbankPayWebViewControllerBase {
    private var lastRootPage: (navigation: WKNavigation?, baseURL: URL?)?

    var navigationLogger: ((URL) -> Void)?

    var isAtRoot: Bool {
        return lastRootPage != nil
    }
    
    private enum ProcessHost {
        case webView
        case browser
    }
    
    private var processHost = ProcessHost.webView {
        didSet {
            wrangleProcessHostAlert()
        }
    }

    override init(
        configuration: WKWebViewConfiguration,
        delegate: SwedbankPayWebViewControllerDelegate
    ) {
        super.init(configuration: configuration, delegate: delegate)
        webView.navigationDelegate = self
    }
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func appDidBecomeActive() {
        wrangleProcessHostAlert()
    }

    func load(htmlString: String, baseURL: URL?) {
        processHost = .webView
        dismissJavascriptDialog()
        let navigation = webView.loadHTMLString(htmlString, baseURL: baseURL)
        lastRootPage = (navigation, baseURL)
    }
}

extension SwedbankPayWebViewController: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        let request = navigationAction.request
        
        if isBaseUrlNavigation(navigationAction: navigationAction) {
            decisionHandler(.allow)
        } else if delegate?.overrideNavigation(request: request) == true {
            decisionHandler(.cancel)
        } else if let url = request.url {
            // If targetFrame is nil, this is a new window navigation;
            // handle like a main frame navigation.
            if navigationAction.targetFrame?.isMainFrame != false {
                navigationLogger?(url)
                decidePolicyFor(navigationAction: navigationAction, url: url, decisionHandler: decisionHandler)
            } else {
                let canOpen = WKWebView.canOpen(url: url)
                decisionHandler(canOpen ? .allow : .cancel)
            }
        } else {
            decisionHandler(.cancel)
        }
    }
    
    private func decidePolicyFor(
        navigationAction: WKNavigationAction,
        url: URL,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        attemptOpenUniversalLink(url) { opened in
            if opened {
                decisionHandler(.cancel)
            } else {
                self.decidePolicyForNormalLink(
                    navigationAction: navigationAction,
                    url: url,
                    decisionHandler: decisionHandler
                )
            }
        }
    }
    
    private func decidePolicyForNormalLink(
        navigationAction: WKNavigationAction,
        url: URL,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if WKWebView.canOpen(url: url), let delegate = delegate {
            if navigationAction.targetFrame == nil {
                decisionHandler(.allow) // always allow new frame navigations
            } else {
                // A regular http(s) url. Check if it matches the list of
                // tested working pages.
                delegate.allowWebViewNavigation(navigationAction: navigationAction) { allowed in
                    if !allowed {
                        // Not tested or incompatible with web view;
                        // must continue process is Safari.
                        self.continueNavigationInBrowser(url: url)
                    }
                    decisionHandler(allowed ? .allow : .cancel)
                }
            }
        } else {
            // A custom-scheme url. Must let another app take care of it.
            UIApplication.shared.open(url, options: [:])
            decisionHandler(.cancel)
        }
    }
    
    private func continueNavigationInBrowser(url: URL) {
        // Naively, one would think that opening the original navigation
        // target here would work. However, testing has shown that not
        // to be the case. Without expending time to work out the exact
        // problem, it can be assumed that the Swedbank Pay page that
        // redirects to the payment instrument issuer page sets up
        // the browser environment in some way that some issuer pages
        // depend on. Therefore the approach is that when we encounter
        // a navigation to a page outside the goodlist, we reopen the
        // _current_ page in the browser. This works for the Swedbank Pay
        // "PrepareAcsChallenge" page, and it can be assumed that it will
        // continue to work for that page. Whether it works if any previously
        // tested flow is changed to navigate to previously unknown pages
        // is anyone's guess, but even in those cases it is the best we can
        // do, since attempting to restart the whole flow by opening the
        // "originating" Swedbank Pay page will, in general not work
        // (this has been tested). In any case, it is important to
        // keep testing the SDK against different issuers and keep
        // the goodlist up-to-date.
        let target = isAtRoot ? url : (webView.url ?? url)
        UIApplication.shared.open(target, options: [:]) { opened in
            if opened {
                self.processHost = .browser
            }
        }
    }
    
    private func ensurePath(url: URL) -> URL {
        return url.path.isEmpty ? URL(string: "/", relativeTo: url)!.absoluteURL : url.absoluteURL
    }
    
    private func isBaseUrlNavigation(navigationAction: WKNavigationAction) -> Bool {
        if let lastRootPage = lastRootPage, navigationAction.targetFrame?.isMainFrame == true {
            let url = navigationAction.request.url
            if let baseUrl = lastRootPage.baseURL {
                // WKWebView silently turns https://foo.bar to https://foo.bar/
                // So append a path to baseURL if needed
                let baseUrlWithPath = ensurePath(url: baseUrl)
                return navigationAction.request.url?.absoluteURL == baseUrlWithPath
            } else {
                // A nil baseURL results in WKWebView using about:blank as the page url instead
                return url?.absoluteString == "about:blank"
            }
        } else {
            return false
        }
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        // Assume the payment is processing in the web view whenever there is a new navigation.
        processHost = .webView
        if navigation != lastRootPage?.navigation {
            lastRootPage = nil
            delegate?.webViewControllerDidNavigateOutOfRoot(self)
        }
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        delegate?.webViewDidFailNavigation(error: error)
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        delegate?.webViewDidFailNavigation(error: error)
    }
}

extension SwedbankPayWebViewController {
    // visible for testing
    func wrangleProcessHostAlert() {
        // Give JS alerts priority over these.
        // This should really never be an issue,
        // but we'd rather not crash if it somehow happens.
        let presentedVC = presentedViewController
        guard presentedVC == nil || (presentedVC as? UIAlertController)?.isProcessHostAlertController == true else {
            return
        }
        
        presentedVC?.dismiss(animated: true, completion: nil)
        let alert = makeProcessHostAlert()
        if let alert = alert {
            alert.isProcessHostAlertController = true
            present(alert, animated: true, completion: nil)
        }
    }
    
    private func makeProcessHostAlert() -> UIAlertController? {
        switch processHost {
        case .webView:
            return nil
        case .browser:
            return makeBrowserAlert()
        }
    }
    
    private func makeBrowserAlert() -> UIAlertController {
        let alert = UIAlertController(
            title: SwedbankPaySDKResources.localizedString(key: "browserAlertTitle"),
            message: SwedbankPaySDKResources.localizedString(key: "browserAlertBody"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        return alert
    }
}

private extension UIAlertController {
    private static var isProcessHostControllerKey: Void = ()
    var isProcessHostAlertController: Bool {
        get {
            objc_getAssociatedObject(self, &Self.isProcessHostControllerKey) as? Bool == true
        }
        set {
            objc_setAssociatedObject(self, &Self.isProcessHostControllerKey, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
}
