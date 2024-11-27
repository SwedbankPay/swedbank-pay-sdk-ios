//
// Copyright 2024 Swedbank AB
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

class SwedbankPaySCAWebViewController: UIViewController {
    internal var lastRootPage: (navigation: WKNavigation?, baseURL: URL?)?

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
        redirectLog?.append((url, note, Date()))
    }

    var isAtRoot: Bool {
        return lastRootPage != nil
    }

    var attemptOpenUniversalLink: (URL, @escaping (Bool) -> Void) -> Void = { url, completionHandler in
        UIApplication.shared.open(url, options: [.universalLinksOnly: true], completionHandler: completionHandler)
    }

    private var handler: ((Result<String, Error>) -> Void)?

    let webView: WKWebView

    let activityView = UIActivityIndicatorView()

    var notificationUrl: String?

    init() {
        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true
        let config = WKWebViewConfiguration()
        config.preferences = preferences
        webView = WKWebView(frame: .zero, configuration: config)

        super.init(nibName: nil, bundle: nil)
        webView.navigationDelegate = self
        webView.addSubview(activityView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        self.view = webView
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        activityView.center = webView.center
    }

    func load(task: IntegrationTask, handler: @escaping (Result<String, Error>) -> Void) {
        guard let taskHref = task.href,
              let url = URL(string: taskHref) else {
            return
        }

        self.activityView.startAnimating()
        self.activityView.isHidden = true

        self.handler = handler

        var request = URLRequest(url: url)
        request.httpMethod = task.method
        request.allHTTPHeaderFields = ["Content-Type": task.contentType ?? ""]
        request.timeoutInterval = SwedbankPayAPIConstants.creditCardTimoutInterval

        if let httpBody = task.expects?.httpBody {
            request.httpBody = httpBody
        }

        let navigation = webView.load(request)

        lastRootPage = (navigation, url)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if self.activityView.isAnimating {
                self.activityView.isHidden = false
            }
        }
    }
}

extension SwedbankPaySCAWebViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard navigation == lastRootPage?.navigation else {
            return
        }

        activityView.isHidden = true
        activityView.stopAnimating()
    }


    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard navigation == lastRootPage?.navigation else {
            return
        }

        activityView.isHidden = true
        activityView.stopAnimating()

        handler?(.failure(error))
        handler = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard navigation == lastRootPage?.navigation else {
            return
        }

        activityView.isHidden = true
        activityView.stopAnimating()

        handler?(.failure(error))
        handler = nil
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        let request = navigationAction.request

        if request.url?.absoluteString == self.notificationUrl,
           let httpBody = request.httpBody,
           let bodyString = String(data: httpBody, encoding: .utf8),
           let urlComponents = URLComponents(string: "https://www.apple.com?\(bodyString)"),
           let cRes = urlComponents.queryItems?.first(where: { $0.name == "cres" })?.value {
            navigationLog(request.url, "Link CRes")
            self.handler?(.success(cRes))
            self.handler = nil
            decisionHandler(.allow)
        } else if isBaseUrlNavigation(navigationAction: navigationAction) {
            navigationLog(request.url, "Link isBaseUrlNavigation")
            decisionHandler(.allow)
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
        if WKWebView.canOpen(url: url) {
            if navigationAction.targetFrame == nil {
                navigationLog(url, "Link with no targetFrame, opened in webview")
                decisionHandler(.allow) // always allow new frame navigations
            } else {
                self.navigationLog(url, "Link opened in webview")
                decisionHandler(.allow)
            }
        } else {
            // A custom-scheme url. Must let another app take care of it.
            navigationLog(url, "Custom-scheme url opened in another app")
            UIApplication.shared.open(url, options: [:])
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
        UIApplication.shared.open(target, options: [:])
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
}
