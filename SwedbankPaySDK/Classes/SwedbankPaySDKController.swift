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


/// Swedbank Pay SDK protocol, conform to this to get the result of the payment process
public protocol SwedbankPaySDKDelegate: AnyObject {
    func paymentComplete()
    func paymentCanceled()
    func paymentFailed(failureReason: SwedbankPaySDKController.FailureReason)
}

/// Swedbank Pay SDK ViewController, initialize this to start the payment process
public final class SwedbankPaySDKController: UIViewController {
    public enum FailureReason {
        case NetworkError(Error)
        case Problem(SwedbankPaySDK.Problem)
        case ScriptLoadingFailure(scriptUrl: URL?)
        case ScriptError(SwedbankPaySDK.TerminalFailure?)
        
        case NonWhitelistedDomain(failingUrl: URL?)
        case MissingField(String)
        case MissingOperation(String)
    }
    
    public weak var delegate: SwedbankPaySDKDelegate?
    
    public var openRedirectsInBrowser: Bool {
        get {
            return rootWebViewController.openRedirectsInBrowser
        }
        set {
            rootWebViewController.openRedirectsInBrowser = newValue
        }
    }
    
    private let userContentController = WKUserContentController()
    private lazy var rootWebViewController = createRootWebViewController()
    
    private lazy var initialLoadingIndicator = UIActivityIndicatorView(style: .gray)
    
    private lazy var viewModel = SwedbankPaySDKViewModel()
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Initializes the Swedbank Pay SDK, and depending on the `consumerData`, starts the payment process with consumer identification or anonymous process
    /// - parameter configuration: Configuration object containing `backendUrl`, `headers`, `domainWhitelist` and `pinPublicKeys`; of these, `domainWhitelist` and `pinPublicKeys` are *optional*
    /// - parameter consumer: consumer identification information; *optional* - if not provided, consumer will be anonymous
    /// - parameter paymentOrder: the payment order to create
    public init(configuration: SwedbankPaySDK.Configuration, consumer: SwedbankPaySDK.Consumer? = nil, paymentOrder: SwedbankPaySDK.PaymentOrder) {
        super.init(nibName: nil, bundle: nil)
        
        viewModel.setConfiguration(configuration)
        viewModel.setConsumerData(consumer)
        viewModel.setPaymentOrder(paymentOrder)
        viewModel.setConsumerProfileRef(nil)
        
        let backendUrl = configuration.backendUrl
        
        guard viewModel.isDomainWhitelisted(backendUrl) else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                self.paymentFailed(failureReason: .NonWhitelistedDomain(failingUrl: backendUrl))
            })
            return
        }
        
        /// Start the payment process
        if consumer == nil {
            createPaymentOrder(backendUrl)
        } else {
            viewModel.identifyConsumer(backendUrl, successCallback: { [weak self] operationsList in
                self?.createConsumerURL(operationsList)
            }, errorCallback: { [weak self] problem in
                self?.paymentFailed(failureReason: .Problem(problem))
            })
        }
        
    }
    
    deinit {
        SwedbankPaySDK.removeCallbackUrlDelegate(self)
        set(scriptMessageHandler: nil)
    }
    
    private func createRootWebViewController() -> SwedbankPayWebViewController {
        let config = WKWebViewConfiguration()
        config.userContentController = userContentController
        return SwedbankPayWebViewController(configuration: config, delegate: self)
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        addRootWebViewController()
        addInitialLoadingIndicator()
    }
    
    private func addRootWebViewController() {
        let view = self.view!
        
        addChild(rootWebViewController)
        let webView = rootWebViewController.view!
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leftAnchor.constraint(equalTo: view.leftAnchor),
            webView.rightAnchor.constraint(equalTo: view.rightAnchor),
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        rootWebViewController.didMove(toParent: self)
    }
    
    private func addInitialLoadingIndicator() {
        let view = self.view!
        
        initialLoadingIndicator.stopAnimating()
        initialLoadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(initialLoadingIndicator)
        let topConstraint: NSLayoutConstraint
        if #available(iOS 11.0, *) {
            topConstraint = initialLoadingIndicator.topAnchor.constraint(
                equalToSystemSpacingBelow: view.safeAreaLayoutGuide.topAnchor,
                multiplier: 1
            )
        } else {
            topConstraint = initialLoadingIndicator.topAnchor.constraint(equalTo: topLayoutGuide.bottomAnchor, constant: 20)
        }
        NSLayoutConstraint.activate([
            initialLoadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            topConstraint
        ])
    }
    
    /// Creates paymentOrder
    private func createPaymentOrder(_ backendUrl: URL) {
        viewModel.createPaymentOrder(backendUrl, successCallback: { [weak self] operationsList in
            self?.createPaymentOrderURL(operationsList)
        }, errorCallback: { [weak self] problem in
            self?.paymentFailed(failureReason: .Problem(problem))
        })
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        SwedbankPaySDK.addCallbackUrlDelegate(self)
        self.view.backgroundColor = UIColor.white
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        SwedbankPaySDK.removeCallbackUrlDelegate(self)
    }
    
    private func reloadPaymentMenuIfAtRoot() {
        if rootWebViewController.isAtRoot == true {
            reloadPaymentMenu()
        }
    }
    
    private func reloadPaymentMenu(delay: Bool = false) {
        if let link = viewModel.viewPaymentOrderLink {
            dismissExtraWebViews(reloadPaymentMenuIfAtRoot: false)
            loadPage(template: SwedbankPayWebContent.paymentTemplate, scriptUrl: link, delay: delay) { [weak self] (event, argument) in
                self?.on(paymentEvent: event, argument: argument)
            }        }
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
            loadPage(template: SwedbankPayWebContent.checkInTemplate, scriptUrl: jsURL) { [weak self] (event, argument) in
                self?.on(consumerEvent: event, argument: argument)
            }
        } else {
            self.paymentFailed(failureReason: .MissingOperation(operationType))
        }
    }
    
    /// Creates payment order JavaScript URL String from list of operations and executes loadWebViewURL with it along with correct type
    /// - parameter list: List of operations available; need to find correct type of operation from it
    private func createPaymentOrderURL(_ list: OperationsList) {
        let operationType = Operation.TypeString.viewPaymentOrder.rawValue
        if let jsURL: String = list.operations.first(where: {$0.contentType == "application/javascript" && $0.rel == operationType})?.href {
            viewModel.viewPaymentOrderLink = jsURL
            loadPage(template: SwedbankPayWebContent.paymentTemplate, scriptUrl: jsURL) { [weak self] (event, argument) in
                self?.on(paymentEvent: event, argument: argument)
            }
        } else {
            self.paymentFailed(failureReason: .MissingOperation(operationType))
        }
    }
    
    private func set(scriptMessageHandler: WKScriptMessageHandler?) {
        debugPrint("setting script message handler to \(scriptMessageHandler == nil ? "" : "non-")nil")
        userContentController.removeScriptMessageHandler(forName: SwedbankPayWebContent.scriptMessageHandlerName)
        if let scriptMessageHandler = scriptMessageHandler {
            userContentController.add(scriptMessageHandler, name: SwedbankPayWebContent.scriptMessageHandlerName)
        }
    }
    
    private func loadPage<T>(template: SwedbankPayWebContent.HTMLTemplate<T>, scriptUrl: String, delay: Bool = false, eventHandler: @escaping (T, Any?) -> Void) {
        
        let html = template.buildPage(scriptUrl: scriptUrl, delay: delay)
        debugPrint("creating script message handler for \(T.self)")
        let scriptMessageHandler = template.createScriptMessageHandler(eventHandler: eventHandler)
        set(scriptMessageHandler: scriptMessageHandler)
        
        initialLoadingIndicator.startAnimating()
        rootWebViewController.load(htmlString: html, baseURL: viewModel.configuration?.backendUrl)
    }
    
    /// Show terms and conditions URL using SwedbankPaySDKToSViewController
    private func showTos(url: URL) {
        debugPrint("SwedbankPaySDK: Open Terms of Service URL \(url)")
        
        let tos = SwedbankPaySDKToSViewController.init(tosUrl: url)
        self.present(tos, animated: true, completion: nil)
    }
}

