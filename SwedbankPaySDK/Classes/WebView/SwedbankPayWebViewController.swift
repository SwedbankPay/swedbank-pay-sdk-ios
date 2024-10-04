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
@preconcurrency import WebKit

class SwedbankPayWebViewController: SwedbankPayWebViewControllerBase {
    internal static let maybeStuckNoteMinimumIntervalFromDidBecomeActive = 3.0
    
    internal var lastRootPage: (navigation: WKNavigation?, baseURL: URL?)?
    
    var shouldShowExternalAppAlerts = true

    //Legacy navigationLogger
    var navigationLogger: ((URL) -> Void)?
    
    /// keep track on all webView redirects and the reason for redirection. Set to activate logging (active by default in DEBUG).
    var redirectLog: [(url: URL, note: String, date: Date)]?
    
    /// print urls to log and send them to the navigationLogger
    func navigationLog(_ url: URL?, _ note: String) {
        guard let url else { return }
        #if DEBUG
        debugPrint("navigation: \(note) url: \(url.absoluteString)")
        if redirectLog == nil {
            redirectLog = .init()
        }
        #endif
        navigationLogger?(url)
        redirectLog?.append((url, note, Date()))
    }

    var isAtRoot: Bool {
        return lastRootPage != nil
    }
    
    internal enum ProcessHost {
        case webView
        case externalApp(openDate: Date)
        case browser
    }
    
    internal var processHost = ProcessHost.webView {
        didSet {
            wrangleProcessHostAlert()
        }
    }
    
    internal var wrangleProcessHostAlertTimer: Timer?
    internal func earliestMaybeStuckDate(_ openDate: Date) -> Date {
        openDate + 30.0
    }

    override init(configuration: WKWebViewConfiguration, delegate: SwedbankPayWebViewControllerDelegate) {
        
        super.init(configuration: configuration, delegate: delegate)
        webView.navigationDelegate = self
    }
    deinit {
        wrangleProcessHostAlertTimer?.invalidate()
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
    
    @objc internal func appDidBecomeActive() {
        wrangleProcessHostAlert(appDidBecomeActiveDate: Date())
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
            navigationLog(request.url, "Link isBaseUrlNavigation")
            decisionHandler(.allow)
        } else if delegate?.overrideNavigation(request: request) == true {
            decisionHandler(.cancel)
        } else if let url = request.url {
            // If targetFrame is nil, this is a new window navigation;
            // handle like a main frame navigation.
            if navigationAction.targetFrame?.isMainFrame != false {
                decidePolicyFor(navigationAction: navigationAction, url: url, decisionHandler: decisionHandler)
            } else {
                
                let canOpen = WKWebView.canOpen(url: url)
                navigationLog(url, "New window navigation, \(canOpen ? "allowed" : "cancelled")")
                decisionHandler(canOpen ? .allow : .cancel)
                if canOpen == false {
                    
                    // if link has been cancelled due to not beeing able to open, we need to open it as an external app.
                    self.navigationLog(url, "External link opened in browser or app")
                    self.processHost = .browser //since we don't know if this link is to open bankId or perform payment we can't assume it is processing a payment.
                    UIApplication.shared.open(url, options: [.universalLinksOnly: false], completionHandler: nil)
                }
                
            }
        } else {
            decisionHandler(.cancel)
        }
    }
    
