//
// Copyright 2021 Swedbank AB
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

class SwedbankPayWebViewControllerBase: UIViewController {
    weak var delegate: SwedbankPayWebViewControllerDelegate?
    
    private var onJavascriptDialogDismissed: (() -> Void)?
    
    // Overridable for testing, so we can mock UIApplication.open(_:options:completionHandler:)
    var attemptOpenUniversalLink: (URL, @escaping (Bool) -> Void) -> Void = { url, completionHandler in
        if #available(iOS 10, *) {
            UIApplication.shared.open(url, options: [.universalLinksOnly: true], completionHandler: completionHandler)
        } else {
            completionHandler(false)
        }
    }

    let webView: WKWebView
    
    init(
        configuration: WKWebViewConfiguration,
        delegate: SwedbankPayWebViewControllerDelegate
    ) {
        webView = WKWebView(frame: .zero, configuration: configuration)
        self.delegate = delegate
        super.init(nibName: nil, bundle: nil)
        webView.uiDelegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        self.view = webView
    }
}

extension SwedbankPayWebViewControllerBase: WKUIDelegate {
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard let delegate = delegate,
            !delegate.overrideNavigation(request: navigationAction.request),
            let url = navigationAction.request.url
            else {
                return nil
        }
        if !WKWebView.canOpen(url: url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            return nil
        }
        
        let viewController = SwedbankPayExtraWebViewController(
            configuration: configuration,
            delegate: delegate
        )
        delegate.add(webViewController: viewController)
        let webView = viewController.webView
        return webView
    }
    
    func webViewDidClose(_ webView: WKWebView) {
        delegate?.remove(webViewController: self)
    }
    
    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        show(javascriptDialog: .alert(completionHandler), message: message)
    }
    
    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {
        show(javascriptDialog: .confirm(completionHandler), message: message)
    }
    
    func webView(
        _ webView: WKWebView,
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (String?) -> Void
    ) {
        show(javascriptDialog: .prompt(completionHandler, defaultValue: defaultText), message: prompt)
    }
}

private extension SwedbankPayWebViewControllerBase {
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
    
    func showJavascriptDialog(alert: UIAlertController, onDialogDismissed: @escaping () -> Void) {
        dismissJavascriptDialog()
        self.onJavascriptDialogDismissed = onDialogDismissed
        present(alert, animated: true, completion: nil)
    }
}
extension SwedbankPayWebViewControllerBase {
    func dismissJavascriptDialog() {
        onJavascriptDialogDismissed?()
        onJavascriptDialogDismissed = nil
        presentedViewController?.dismiss(animated: false, completion: nil)
    }
}