// MARK: Payment process URLs
private extension SwedbankPaySDKController {
    func handlePaymentProcessUrl(url: URL) -> Bool {
        guard let urls = viewModel.paymentOrder?.urls else {
            return false
        }
        
        switch url.absoluteURL {
        case urls.completeUrl.absoluteURL:
            paymentComplete()
            return true
        case urls.cancelUrl?.absoluteURL:
            paymentCanceled()
            return true
        case urls.paymentUrl?.absoluteURL:
            reloadPaymentMenu(delay: true)
            return true
        case urls.termsOfServiceUrl?.absoluteURL:
            showTos(url: url)
            return true
        default:
            return false
        }
    }
    
    func paymentComplete() {
        self.delegate?.paymentComplete()
    }
    
    func paymentCanceled() {
        self.delegate?.paymentCanceled()
    }
    
    func paymentFailed(failureReason: FailureReason) {
        self.delegate?.paymentFailed(failureReason: failureReason)
    }

}

/// Extension to handle the WKWebview JavaScript events
private extension SwedbankPaySDKController {
    private func parseTerminalFailure(jsTerminalFailure: Any?) -> SwedbankPaySDK.TerminalFailure? {
        return (jsTerminalFailure as? [AnyHashable : Any]).map {
            SwedbankPaySDK.TerminalFailure(
                origin: $0["origin"] as? String,
                messageId: $0["messageId"] as? String,
                details: $0["details"] as? String
            )
        }
    }
    
