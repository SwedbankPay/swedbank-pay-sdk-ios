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

/// SwedbankPaySDKToSViewController handles terms of service (ToS) URL by showing it in a WKWebview
final class SwedbankPaySDKToSViewController: UIViewController, WKNavigationDelegate {
    
    private let tosUrl: URL
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    init(tosUrl: URL) {
        self.tosUrl = tosUrl
        super.init(nibName: nil, bundle: nil)
        
        if #available(iOS 13, *) {
            self.modalPresentationStyle = .automatic
        } else {
            self.modalPresentationStyle = .overCurrentContext
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.view.backgroundColor = UIColor.white
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Create navbar with close button
        var yPos: CGFloat = 0
        if #available(iOS 11, *) {
            yPos = view.safeAreaInsets.top
        } else {
            yPos = self.topLayoutGuide.length
        }
        let navBar = UINavigationBar.init(frame: CGRect(x: 0, y: yPos, width: UIScreen.main.bounds.width, height: 44))
        view.addSubview(navBar)

        let navItem = UINavigationItem(title: "")
        let closeButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.done, target: nil, action: #selector(self.closeButtonPressed))
        navItem.rightBarButtonItem = closeButton
        navBar.setItems([navItem], animated: false)
        
        // Create webview
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: view.bounds, configuration: config)
        webView.navigationDelegate = self
        webView.contentMode = .scaleAspectFill
        view.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: navBar.bottomAnchor),
            webView.leftAnchor.constraint(equalTo: view.leftAnchor),
            webView.rightAnchor.constraint(equalTo: view.rightAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        
        // Load given URL into webview
        let request = URLRequest.init(url: tosUrl)
        webView.load(request)
    }
    
    @objc func closeButtonPressed() -> Void {
        self.dismiss(animated: true, completion: nil)
    }
}
