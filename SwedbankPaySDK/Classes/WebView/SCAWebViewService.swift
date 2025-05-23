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

import Foundation
@preconcurrency import WebKit

class SCAWebViewService: NSObject, WKNavigationDelegate {
    private var handler: ((Result<Void, Error>) -> Void)?

    private var webView: WKWebView?
    private var cleanupTimer: Timer?

    func load(task: IntegrationTask, handler: @escaping (Result<Void, Error>) -> Void) {
        guard let taskHref = task.href, 
              let url = URL(string: taskHref) else {
            handler(.failure(SwedbankPayAPIError.invalidUrl))

            return
        }

        cleanupTimer?.invalidate()
        cleanupTimer = nil
        webView?.stopLoading()
        webView = nil

        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true
        let configuration = WKWebViewConfiguration()
        configuration.preferences = preferences
        webView = WKWebView(frame: .zero, configuration: configuration)

        self.handler = handler

        var request = URLRequest(url: url)
        request.httpMethod = task.method
        request.allHTTPHeaderFields = ["Content-Type": task.contentType ?? ""]
        request.timeoutInterval = SwedbankPayAPIConstants.creditCardTimoutInterval

        if let httpBody = task.expects?.httpBody {
            request.httpBody = httpBody
        }

        webView?.navigationDelegate = self
        webView?.load(request)
    }
    
    private func reportResultAndScheduleCleanup(result: Result<Void, Error>) {
        if handler != nil {
            // Only report back result after first request, and leave webview to finish up until removing from memory after 10 seconds
            handler?(result)
            handler = nil
            
            cleanupTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { timer in
                self.webView?.stopLoading()
                self.webView = nil
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        reportResultAndScheduleCleanup(result: .success(()))
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        reportResultAndScheduleCleanup(result: .failure(error))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        reportResultAndScheduleCleanup(result: .failure(error))
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let response = navigationResponse.response as? HTTPURLResponse {
            if 400...599 ~= response.statusCode {
                decisionHandler(.cancel)

                return
            }
        }

        decisionHandler(.allow)
    }
}
