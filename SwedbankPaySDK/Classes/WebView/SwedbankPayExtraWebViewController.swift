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

import Foundation
import WebKit

final class SwedbankPayExtraWebViewController: SwedbankPayWebViewControllerBase {
    override init(
        configuration: WKWebViewConfiguration,
        delegate: SwedbankPayWebViewControllerDelegate
    ) {
        super.init(configuration: configuration, delegate: delegate)
        webView.navigationDelegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension SwedbankPayExtraWebViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let request = navigationAction.request
        
        if delegate?.overrideNavigation(request: request) == true {
            decisionHandler(.cancel)
        } else if let url = request.url {
            if navigationAction.targetFrame?.isMainFrame == true {
                decidePolicyFor(url: url, decisionHandler: decisionHandler)
            } else {
                let canOpen = WKWebView.canOpen(url: url)
                decisionHandler(canOpen ? .allow : .cancel)
            }
        } else {
            decisionHandler(.cancel)
        }
    }
    
    private func decidePolicyFor(
        url: URL,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        attemptOpenUniversalLink(url) { opened in
            if opened {
                decisionHandler(.cancel)
            } else {
                self.decidePolicyForNormalLink(
                    url: url,
                    decisionHandler: decisionHandler
                )
            }
        }
    }
    
    private func decidePolicyForNormalLink(
        url: URL,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if WKWebView.canOpen(url: url) {
            decisionHandler(.allow)
        } else {
            // A custom-scheme url. Must let another app take care of it.
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            decisionHandler(.cancel)
        }
    }
}
