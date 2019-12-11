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

private let storeLinksForSchemes = [
    "swish": URL(string: "itms-apps://apps.apple.com/fi/app/swish-betalningar/id563204724")!
]

/// Swedbank Pay SDK protocol, conform to this to get the result of the payment process
public protocol SwedbankPaySDKDelegate: AnyObject {
    func paymentComplete()
    
    func paymentFailed(_ problem: SwedbankPaySDK.Problem)
}

/// Swedbank Pay SDK ViewController, initialize this to start the payment process
public final class SwedbankPaySDKController: UIViewController {
    
    public weak var delegate: SwedbankPaySDKDelegate?
    
    lazy private var viewModel = SwedbankPaySDKViewModel()
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Initializes the Swedbank Pay SDK, and depending on the `consumerData`, starts the payment process with consumer identification or anonymous process
    /// - parameter configuration: Configuration object containing `backendUrl`, `headers`, `domainWhitelist` and `pinPublicKeys`; of these, `domainWhitelist` and `pinPublicKeys` are *optional*
    /// - parameter merchantData: merchant and purchase information
    /// - parameter consumerData: consumer identification information; *optional* - if not provided, consumer will be anonymous
    public init<T: Encodable>(configuration: SwedbankPaySDK.Configuration, merchantData: T?, consumerData: SwedbankPaySDK.Consumer? = nil) {
        super.init(nibName: nil, bundle: nil)

        viewModel.setConfiguration(configuration)
        viewModel.setConsumerData(consumerData)
        viewModel.setConsumerProfileRef(nil)
        
        let backendUrl = configuration.backendUrl
        
        guard viewModel.isDomainWhitelisted(backendUrl) else {
            let msg: String = "\(SDKProblemString.domainWhitelistError.rawValue)\(backendUrl)"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                self.paymentFailed(SwedbankPaySDK.Problem.Client(.MobileSDK(.InvalidRequest(message: msg, raw: nil))))
            })
            return
        }
        
        /// Convert merchantData into JSON
        if let merchantData = merchantData {
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            if let data = try? encoder.encode(merchantData) {
                // viewModel.merchantData = String(data: data, encoding: .utf8)
                let jsonStr = String(data: data, encoding: .utf8)
                viewModel.setMerchantData(jsonStr)
            } else {
                let msg: String = SDKProblemString.merchantDataSerializationFailed.rawValue
                self.paymentFailed(SwedbankPaySDK.Problem.Client(.MobileSDK(.InvalidRequest(message: msg, raw: nil))))
            }
        } else {
            let msg: String = SDKProblemString.merchantDataMissing.rawValue
            self.paymentFailed(SwedbankPaySDK.Problem.Client(.MobileSDK(.InvalidRequest(message: msg, raw: nil))))
        }
        
        /// Start the payment process
        if consumerData == nil {
            createPaymentOrder(backendUrl)
        } else {
            viewModel.identifyConsumer(backendUrl, successCallback: { [weak self] operationsList in
                self?.createConsumerURL(operationsList)
            }, errorCallback: { [weak self] problem in
                self?.paymentFailed(problem)
            })
        }
        
    }
    
    deinit {
        SwedbankPaySDK.removeContinueWebBrowsingUserActivityDelegate(self)
    }
    
    /// Creates paymentOrder
    private func createPaymentOrder(_ backendUrl: URL) {
        viewModel.createPaymentOrder(backendUrl, successCallback: { [weak self] operationsList in
            self?.createPaymentOrderURL(operationsList)
        }, errorCallback: { [weak self] problem in
            self?.paymentFailed(problem)
        })
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        SwedbankPaySDK.addContinueWebBrowsingUserActivityDelegate(self)
        self.view.backgroundColor = UIColor.white
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        SwedbankPaySDK.removeContinueWebBrowsingUserActivityDelegate(self)
    }
    
    private func reloadPaymentMenu() {
        if let link = viewModel.viewPaymentOrderLink {
            loadWebViewURL(link, type: .paymentOrder)
        }
    }
    
    /// Dismisses the viewcontroller when close button has been pressed
    @objc func closeButtonPressed() -> Void {
        self.dismiss(animated: true, completion: nil)
    }
    
    /// Creates consumer identification JavaScript URL String from list of operations and executes loadWebViewURL with it along with correct type
    /// - parameter list: List of operations available; need to find correct type of operation from it
    private func createConsumerURL(_ list: OperationsList) {
        let operationType = Operation.TypeString.viewConsumerIdentification.rawValue
        if let jsURL: String = list.operations.first(where: {$0.contentType == "application/javascript" && $0.rel == operationType})?.href {
            loadWebViewURL(jsURL, type: .consumerIdentification)
        } else {
            let msg: String = SDKProblemString.consumerIdentificationWebviewCreationFailed.rawValue
            self.paymentFailed(SwedbankPaySDK.Problem.Client(.MobileSDK(.InvalidRequest(message: msg, raw: nil))))
        }
    }
    
    /// Creates payment order JavaScript URL String from list of operations and executes loadWebViewURL with it along with correct type
    /// - parameter list: List of operations available; need to find correct type of operation from it
    private func createPaymentOrderURL(_ list: OperationsList) {
        let operationType = Operation.TypeString.viewPaymentOrder.rawValue
        if let jsURL: String = list.operations.first(where: {$0.contentType == "application/javascript" && $0.rel == operationType})?.href {
            viewModel.viewPaymentOrderLink = jsURL
            loadWebViewURL(jsURL, type: .paymentOrder)
        } else {
            let msg: String = SDKProblemString.paymentWebviewCreationFailed.rawValue
            self.paymentFailed(SwedbankPaySDK.Problem.Client(.MobileSDK(.InvalidRequest(message: msg, raw: nil))))
        }
    }
    
    /// Creates a HTML string to load into WKWebView
    /// - parameter url: JavaScript URL String to replace a placeholder with from HTML template
    /// - parameter type: the type of the WKWebView HTML to load, and what kind of JavaScript events to create for it
    private func loadWebViewURL(_ url: String, type: SwedbankWebView.ActionType) {
        
        let html: String
        let contentController = WKUserContentController();
        let messageHandler = MyScriptMessageHandler(owner: self)
        switch type {
        case .consumerIdentification:
            html = SwedbankWebView.createCheckinHTML(url)
            contentController.add(messageHandler, name: SwedbankWebView.ConsumerEvent.onConsumerIdentified.rawValue)
            contentController.add(messageHandler, name: SwedbankWebView.ConsumerEvent.onShippingDetailsAvailable.rawValue)
            contentController.add(messageHandler, name: SwedbankWebView.ConsumerEvent.onError.rawValue)
        case .paymentOrder:
            html = SwedbankWebView.createCheckoutHTML(url)
            contentController.add(messageHandler, name: SwedbankWebView.PaymentEvent.onPaymentMenuInstrumentSelected.rawValue)
            contentController.add(messageHandler, name: SwedbankWebView.PaymentEvent.onPaymentCompleted.rawValue)
            contentController.add(messageHandler, name: SwedbankWebView.PaymentEvent.onPaymentFailed.rawValue)
            contentController.add(messageHandler, name: SwedbankWebView.PaymentEvent.onPaymentCreated.rawValue)
            contentController.add(messageHandler, name: SwedbankWebView.PaymentEvent.onPaymentToS.rawValue)
            contentController.add(messageHandler, name: SwedbankWebView.PaymentEvent.onError.rawValue)
        }
        
        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        
        let webView = WKWebView(frame: view.bounds, configuration: config)
        webView.navigationDelegate = self
        webView.contentMode = .scaleAspectFill
        view.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        
        // Constrain the WKWebView
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.leftAnchor.constraint(equalTo: view.leftAnchor),
            webView.rightAnchor.constraint(equalTo: view.rightAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        
        // Load the created HTML
        webView.loadHTMLString(html, baseURL: viewModel.configuration?.backendUrl)
    }
    
    /// Show terms and conditions URL using SwedbankPaySDKToSViewController
    fileprivate func showTos(url: String) {
        debugPrint("SwedbankPaySDK: Open Terms of Service URL \(url)")
        
        let tos = SwedbankPaySDKToSViewController.init(tosUrl: url)
        self.present(tos, animated: true, completion: nil)
    }
    
    private func openRedirect(url: URL) {
        if #available(iOS 10, *) {
            UIApplication.shared.open(url, options: [:]) {
                self.handleRedirectCompletion(url: url, success: $0)
            }
        } else {
            let success = UIApplication.shared.openURL(url)
            handleRedirectCompletion(url: url, success: success)
        }
    }
    
    private func handleRedirectCompletion(url: URL, success: Bool) {
        if (!success) {
            if let scheme = url.scheme, let storeLink = storeLinksForSchemes[scheme] {
                if #available(iOS 10, *) {
                    UIApplication.shared.open(storeLink, options: [:], completionHandler: nil)
                } else {
                    UIApplication.shared.openURL(storeLink)
                    handleRedirectCompletion(url: url, success: success)
                }
            }
        }
    }
}