    internal func decidePolicyFor(
        navigationAction: WKNavigationAction,
        url: URL,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        attemptOpenUniversalLink(url) { opened in
            if opened {
                self.navigationLog(url, "Universal link opened in browser")
                self.processHost = .externalApp(openDate: Date())
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
    
    internal func decidePolicyForNormalLink(
        navigationAction: WKNavigationAction,
        url: URL,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if WKWebView.canOpen(url: url), let delegate = delegate {
            if navigationAction.targetFrame == nil {
                navigationLog(url, "Link with no targetFrame, opened in webview")
                decisionHandler(.allow) // always allow new frame navigations
            } else {
                // A regular http(s) url. Check if it matches the list of
                // tested working pages.
                delegate.allowWebViewNavigation(navigationAction: navigationAction) { allowed in
                    if !allowed {
                        // Not tested or incompatible with web view;
                        // must continue process is Safari.
                        self.navigationLog(url, "Incompatible link opened in browser")
                        self.continueNavigationInBrowser(url: url)
                    } else {
                        self.navigationLog(url, "Link opened in webview")
                    }
                    decisionHandler(allowed ? .allow : .cancel)
                }
            }
        } else {
            // A custom-scheme url. Must let another app take care of it.
            navigationLog(url, "Custom-scheme url opened in another app")
            UIApplication.shared.open(url, options: [:]) { opened in
                if opened {
                    self.processHost = .externalApp(openDate: Date())
                }
            }
            decisionHandler(.cancel)
        }
    }
    
    internal func continueNavigationInBrowser(url: URL) {
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
    
    internal func ensurePath(url: URL) -> URL {
        return url.path.isEmpty ? URL(string: "/", relativeTo: url)!.absoluteURL : url.absoluteURL
    }
    
    internal func isBaseUrlNavigation(navigationAction: WKNavigationAction) -> Bool {
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
    func wrangleProcessHostAlert(appDidBecomeActiveDate: Date? = nil, now: @autoclosure () -> Date = Date()) {
        wrangleProcessHostAlertTimer?.invalidate()
        wrangleProcessHostAlertTimer = nil
        
        // Give JS alerts priority over these.
        // This should really never be an issue,
        // but we'd rather not crash if it somehow happens.
        let presentedVC = presentedViewController
        guard presentedVC == nil || (presentedVC as? UIAlertController)?.isProcessHostAlertController == true else {
            return
        }
        
        presentedVC?.dismiss(animated: true, completion: nil)
        let alert = makeProcessHostAlert(appDidBecomeActiveDate: appDidBecomeActiveDate, now: now)
        if let alert = alert {
            alert.isProcessHostAlertController = true
            present(alert, animated: true, completion: nil)
        }
    }
    
    internal func makeProcessHostAlert(appDidBecomeActiveDate: Date?, now: () -> Date) -> UIAlertController? {
        switch processHost {
        case .webView:
            return nil
        case .externalApp(let openDate):
            return shouldShowExternalAppAlerts
                ? wrangleExternalAppAlert(openDate: openDate, appDidBecomeActiveDate: appDidBecomeActiveDate, now: now())
                : nil
        case .browser:
            return makeBrowserAlert()
        }
    }
    
    internal func wrangleExternalAppAlert(openDate: Date, appDidBecomeActiveDate: Date?, now: Date) -> UIAlertController? {
        var earliestAlertDate = earliestMaybeStuckDate(openDate)
        if let appDidBecomeActiveDate = appDidBecomeActiveDate {
            earliestAlertDate = max(earliestAlertDate, appDidBecomeActiveDate + Self.maybeStuckNoteMinimumIntervalFromDidBecomeActive)
        }
        let interval = earliestAlertDate.timeIntervalSince(now)
        let shouldShow = interval <= 0
        if !shouldShow {
            wrangleProcessHostAlertTimer = .scheduledTimer(withTimeInterval: interval, repeats: false) { [unowned self] _ in
                self.wrangleProcessHostAlert()
            }
        }
        return shouldShow ? makeExternalAppAlert() : nil
    }
    
    internal func makeExternalAppAlert() -> UIAlertController {
        let alert = UIAlertController(
            title: SwedbankPaySDKResources.localizedString(key: "maybeStuckAlertTitle"),
            message: SwedbankPaySDKResources.localizedString(key: "maybeStuckAlertBody"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(
            title: SwedbankPaySDKResources.localizedString(key: "maybeStuckAlertWait"),
            style: .default)
        )
        alert.addAction(UIAlertAction(
            title: SwedbankPaySDKResources.localizedString(key: "maybeStuckAlertRetry"),
            style: .default
        ) { [weak self] _ in
            if let self = self {
                self.delegate?.webViewControllerRetryWithBrowserRedirectBehavior(self)
            }
        })
        return alert
    }
    
    internal func makeBrowserAlert() -> UIAlertController {
        let alert = UIAlertController(
            title: SwedbankPaySDKResources.localizedString(key: "browserAlertTitle"),
            message: SwedbankPaySDKResources.localizedString(key: "browserAlertBody"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(
            title: SwedbankPaySDKResources.localizedString(key: "OK"),
            style: .default
        ))
        return alert
    }
}

internal extension UIAlertController {
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
