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

protocol SwedbankPayWebViewControllerDelegate : class {
    func add(webViewController: SwedbankPayWebViewController)
    func remove(webViewController: SwedbankPayWebViewController)
    func overrideNavigation(request: URLRequest) -> Bool
    func webViewControllerDidNavigateOutOfRoot(_ webViewController: SwedbankPayWebViewController)
}

class SwedbankPayWebViewController : UIViewController {
    private weak var delegate: SwedbankPayWebViewControllerDelegate?
    
    private let webView: WKWebView
    private var lastRootPage: (navigation: WKNavigation?, baseURL: URL?)?
    
    private var onJavascriptDialogDismissed: (() -> Void)?
    
    // Overridable for testing, so we can mock UIApplication.open(_:options:completionHandler:)
    var attemptOpenUniversalLink: (URL, @escaping (Bool) -> Void) -> Void = { url, completionHandler in
        if #available(iOS 10, *) {
            UIApplication.shared.open(url, options: [.universalLinksOnly: true], completionHandler: completionHandler)
        } else {
            completionHandler(false)
        }
    }
    
    var navigationLogger: ((URL) -> Void)?
    
    var openRedirectsInBrowser = false
    
    var isAtRoot: Bool {
        return lastRootPage != nil
    }
    
    init(configuration: WKWebViewConfiguration, delegate: SwedbankPayWebViewControllerDelegate) {
        webView = WKWebView(frame: .zero, configuration: configuration)
        self.delegate = delegate
        super.init(nibName: nil, bundle: nil)
        webView.navigationDelegate = self
        webView.uiDelegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        self.view = webView
    }
    
    func load(htmlString: String, baseURL: URL?) {
        dismissJavascriptDialog()
        let navigation = webView.loadHTMLString(htmlString, baseURL: baseURL)
        lastRootPage = (navigation, baseURL)
    }
    
    private func showJavascriptDialog(alert: UIAlertController, onDialogDismissed: @escaping () -> Void) {
        dismissJavascriptDialog()
        self.onJavascriptDialogDismissed = onDialogDismissed
        present(alert, animated: true, completion: nil)
    }
    
    private func dismissJavascriptDialog() {
        onJavascriptDialogDismissed?()
        onJavascriptDialogDismissed = nil
        presentedViewController?.dismiss(animated: false, completion: nil)
    }
}

private extension SwedbankPayWebViewController {
    enum JavascriptDialog {
        case alert(() -> Void)
        case confirm((Bool) -> Void)
        case prompt((String?) -> Void, defaultValue: String?)
        
        func addTextField(alert: UIAlertController) {
            if case .prompt(_, let defaultValue) = self {
                alert.addTextField {
                    $0.text = defaultValue
                }
            }
        }
        
        var cancelHandler: (() -> Void)? {
            switch self {
            case .alert: return nil
            case .confirm(let handler): return { handler(false) }
            case .prompt(let handler, _): return { handler(nil) }
            }
        }
        
        func getOKHandler(alert: UIAlertController) -> () -> Void {
            switch self {
            case .alert(let handler): return handler
            case .confirm(let handler): return { handler(true) }
            case .prompt(let handler, _): return { handler(alert.textFields?.first?.text ?? "") }
            }
        }
    }
    
    func show(javascriptDialog: JavascriptDialog, message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        
        javascriptDialog.addTextField(alert: alert)
        
        let okHandler = javascriptDialog.getOKHandler(alert: alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
            self.onJavascriptDialogDismissed = nil
            okHandler()
        })
        
        let cancelHandler = javascriptDialog.cancelHandler
        if let cancelHandler = cancelHandler {
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                self.onJavascriptDialogDismissed = nil
                cancelHandler()
            })
        }
        
        showJavascriptDialog(alert: alert, onDialogDismissed: cancelHandler ?? okHandler)
    }
}

private extension WKWebView {
    static func canOpen(url: URL) -> Bool {
        let scheme = url.scheme
        if #available(iOS 11, *) {
            return scheme.map(handlesURLScheme) == true
        } else {
            return scheme == "http" || scheme == "https"
        }
    }
}

extension SwedbankPayWebViewController : WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let request = navigationAction.request
        
        if isBaseUrlNavigation(navigationAction: navigationAction) {
            decisionHandler(.allow)
        } else if delegate?.overrideNavigation(request: request) == true {
            decisionHandler(.cancel)
        } else if let url = request.url {
            if navigationAction.targetFrame?.isMainFrame == true {
                navigationLogger?(url)
                decidePolicyFor(url: url, decisionHandler: decisionHandler)
            } else {
                let canOpen = WKWebView.canOpen(url: url)
                decisionHandler(canOpen ? .allow : .cancel)
            }
        } else {
            decisionHandler(.cancel)
        }
    }
    
    private func decidePolicyFor(url: URL, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        attemptOpenUniversalLink(url) { opened in
            let policy: WKNavigationActionPolicy
            if opened {
                policy = .cancel
            } else {
                // TODO: check against whitelist
                let webViewCanOpen = !self.openRedirectsInBrowser && WKWebView.canOpen(url: url)
                if !webViewCanOpen {
                    self.attemptOpenCustomSchemeLink(url: url)
                }
                policy = webViewCanOpen ? .allow : .cancel
            }
            decisionHandler(policy)
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
    
    private func attemptOpenCustomSchemeLink(url: URL) {
        if #available(iOS 10, *) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else {
            UIApplication.shared.openURL(url)
        }
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        if navigation != lastRootPage?.navigation {
            lastRootPage = nil
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
    
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        show(javascriptDialog: .alert(completionHandler), message: message)
    }
    
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        show(javascriptDialog: .confirm(completionHandler), message: message)
    }
    
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        show(javascriptDialog: .prompt(completionHandler, defaultValue: defaultText), message: prompt)
    }
}

