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
    
    /// Called when the user taps on the Terms of Service Link
    /// in the Payment Menu.
    ///
    /// If your delegate does not override this method, the SDK will
    /// present a view controller that loads the linked page.
    ///
    /// - parameter url: the URL of the Terms of Service page
    /// - returns: `true` to consume the tap and disable the default behaviour, `false` to allow the SDK to show the ToS web page
    func overrideTermsOfServiceTapped(url: URL) -> Bool
}
public extension SwedbankPaySDKDelegate {
    func overrideTermsOfServiceTapped(url: URL) -> Bool {
        return false
    }
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
    
    // These are useful for investigating issuers' compatibility with WKWebView
    //
    // As some 3DS pages are unfortunately incompatible with WKWebView,
    // we err on the side of caution and only allow pages we have tested
    // by default. You can add your own entries either by editing the
    // good_redirects file (and please submit a pull request if you do),
    // or by specifying them in the additionalAllowedWebViewRedirects
    // property of your SwedbankPaySDK.Configuration.
    //
    // To discover more WKWebView compatible pages, you can set
    // the SwedbankPaySDKController's webRedirectBehavior
    // to .AlwaysUseWebView, and set a webNavigationLogger
    // to gather the urls used. At this time the decision to
    // use WKWebView is based on the domain name only; more
    // sophisticated patterns can be added to the system if
    // a reasonable need arises.
    //
    // To help with debugging, there is also the option to open all
    // pages in the browser. You can use this to check if a problem
    // with a PSP is or is not related to WKWebView.
    public enum WebRedirectBehavior {
        case Default
        case AlwaysUseWebView
        case AlwaysUseBrowser
    }
    
    public var webRedirectBehavior = WebRedirectBehavior.Default
    
    public var webNavigationLogger: ((URL) -> Void)? {
        get {
            return rootWebViewController.navigationLogger
        }
        set {
            rootWebViewController.navigationLogger = newValue
        }
    }
    
    private let userContentController = WKUserContentController()
    private lazy var rootWebViewController = createRootWebViewController()
    
    private var loadingIndicatorStyle: UIActivityIndicatorView.Style {
        if #available(iOS 13.0, *) {
            return .medium
        } else {
            return .gray
        }
    }
    private lazy var initialLoadingIndicator = UIActivityIndicatorView(style: loadingIndicatorStyle)
    
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
        if let jsURL: String = list.operations.first(where: {$0.rel == operationType})?.href {
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
        if let jsURL: String = list.operations.first(where: {$0.rel == operationType})?.href {
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
        
        if delegate?.overrideTermsOfServiceTapped(url: url) != true {
            let tos = SwedbankPaySDKToSViewController.init(tosUrl: url)
            self.present(tos, animated: true, completion: nil)
        }
    }
}

// MARK: Payment process URLs
private extension SwedbankPaySDKController {
    private func ensurePath(url: URL) -> URL {
        return url.path.isEmpty ? URL(string: "/", relativeTo: url)!.absoluteURL : url.absoluteURL
    }
    
