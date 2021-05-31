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
    /// Called whenever the payment order is shown in this
    /// view controller's view.
    func paymentOrderDidShow(info: SwedbankPaySDK.ViewPaymentOrderInfo)
    /// Called when the payment order is no longer visible after being shown.
    /// Usually this happens because the payment order needed to redirect
    /// to a 3D-Secure page.
    ///
    /// This is usually interesting if you are using instrument mode
    /// to provide custom instrument selection. You should disallow
    /// changing the instrument at this state.
    func paymentOrderDidHide()
    /// Called if an attempt to update the payment order fails.
    func updatePaymentOrderFailed(
        updateInfo: Any,
        error: Error
    )
    
    func paymentComplete()
    func paymentCanceled()
    
    /// Called if there is an error in performing the payment.
    /// The error may be SwedbankPaySDKController.WebContentError,
    /// or any error reported by your SwedbankPaySDKConfiguration.
    ///
    /// If you are using a SwedbankPaySDK.MerchantBackendConfiguration,
    /// this means the error will be either
    /// SwedbankPaySDKController.WebContentError, or
    /// SwedbankPaySDK.MerchantBackendError.
    ///
    /// - parameter error: The error that caused the failure
    func paymentFailed(error: Error)
    
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
    func paymentOrderDidShow(info: SwedbankPaySDK.ViewPaymentOrderInfo) {}
    func paymentOrderDidHide() {}
    func updatePaymentOrderFailed(
        updateInfo: Any,
        error: Error
    ) {}
    
    func overrideTermsOfServiceTapped(url: URL) -> Bool {
        return false
    }
}

/// Swedbank Pay SDK ViewController, initialize this to start the payment process
public final class SwedbankPaySDKController: UIViewController {
    /// Ways that the payment can fail after the configuration
    /// has successfully started it.
    public enum WebContentError: Error {
        /// The script (the "view-*" link) failed to load.
        /// As WKWebView will not provide details on the failure,
        /// we cannot know more than the script url here.
        case ScriptLoadingFailure(scriptUrl: URL?)
        /// The script made an onError callback
        /// The associated value if the Terminal Failure reported by the callback
        case ScriptError(SwedbankPaySDK.TerminalFailure?)
        /// The payment tried to redirect to a web page,
        /// but the loading failed
        case RedirectFailure(error: Error)
    }
    
    /// A delegate to receive callbacks as the state of SwedbankPaySDKController changes.
    public weak var delegate: SwedbankPaySDKDelegate?
    
    /// Styling for the payment menu
    ///
    /// Styling the payment menu requires a separate agreement with Swedbank Pay.

    public var paymentMenuStyle: [String: Any]?
    
    /// The current payment order in this SwedbankPaySDKController.
    ///
    /// This will be `nil` until the first call to
    /// SwedbankPaySDKDelegate.paymentOrderDidShow. It will not become `nil`
    /// after that, so it does *not* represent the state of whether
    /// the payment order is currently showing or not.
    /// Is value is always the most recent value returned from your
    /// `SwedbankPaySDKConfiguration` (currently from either
    /// `postPaymentorders` or `patchUpdatePaymentorderSetinstrument`.
    public var currentPaymentOrder: SwedbankPaySDK.ViewPaymentOrderInfo? {
        return viewModel.viewPaymentOrderInfo
    }
    
    /// `true` if the payment order is currently shown, `false` otherwise
    public var showingPaymentOrder: Bool {
        return currentPaymentOrder != nil && rootWebViewController.isAtRoot
    }
    
    /// `true` if the payment order is currently being updated, `false` otherwise
    public var updatingPaymentOrder: Bool {
        return viewModel.updating
    }
    
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
    
