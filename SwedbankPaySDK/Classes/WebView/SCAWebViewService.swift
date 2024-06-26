//
//  SCAWebViewService.swift
//  SwedbankPaySDK
//
//  Created by Michael Balsiger on 2024-06-07.
//  Copyright © 2024 Swedbank. All rights reserved.
//

import Foundation
import WebKit

class SCAWebViewService: NSObject, WKNavigationDelegate {
    private var handler: ((Result<Void, Error>) -> Void)?

    private var webView: WKWebView?

    func load(task: IntegrationTask, handler: @escaping (Result<Void, Error>) -> Void) {
        guard let taskHref = task.href, 
              let url = URL(string: taskHref) else {
            handler(.failure(SwedbankPayAPIError.invalidUrl))

            return
        }

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
        request.timeoutInterval = 5

        if let bodyString = task.expects?
            .filter({ $0.type == "string" })
            .compactMap({ 
                guard let name = $0.name, 
                      let value = $0.value?.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else {
                    return nil
                }

                return name + "=" + value
            })
                .joined(separator: "&") {

            request.httpBody = bodyString.data(using: .utf8)
        }

        webView?.navigationDelegate = self
        webView?.load(request)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        handler?(.success(()))
        handler = nil

        self.webView?.stopLoading()
        self.webView = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handler?(.failure(error))
        handler = nil

        self.webView?.stopLoading()
        self.webView = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handler?(.failure(error))
        handler = nil

        self.webView?.stopLoading()
        self.webView = nil
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