/// Extension for WKNavigationDelegate
extension SwedbankPaySDKController: WKNavigationDelegate {
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.targetFrame?.isMainFrame == false {
            decisionHandler(.allow)
            return
        }
        
        let isBaseUrlNavigation: Bool
        let url = navigationAction.request.url?.absoluteURL
        if let baseUrl = viewModel.configuration?.backendUrl.absoluteURL {
            // WKWebView will silently turn a navigation to https://foo.bar to https://foo.bar/
            isBaseUrlNavigation = url == baseUrl || url == URL(string: "/", relativeTo: baseUrl)?.absoluteURL
        } else {
            isBaseUrlNavigation = url?.absoluteString == "about:blank"
        }
        if isBaseUrlNavigation {
            decisionHandler(.allow)
            return
        }
        
        if let url = navigationAction.request.url {
            openRedirect(url: url)
        }
        decisionHandler(.cancel)
    }
        
    fileprivate func paymentFailed(_ problem: SwedbankPaySDK.Problem) {
        debugPrint("SwedbankPaySDK: Payment failed")
        
        self.delegate?.paymentFailed(problem)
    }
    
    fileprivate func paymentComplete() {
        debugPrint("SwedbankPaySDK: Payment complete")
        
        self.delegate?.paymentComplete()
    }
}

