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
    let webView: WKWebView

    var handler: ((Result<Void, Error>) -> Void)?

    override init() {
        self.webView = WKWebView()

        super.init()

        self.webView.navigationDelegate = self
    }

    func load(task: IntegrationTask, handler: @escaping (Result<Void, Error>) -> Void) {
        self.webView.stopLoading()
        self.handler = handler

        var request = URLRequest(url: URL(string: task.href!)!)
        request.httpMethod = task.method
        request.allHTTPHeaderFields = ["Content-Type": task.contentType ?? ""]
        request.timeoutInterval = 30

        var body: [String: Any?] = [:]

        if let expects = task.expects {
            for expect in expects {
                if let name = expect.name {
                    body[name] = expect.value
                }
            }
        }

        if let jsonData = try? JSONSerialization.data(withJSONObject: body) {
            request.httpBody = jsonData
        }

        self.webView.load(request)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.handler?(.success(()))
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self.handler?(.failure(error))
    }
}