    private let viewModel: SwedbankPaySDKViewModel
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Initializes the Swedbank Pay SDK, and depending on the `consumerData`,
    /// starts the payment process with consumer identification or anonymous process
    /// - parameter configuration: Configuration object that handles creating
    /// and manipulating Consumer Identification Sessions and Payment Orders as needed.
    /// - parameter consumer: consumer identification information;
    /// *optional* - if not provided, consumer will be anonymous
    /// - parameter paymentOrder: the payment order to create
    public convenience init(
        configuration: SwedbankPaySDKConfiguration,
        consumer: SwedbankPaySDK.Consumer? = nil,
        paymentOrder: SwedbankPaySDK.PaymentOrder
    ) {
        self.init(
            configuration: configuration,
            withCheckin: consumer != nil,
            consumer: consumer,
            paymentOrder: paymentOrder,
            userData: nil
        )
    }
    
    /// Initializes the Swedbank Pay SDK, and starts the payment process
    ///  with consumer identification or anonymous process
    /// - parameter configuration: Configuration object that handles creating
    ///  and manipulating Consumer Identification Sessions and Payment Orders as needed.
    /// - parameter withCheckin: if `true`, performs checkin berfore creating the payment order
    /// - parameter consumer: consumer object for the checkin
    /// - parameter paymentOrder: the payment order to create
    /// - userData: user data for your configuration. This value will be provided to your configuration callbacks.
    public init(
        configuration: SwedbankPaySDKConfiguration,
        withCheckin: Bool,
        consumer: SwedbankPaySDK.Consumer?,
        paymentOrder: SwedbankPaySDK.PaymentOrder?,
        userData: Any?
    ) {
        viewModel = SwedbankPaySDKViewModel(
            configuration: configuration,
            consumerData: consumer,
            paymentOrder: paymentOrder,
            userData: userData
        )
        super.init(nibName: nil, bundle: nil)
        
        /// Start the payment process
        if withCheckin {
            viewModel.identifyConsumer { [weak self] in
                self?.handleIdentifyConsumerResult(result: $0)
            }
        } else {
            createPaymentOrder()
        }
    }
    
    deinit {
        SwedbankPaySDK.removeCallbackUrlDelegate(self)
        set(scriptMessageHandler: nil)
        viewModel.cancelUpdate()
    }
    