/// Extension to handle the WKWebview JavaScript events
private extension SwedbankPaySDKController {
    private class MyScriptMessageHandler: NSObject, WKScriptMessageHandler {
        private weak var owner: SwedbankPaySDKController?
        
        init(owner: SwedbankPaySDKController) {
            super.init()
            self.owner = owner
        }
        
        // Create event handlers
        public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
                
            // Consumer identification events
            case SwedbankWebView.ConsumerEvent.onConsumerIdentified.rawValue:
                handleConsumerIdentifiedEvent(message.body)
            case SwedbankWebView.ConsumerEvent.onShippingDetailsAvailable.rawValue:
                debugPrint("SwedbankPaySDK: onShippingDetailsAvailable event received")
            case SwedbankWebView.ConsumerEvent.onError.rawValue:
                let msg: String = message.body as? String ?? "Unknown error"
                owner?.paymentFailed(SwedbankPaySDK.Problem.Client(.MobileSDK(.InvalidRequest(message: msg, raw: nil))))
                
            // Payment events
            case SwedbankWebView.PaymentEvent.onPaymentMenuInstrumentSelected.rawValue:
                debugPrint("SwedbankPaySDK: onPaymentMenuInstrumentSelected event received")
            case SwedbankWebView.PaymentEvent.onPaymentCompleted.rawValue:
                debugPrint("SwedbankPaySDK: onPaymentCompleted event received")
                owner?.paymentComplete()
            case SwedbankWebView.PaymentEvent.onPaymentFailed.rawValue:
                let msg: String = message.body as? String ?? "Unknown error"
                owner?.paymentFailed(SwedbankPaySDK.Problem.Client(.MobileSDK(.InvalidRequest(message: msg, raw: nil))))
            case SwedbankWebView.PaymentEvent.onPaymentCreated.rawValue:
                debugPrint("SwedbankPaySDK: onPaymentCreated event received")
            case SwedbankWebView.PaymentEvent.onPaymentToS.rawValue:
                handleToSEvent(message.body)
            case SwedbankWebView.PaymentEvent.onError.rawValue:
                let msg: String = message.body as? String ?? "Unknown error"
                owner?.paymentFailed(SwedbankPaySDK.Problem.Client(.MobileSDK(.InvalidRequest(message: msg, raw: nil))))
            default:
                debugPrint("SwedbankPaySDK: undefined event received")
            }
        }
        
        /// Consumer identified event received
        /// - parameter messageBody: consumer identification String saved as consumerProfileRef
        private func handleConsumerIdentifiedEvent(_ messageBody: Any) {
            debugPrint("SwedbankPaySDK: onConsumerIdentified event received")
            if let str = messageBody as? String {
                owner?.viewModel.setConsumerProfileRef(str)
                
                #if DEBUG
                debugPrint("SwedbankPaySDK: consumerProfileRef set to: \(str)")
                #endif
            } else {
                debugPrint("SwedbankPaySDK: onConsumerIdentified - failed to get consumerProfileRef")
            }
            
            if let backendUrl = owner?.viewModel.configuration?.backendUrl {
                owner?.createPaymentOrder(backendUrl)
            }
        }
        
        /// Terms of service event received
        /// - parameter messageBody: terms of service URL String in an NSDictionary
        private func handleToSEvent(_ messageBody: Any) {
            debugPrint("SwedbankPaySDK: onPaymentToS event received")
            if let dict = messageBody as? NSDictionary {
                if let url = dict["openUrl"] as? String {
                    owner?.showTos(url: url)
                }
            } else {
                debugPrint("SwedbankPaySDK: Terms of Service URL could not be found")
            }
        }
    }
}

extension SwedbankPaySDKController : ContinueWebBrowsingUserActivityDelegate {
    func continueWebBrowsingActivity(url: URL) -> Bool {
        if let callbackUrl = viewModel.parseCallbackUrl(url) {
            switch callbackUrl {
            case .reloadPaymentMenu: reloadPaymentMenu()
            }
            return true
        } else {
            return false
        }
    }
}
