import UIKit
import WebKit

/// ToSViewController handles terms of service (ToS) URL by showing it in a WKWebview
public class ToSViewController: UIViewController, WKNavigationDelegate {
    
    private var tosUrl: String?
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public init(tosUrl: String?) {
        super.init(nibName: nil, bundle: nil)
        
        self.tosUrl = tosUrl
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.view.backgroundColor = UIColor.white
    }
    
    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Create navbar with close button
        let navBar = UINavigationBar(frame: CGRect(x: 0, y: self.topLayoutGuide.length, width: UIScreen.main.bounds.width, height: 44))
        view.addSubview(navBar)

        let navItem = UINavigationItem(title: "")
        let closeButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.done, target: nil, action: #selector(self.closeButtonPressed))
        navItem.rightBarButtonItem = closeButton
        navBar.setItems([navItem], animated: false)

        // Create webview
        let webView = WKWebView(frame: view.bounds)
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
        if let tosUrl = tosUrl, let url = URL.init(string: tosUrl) {
            let request = URLRequest.init(url: url)
            webView.load(request)
        }
    }
    
    @objc func closeButtonPressed() -> Void {
        self.dismiss(animated: true, completion: nil)
    }
}