    func handlePaymentProcessUrl(url: URL) -> Bool {
        guard let urls = viewModel.paymentOrder?.urls else {
            return false
        }
        
        // WKWebView silently turns https://foo.bar to https://foo.bar/
        // So append a path to the payment urls if needed
        switch url.absoluteURL {
        case ensurePath(url: urls.completeUrl):
            paymentComplete()
            return true
        case urls.cancelUrl.map(ensurePath(url:)):
            paymentCanceled()
            return true
        case urls.paymentUrl.map(ensurePath(url:)):
            reloadPaymentMenu(delay: true)
            return true
        case urls.termsOfServiceUrl.map(ensurePath(url:)):
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

extension SwedbankPaySDKController : CallbackUrlDelegate {
    func handleCallbackUrl(_ url: URL) -> Bool {
        let handled = urlMatchesPaymentUrl(url: url)
        if handled {
            // I have witnessed the reload not immediately resulting in onPaymentSuccess.
            // This does not happen often, but hopefully this will fix it.
            reloadPaymentMenu(delay: true)
        }
        return handled
    }
    
    private func urlMatchesPaymentUrl(url: URL) -> Bool {
        // Because of the interaction between how Universal Links work
        // (first, they will only be followed if the navigation started
        // from a user interaction; and second, they will only be followed
        // if their domain is different to the current page), and how many
        // 3DS pages are designed (i.e. they have a timeout that navigates
        // to the payment url), we have to perform some gymnastics to get
        // back to the app while maintaining a nice user experience.
        //
        // How this works is:
        //  - paymentUrl is a Universal Link
        //    - if stars align, this will get routed to our app. Usually not the case. (See below for note)
        //  - in browser, paymentUrl redirects to a page different domain
        //  - that page has a button
        //  - pressing the button navigates back to paymentUrl but with an extra query parameter
        //    - in most cases, this will be routed to our app
        //  - in browser, paymentUrl with the extra parameter redirects to the same url but with a custom scheme
        //
        // We don't do the last one immediately, because doing that will show a
        // popup that we have no control over. It is included as a final fallback mechanism.
        //
        // N.B! iOS version 13.4 has slightly changed how Universal Links
        // work, and it seems that it is now more likely that already
        // the first universal link will be routed to our app.
        //
        // All of the above means, that if paymentUrl is https://<foo>,
        // then all of the following are equal in this sense:
        //  - https://<foo>
        //  - https://<foo>&fallback=true
        //  - <customscheme>://<foo>&fallback=true
        //  (the following won't be used by the example backend, but your custom one may)
        //  - https://<foo>?fallback=true
        //  - <customscheme>://foo
        //  - <customscheme>://<foo>?fallback=true
        //
        // For simplicity, we require the URL to be parseable to URLComponents,
        // i.e. that if conforms to RFC 3986. This should never be a problem in practice.
        
        guard
            let paymentUrl = viewModel.paymentOrder?.urls.paymentUrl,
            let paymentUrlComponents = URLComponents(url: paymentUrl, resolvingAgainstBaseURL: true),
            let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: true)
            else {
                return false
        }
        
        return callback(components: urlComponents, matchPaymentUrlComponents: paymentUrlComponents)
    }
    
    private func callback(components: URLComponents, matchPaymentUrlComponents paymentUrlComponents: URLComponents) -> Bool {
        // Treat fallback scheme as equal to the original scheme
        var componentsToCompare = components
        if let callbackScheme = viewModel.configuration?.callbackScheme,
            componentsToCompare.scheme == callbackScheme {
            componentsToCompare.scheme = paymentUrlComponents.scheme
        }
        
        // Check that all the original query items are in place
        if !callback(queryItems: components.queryItems, match: paymentUrlComponents.queryItems) {
            return false
        }
        
        // Check that everything else is equal
        var paymentUrlComponentsToCompare = paymentUrlComponents
        componentsToCompare.queryItems = nil
        paymentUrlComponentsToCompare.queryItems = nil
        return componentsToCompare == paymentUrlComponentsToCompare
    }
    
    private func callback(queryItems: [URLQueryItem]?, match requiredItems: [URLQueryItem]?) -> Bool {
        // Backend is allowed to add query items to the url.
        // It must not remove or modify any.
        var items = queryItems ?? []
        for requiredItem in requiredItems ?? [] {
            guard let index = items.firstIndex(of: requiredItem) else {
                return false
            }
            items.remove(at: index)
        }
        return true
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
    
    func allowWebViewNavigation(to url: URL, completion: @escaping (Bool) -> Void) {
        if url.absoluteString == "about:blank" {
            // Always allow loading the empty page.
            // This is chiefly for tests.
            completion(true)
        } else {
            switch webRedirectBehavior {
            case .Default:
                let allowedByConfig = viewModel.configuration?.additionalAllowedWebViewRedirects
                if allowedByConfig?.contains(where: { $0.allows(url: url) }) == true {
                    completion(true)
                } else {
                    GoodWebViewRedirects.instance.allows(url: url, completion: completion)
                }
                
            case .AlwaysUseWebView:
                completion(true)
                
            case .AlwaysUseBrowser:
                completion(false)
            }
        }
    }
}