    /// Performs an update on the current payment order.
    ///
    /// When you call this method, it will result in a callback to your
    /// `SwedbankPaySDKConfiguration.updatePaymentOrder` method;
    /// the meaning of `updateInfo` is determined by your implementation
    /// of that method.
    ///
    /// After calling this method, you should disable user interaction
    /// until the update finishes. Your delegate will receive either a
    /// `paymentOrderDidShow` or `updatePaymentOrderFailed` when that happens.
    /// If you call this method while an update is in progress,
    /// the previous update will be canceled first.
    ///
    /// See `SwedbankPaySDK.MerchantBackendConfiguration` for an example.
    public func updatePaymentOrder(updateInfo: Any) {
        viewModel.updatePaymentOrder(
            updateInfo: updateInfo
        ) { [weak self] in
            self?.handleUpdatePaymentOrderResult(updateInfo: updateInfo, result: $0)
        }
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
    private func createPaymentOrder() {
        viewModel.createPaymentOrder { [weak self] in
            self?.handleCreatePaymentOrderResult(result: $0)
        }
    }
    
    private func handleResult<T>(result: Result<T, Error>, onSuccess: (T) -> Void) {
        switch result {
        case .success(let t):
            onSuccess(t)
        case .failure(let error):
            paymentFailed(error: error)
        }
    }
    
    private func handleIdentifyConsumerResult(result: Result<SwedbankPaySDK.ViewConsumerIdentificationInfo, Error>) {
        handleResult(result: result, onSuccess: showCheckin(_:))
    }
    
    private func handleCreatePaymentOrderResult(result: Result<SwedbankPaySDK.ViewPaymentOrderInfo, Error>) {
        handleResult(result: result) {
            showPaymentOrder(info: $0, delay: false)
        }
    }
    
    private func handleUpdatePaymentOrderResult(
        updateInfo: Any,
        result: Result<SwedbankPaySDK.ViewPaymentOrderInfo, Error>
    ) {
        switch result {
        case .success(let info):
            showPaymentOrder(info: info, delay: false)
        case .failure(let error):
            delegate?.updatePaymentOrderFailed(
                updateInfo: updateInfo,
                error: error
            )
        }
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
    
    /// Dismisses the viewcontroller when close button has been pressed
    @objc func closeButtonPressed() -> Void {
        self.dismiss(animated: true, completion: nil)
    }
    
    /// Creates consumer identification JavaScript URL String from list of operations and executes loadWebViewURL with it along with correct type
    /// - parameter list: List of operations available; need to find correct type of operation from it
    private func showCheckin(_ info: SwedbankPaySDK.ViewConsumerIdentificationInfo) {
        loadPage(
            baseURL: info.webViewBaseURL,
            template: SwedbankPayWebContent.checkInTemplate,
            scriptUrl: info.viewConsumerIdentification
        ) { [weak self] (event, argument) in
            self?.on(consumerEvent: event, argument: argument)
        }
    }
    
    private func showPaymentOrder(info: SwedbankPaySDK.ViewPaymentOrderInfo, delay: Bool) {
        viewModel.viewPaymentOrderInfo = info
        loadPage(
            baseURL: info.webViewBaseURL,
            template: SwedbankPayWebContent.paymentTemplate,
            scriptUrl: info.viewPaymentorder,
            delay: delay
        ) { [weak self] (event, argument) in
            self?.on(paymentEvent: event, argument: argument)
        }
        delegate?.paymentOrderDidShow(info: info)
    }
    
    private func reloadPaymentMenu(delay: Bool = false) {
        if let info = viewModel.viewPaymentOrderInfo {
            dismissExtraWebViews()
            showPaymentOrder(info: info, delay: delay)
        }
    }
    
    private func set(scriptMessageHandler: WKScriptMessageHandler?) {
        debugPrint("setting script message handler to \(scriptMessageHandler == nil ? "" : "non-")nil")
        userContentController.removeScriptMessageHandler(forName: SwedbankPayWebContent.scriptMessageHandlerName)
        if let scriptMessageHandler = scriptMessageHandler {
            userContentController.add(scriptMessageHandler, name: SwedbankPayWebContent.scriptMessageHandlerName)
        }
    }
    
    private func loadPage<T>(
        baseURL: URL?,
        template: SwedbankPayWebContent.HTMLTemplate<T>,
        scriptUrl: URL,
        delay: Bool = false,
        eventHandler: @escaping (T, Any?) -> Void
    ) {
        
        let html = template.buildPage(scriptUrl: scriptUrl.absoluteString, style: paymentMenuStyle, delay: delay)
        debugPrint("creating script message handler for \(T.self)")
        let scriptMessageHandler = template.createScriptMessageHandler(eventHandler: eventHandler)
        set(scriptMessageHandler: scriptMessageHandler)
        
        initialLoadingIndicator.startAnimating()
        rootWebViewController.load(htmlString: html, baseURL: baseURL)
    }
}

// MARK: Payment process URLs
private extension SwedbankPaySDKController {
    private func ensurePath(url: URL) -> URL {
        return url.path.isEmpty ? URL(string: "/", relativeTo: url)!.absoluteURL : url.absoluteURL
    }
    
    func handlePaymentProcessUrl(url: URL) -> Bool {
        guard let info = viewModel.viewPaymentOrderInfo else {
            return false
        }
        
        // WKWebView silently turns https://foo.bar to https://foo.bar/
        // So append a path to the payment urls if needed
        switch url.absoluteURL {
        case ensurePath(url: info.completeUrl):
            paymentComplete()
            return true
        case info.cancelUrl.map(ensurePath(url:)):
            paymentCanceled()
            return true
        case info.paymentUrl.map(ensurePath(url:)):
            reloadPaymentMenu(delay: true)
            return true
        case info.termsOfServiceUrl.map(ensurePath(url:)):
            return delegate?.overrideTermsOfServiceTapped(url: url) == true
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
    
    func paymentFailed(error: Error) {
        self.delegate?.paymentFailed(error: error)
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
        guard let paymentUrl = viewModel.viewPaymentOrderInfo?.paymentUrl else {
            return false
        }
        // See SwedbankPaySDKConfiguration for discussion on why we need to do this.
        return url == paymentUrl
            || viewModel.configuration.url(url, matchesPaymentUrl: paymentUrl)
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
            paymentFailed(error: WebContentError.ScriptLoadingFailure(scriptUrl: url))
        case .onConsumerIdentified:
            handleConsumerIdentifiedEvent(argument)
        case .onShippingDetailsAvailable:
            debugPrint("SwedbankPaySDK: onShippingDetailsAvailable event received")
        case .onError:
            let failure = parseTerminalFailure(jsTerminalFailure: argument)
            paymentFailed(error: WebContentError.ScriptError(failure))
        }
    }
    
    func on(paymentEvent: SwedbankPayWebContent.PaymentEvent, argument: Any?) {
        switch paymentEvent {
        case .onScriptLoaded:
            initialLoadingIndicator.stopAnimating()
        case .onScriptError:
            let url = (argument as? String).flatMap(URL.init(string:))
            paymentFailed(error: WebContentError.ScriptLoadingFailure(scriptUrl: url))
        case .onError:
            let failure = parseTerminalFailure(jsTerminalFailure: argument)
            paymentFailed(error: WebContentError.ScriptError(failure))
        }
    }
    
    /// Consumer identified event received
    /// - parameter messageBody: consumer identification String saved as consumerProfileRef
    private func handleConsumerIdentifiedEvent(_ messageBody: Any?) {
        debugPrint("SwedbankPaySDK: onConsumerIdentified event received")
        if let str = messageBody as? String {
            viewModel.consumerProfileRef = str
            
            #if DEBUG
            debugPrint("SwedbankPaySDK: consumerProfileRef set to: \(str)")
            #endif
        } else {
            debugPrint("SwedbankPaySDK: onConsumerIdentified - failed to get consumerProfileRef")
        }
        
        createPaymentOrder()
    }
}

extension SwedbankPaySDKController : SwedbankPayWebViewControllerDelegate {
    func add(webViewController: SwedbankPayWebViewControllerBase) {
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
        dismissExtraWebViews()
    }
    
    func remove(webViewController: SwedbankPayWebViewControllerBase) {
        if webViewController === rootWebViewController {
            reloadPaymentMenu()
        } else if let navigationController = presentedViewController as? UINavigationController {
            if navigationController.visibleViewController === webViewController {
                if navigationController.viewControllers.count > 1 {
                    navigationController.popViewController(animated: true)
                } else {
                    dismissExtraWebViews()
                }
            } else {
                let viewControllers = navigationController.viewControllers.filter {
                    $0 !== webViewController
                }
                if viewControllers.isEmpty {
                    dismissExtraWebViews()
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
            delegate?.paymentOrderDidHide()
        }
    }
    
    private func dismissExtraWebViews() {
        dismiss(animated: true, completion: nil)
    }
    
    func allowWebViewNavigation(
        navigationAction: WKNavigationAction,
        completion: @escaping (Bool) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            completion(true)
            return
        }
        if url.absoluteString == "about:blank" {
            // Always allow loading the empty page.
            // This is chiefly for tests.
            completion(true)
        } else {
            switch webRedirectBehavior {
            case .Default:
                viewModel.configuration.decidePolicyForPaymentMenuRedirect(
                    navigationAction: navigationAction
                ) {
                    let allow = $0 == .openInWebView
                    DispatchQueue.main.async {
                        completion(allow)
                    }
                }
                
            case .AlwaysUseWebView:
                completion(true)
                
            case .AlwaysUseBrowser:
                completion(false)
            }
        }
    }
    
    func webViewDidFailNavigation(error: Error) {
        paymentFailed(error: WebContentError.RedirectFailure(error: error))
    }
}