    func on(consumerEvent: SwedbankPayWebContent.ConsumerEvent, argument: Any?) {
        switch consumerEvent {
        case .onScriptLoaded:
            initialLoadingIndicator.stopAnimating()
        case .onScriptError:
            let url = (argument as? String).flatMap(URL.init(string:))
            paymentFailed(failureReason: .ScriptLoadingFailure(scriptUrl: url))
        case .onConsumerIdentified:
            handleConsumerIdentifiedEvent(argument)
        case .onShippingDetailsAvailable:
            debugPrint("SwedbankPaySDK: onShippingDetailsAvailable event received")
        case .onError:
            let failure = parseTerminalFailure(jsTerminalFailure: argument)
            paymentFailed(failureReason: .ScriptError(failure))
        }
    }
    
    func on(paymentEvent: SwedbankPayWebContent.PaymentEvent, argument: Any?) {
        switch paymentEvent {
        case .onScriptLoaded:
            initialLoadingIndicator.stopAnimating()
        case .onScriptError:
            let url = (argument as? String).flatMap(URL.init(string:))
            paymentFailed(failureReason: .ScriptLoadingFailure(scriptUrl: url))
        case .onError:
            let failure = parseTerminalFailure(jsTerminalFailure: argument)
            paymentFailed(failureReason: .ScriptError(failure))
        }
    }
    
    /// Consumer identified event received
    /// - parameter messageBody: consumer identification String saved as consumerProfileRef
    private func handleConsumerIdentifiedEvent(_ messageBody: Any?) {
        debugPrint("SwedbankPaySDK: onConsumerIdentified event received")
        if let str = messageBody as? String {
            viewModel.setConsumerProfileRef(str)
            
            #if DEBUG
            debugPrint("SwedbankPaySDK: consumerProfileRef set to: \(str)")
            #endif
        } else {
            debugPrint("SwedbankPaySDK: onConsumerIdentified - failed to get consumerProfileRef")
        }
        
        if let backendUrl = viewModel.configuration?.backendUrl {
            createPaymentOrder(backendUrl)
        }
    }
}

extension SwedbankPaySDKController : CallbackUrlDelegate {
    func handleCallbackUrl(_ url: URL) -> Bool {
        if let token = viewModel.paymentOrder?.urls.paymentToken,
            let callbackUrl = viewModel.parseCallbackUrl(url) {
            switch callbackUrl {
            case .reloadPaymentMenu(token):
                // I have witnessed the reload not immediately resulting in onPaymentSuccess.
                // This does not happen often, but hopefully this will fix it.
                reloadPaymentMenu(delay: true)
                return true
            default:
                return false
            }
        } else {
            return false
        }
    }
}

extension SwedbankPaySDKController : SwedbankPayWebViewControllerDelegate {
    func add(webViewController: SwedbankPayWebViewController) {
        let presentedViewController = self.presentedViewController
        if let navigationController = presentedViewController as? UINavigationController {
            navigationController.pushViewController(webViewController, animated: true)
        } else {
            if presentedViewController != nil {
                dismiss(animated: false, completion: nil)
            }
            webViewController.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(onWebViewDoneButtonPressed))
            let navigationController = UINavigationController(rootViewController: webViewController)
            present(navigationController, animated: true, completion: nil)
        }
    }
    
    @objc private func onWebViewDoneButtonPressed() {
        dismissExtraWebViews(reloadPaymentMenuIfAtRoot: true)
    }
    
    func remove(webViewController: SwedbankPayWebViewController) {
        if webViewController === rootWebViewController {
            reloadPaymentMenu()
        } else if let navigationController = presentedViewController as? UINavigationController {
            if navigationController.visibleViewController === webViewController {
                if navigationController.viewControllers.count > 1 {
                    navigationController.popViewController(animated: true)
                } else {
                    dismissExtraWebViews(reloadPaymentMenuIfAtRoot: true)
                }
            } else {
                let viewControllers = navigationController.viewControllers.filter {
                    $0 !== webViewController
                }
                if viewControllers.isEmpty {
                    dismissExtraWebViews(reloadPaymentMenuIfAtRoot: true)
                } else {
                    navigationController.viewControllers = viewControllers
                }
            }
        }
    }
    
    func overrideNavigation(request: URLRequest) -> Bool {
        guard let url = request.url else {
            return false
        }
        return handlePaymentProcessUrl(url: url)
            || handleCallbackUrl(url)
    }
    
    func webViewControllerDidNavigateOutOfRoot(_ webViewController: SwedbankPayWebViewController) {
        if webViewController === rootWebViewController {
            set(scriptMessageHandler: nil)
            initialLoadingIndicator.stopAnimating()
        }
    }
    
    private func dismissExtraWebViews(reloadPaymentMenuIfAtRoot: Bool) {
        dismiss(animated: true, completion: nil)
        if reloadPaymentMenuIfAtRoot {
            self.reloadPaymentMenuIfAtRoot()
        }
    }
}
