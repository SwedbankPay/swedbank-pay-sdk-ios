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
    func paymentOrderDidShow(info: SwedbankPaySDK.ViewPaymentLinkInfo)
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
    func paymentOrderDidShow(info: SwedbankPaySDK.ViewPaymentLinkInfo) {}
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
///
/// `SwedbankPaySDKController` supports subclassing. In most cases you should not
/// need to do so, but if you select the `SwedbankPaySDKConfiguration` dynamically,
/// and you support view controller state saving, then you must create a subclass
/// and override the `configuration` property.
///
/// `SwedbankPaySDKController` conforms to `UIViewControllerRestoration`;
/// it can restore itself and subclasses. For convenience, the no-argument constructor sets `Self`
/// as the restoration class. It is also possible to use `Self` as the restoration class for a
/// `SwedbankPaySDKController` created form a storyboard, but the regular restoration
/// mechanism should also work in that case. Notably, state restoration will not work if you use the
/// legacy intitializers that take a `SwedbankPaySDKConfiguration` directly.
///
/// If you use state restoration, and make use of the `userData` argument of `startPayment`,
/// or the `userInfo` property of `SwedbankPaySDK.ViewPaymentOrderInfo`, then those values
/// must be either `NSCoding` or `Codable`. If you use `Codable` types (recommended), you must also
/// register them with the SDK by calling `SwedbankPaySDK.registerCodable` for those types.
/// You can also register any custom `Codable` `Error` types your  `SwedbankPaySDKConfiguration`
/// may throw; otherwise those will be turned to `NSError` during state saving.
open class SwedbankPaySDKController: UIViewController, UIViewControllerRestoration {
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
    
    /// If you are using state restoration, and there is an error in the restoration process,
    /// the SwedbankPaySDKController will be put in an error state with one of these errors.
    public enum StateRestorationError: Error {
        /// You tried to use a `Codable` as `userData` or as
        /// `SwedbankPaySDK.ViewPaymentOrderInfo.userInfo`,
        /// but the type was not registered  with `SwedbankPaySDK.registerCodable`.
        ///
        /// The associated value is the type name.
        /// You should call `SwedbankPaySDK.registerCodable(Foo.self)` during app initialization,
        /// e.g. in `UIApplicationDelegate.application(_:willFinishLaunchingWithOptions:)`.
        case unregisteredCodable(String)
        
        /// The state was restored from a `SwedbankPaySDKController` that was initialized using
        /// the legacy initializer that takes a configuration directly. State restoration will not work with such a setup.
        case nonpersistableConfiguration
        
        /// There was an unexpected error condition during the restoration process.
        case unknown
    }
    
    /// The default value for `configuration`. If your setup does not need multiple configurations
    /// in a single app, then you should set your configuration here and not worry about subclassing
    /// `SwedbankPaySDKController`.
    public static var defaultConfiguration: SwedbankPaySDKConfiguration?

    /// The `SwedbankPaySDKConfiguration` used by this `SwedbankPaySDKController`.
    ///
    /// Note that `SwedbankPaySDKController` accesses this property only once during initialization,
    /// and will use the returned value thereafter. Hence, you cannot change the configuration "in-flight"
    /// by changing the value returned from here.
    open var configuration: SwedbankPaySDKConfiguration {
        if let configuration = nonpersistableConfiguration {
            return configuration
        } else if let configuration = SwedbankPaySDKController.defaultConfiguration {
            return configuration
        } else {
            preconditionFailure("SwedbankPaySDKController.defaultConfiguration not set. Set defaultConfiguration or subclass SwedbankPaySDKController to implement dynamic configuration selection.")
        }
    }
    
    /// A delegate to receive callbacks as the state of SwedbankPaySDKController changes.
    public weak var delegate: SwedbankPaySDKDelegate? {
        didSet {
            notifyDelegateIfNeeded()
        }
    }
    
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
    public var currentPaymentOrder: SwedbankPaySDK.ViewPaymentLinkInfo? {
        return viewModel?.viewPaymentOrderInfo
    }
    
    /// `true` if the payment order is currently shown, `false` otherwise
    public var showingPaymentOrder: Bool {
        return currentPaymentOrder != nil && rootWebViewController.isAtRoot
    }
    
    /// `true` if the payment order is currently being updated, `false` otherwise
    public var updatingPaymentOrder: Bool {
        return viewModel?.updating == true
    }
    
    /// Options for `webRedirectBehavior`
    ///
    /// Testing has shown that some pages are not compatible with WKWebView.
    /// In those cases, the redirect must be opened in the browser instead.
    /// The default behavior is to allow the `configuration` to control
    /// the redirect (which, in turn, defaults to using the web view) but attempt to
    /// detect the incompatibility and allow for retry with the "always use browser"
    /// behavior.
    public enum WebRedirectBehavior {
        /// Call `SwedbankPaySDKConfiguration.decidePolicyForPaymentMenuRedirect`
        /// to determine the outcome.
        ///
        /// Also attempts to detect the payment getting stuck. If that happens, the SDK
        /// will alert the user. If the user chooses to retry the payment,
        /// `webRedirectBehavior` is set to `.AlwaysUseBrowser` and
        /// the payment menu is reloaded.
        case Default
        /// Always use the web view; do not call `decidePolicyForPaymentMenuRedirect`.
        case AlwaysUseWebView
        /// Always use the browser; do not call `decidePolicyForPaymentMenuRedirect`.
        case AlwaysUseBrowser
    }
    
    /// Controls how redirects from the payment menu are handled.
    ///
    /// When this value is `.Default`, the SDK will attempt to detect the payment
    /// getting stuck, and allows the user to retry the payment with this setting
    /// changed to `.AlwaysUseBrowser`.
    ///
    /// When this value is not `.Default`, the SDK will not attempt to detect the payment
    /// getting stuck.
    public var webRedirectBehavior = WebRedirectBehavior.Default {
        didSet {
            rootWebViewController.shouldShowExternalAppAlerts = webRedirectBehavior == .Default
        }
    }
    
    public var webNavigationLogger: ((URL) -> Void)? {
        get {
            return rootWebViewController.navigationLogger
        }
        set {
            rootWebViewController.navigationLogger = newValue
        }
    }
            
    private let nonpersistableConfiguration: SwedbankPaySDKConfiguration?
    
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
    
    private var viewModel: SwedbankPaySDKViewModel? {
        didSet {
            oldValue?.onStateChanged = nil
            viewModel?.onStateChanged = { [unowned self] in
                self.updateUI()
                self.notifyDelegateIfNeeded()
            }
            updateUI()
            notifyDelegateIfNeeded()
        }
    }
    
    public required init?(coder aDecoder: NSCoder) {
        nonpersistableConfiguration = nil
        super.init(coder: aDecoder)
    }
    
    /// Create a new `SwedbankPaySDKController`.
    /// Call `startPayment` to start the payment.
    public required init() {
        nonpersistableConfiguration = nil
        super.init(nibName: nil, bundle: nil)
        restorationClass = Self.self
    }
    
    /// Note: This is a legacy initializer. Please consider using the no-argument initializer
    /// and `startPayment` instead.
    ///
    /// Initializes the SwedbankPaySDKController, and depending on the `consumerData`,
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
    
    /// Note: This is a legacy initializer. Please consider using the no-argument initializer
    /// and `startPayment` instead.
    ///
    /// Initializes the SwedbankPaySDKController, and starts the payment process
    ///  with consumer identification or anonymous process
    /// - parameter configuration: Configuration object that handles creating
    ///  and manipulating Consumer Identification Sessions and Payment Orders as needed.
    /// - parameter withCheckin: if `true`, performs checkin berfore creating the payment order
    /// - parameter consumer: consumer object for the checkin
    /// - parameter paymentOrder: the payment order to create
    /// - parameter userData: user data for your configuration. This value will be provided to your configuration callbacks.
    public init(
        configuration: SwedbankPaySDKConfiguration,
        withCheckin: Bool,
        consumer: SwedbankPaySDK.Consumer?,
        paymentOrder: SwedbankPaySDK.PaymentOrder?,
        userData: Any?
    ) {
        nonpersistableConfiguration = configuration
        super.init(nibName: nil, bundle: nil)
        startPayment(withCheckin: withCheckin, consumer: consumer, paymentOrder: paymentOrder, userData: userData)
    }
        
    deinit {
        viewModel?.onStateChanged = nil
        viewModel?.cancelUpdate()
        SwedbankPaySDK.removeCallbackUrlDelegate(self)
        set(scriptMessageHandler: nil)
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        addRootWebViewController()
        addInitialLoadingIndicator()
        
        updateUI()
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        SwedbankPaySDK.addCallbackUrlDelegate(self)
        self.view.backgroundColor = UIColor.white
    }
    
    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        SwedbankPaySDK.removeCallbackUrlDelegate(self)
    }
    
    /// Starts a new payment.
    ///
    /// Calling this when a payment is already started has no effect.
    ///
    /// - parameter withCheckin: `true` to include the customer identification flow, `false` otherwise
    /// - parameter consumer: the `Consumer` to use for customer identification
    /// - parameter paymentOrder: the `PaymentOrder` to use to create the payment
    /// - parameter userData: any additional data you may need for the identification and/or payment
    public func startPayment(
        withCheckin: Bool,
        isV3: Bool = false,
        consumer: SwedbankPaySDK.Consumer?,
        paymentOrder: SwedbankPaySDK.PaymentOrder?,
        userData: Any?
    ) {
        let maybeViewModel = self.viewModel
        let viewModel = maybeViewModel ?? SwedbankPaySDKViewModel(
            consumer: consumer, paymentOrder: paymentOrder, userData: userData
        )
        if maybeViewModel == nil {
            self.viewModel = viewModel
        }
        viewModel.start(useCheckin: withCheckin, isV3: isV3, configuration: configuration)
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
        viewModel?.updatePaymentOrder(updateInfo: updateInfo)
    }
    
    private func createRootWebViewController() -> SwedbankPayWebViewController {
        let config = WKWebViewConfiguration()
        config.userContentController = userContentController
        return SwedbankPayWebViewController(configuration: config, delegate: self)
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
    
    /*
     TODO v3: must know whether to use v2 or v3 html templates
     modify SwedbankPaySDKViewModel.State to contain that information
     modify showCheckin and showPaymentOrder to choose the template accordingly
    */
    private func updateUI() {
        if isViewLoaded, let viewModel = viewModel {
            switch viewModel.state {
                case .idle:
                    break
                case .initializingConsumerSession:
                    initialLoadingIndicator.startAnimating()
                case .identifyingConsumer(let info, let options):
                    showCheckin(info, options: options)
                case .creatingPaymentOrder:
                    initialLoadingIndicator.startAnimating()
                case .paying(let info, options: let options, failedUpdate: let failedUpdate):
                    if failedUpdate == nil {
                        showPaymentOrder(info: info, delay: false, options: options)
                    } else {
                        print("failed paying: \(String(describing: failedUpdate))")
                        initialLoadingIndicator.stopAnimating()
                    }
                case .updatingPaymentOrder:
                    initialLoadingIndicator.startAnimating()
                case .complete:
                    break
                case .canceled:
                    break
                case .failed(let linkInfo, let error):
                    if let linkInfo = linkInfo {
                        print("failed with paymentInfo: \(linkInfo) error: \(error)")
                    } else {
                        print("failed with error: \(error)")
                    }
                    initialLoadingIndicator.stopAnimating()
                    //Now the integrators need to display the error to the user.
                    
                    break
                case .payerIdentified(_, options: let options):
                    if options.contains(.useCheckin) {
                        //TODO: updating payment if needed!
                        initialLoadingIndicator.startAnimating()
                    }
                    break
            }
        }
    }
    
    private func notifyDelegateIfNeeded() {
        if let viewModel = viewModel {
            switch viewModel.state {
            case .complete:
                delegate?.paymentComplete()
            case .canceled:
                delegate?.paymentCanceled()
            case .failed(_, let error):
                delegate?.paymentFailed(error: error)
            case .paying(_, options: _, failedUpdate: let failedUpdate?):
                delegate?.updatePaymentOrderFailed(updateInfo: failedUpdate.updateInfo, error: failedUpdate.error)
            default:
                break
            }
        }
    }
    
    /// Creates consumer identification JavaScript URL String from list of operations and executes loadWebViewURL with it along with correct type
    /// - parameter list: List of operations available; need to find correct type of operation from it
    private func showCheckin(_ info: SwedbankPaySDK.IdentifyingVersion, options: SwedbankPaySDK.VersionOptions) {
        //TODO: use isV3 to select template
        switch info {
            case .v2(let info):
                showCheckin(info)
            case .v3(let info):
                showPaymentOrder(info: info, delay: false, options: options)
        }
    }
    
    /// Version 2 checkin
    private func showCheckin(_ info: SwedbankPaySDK.ViewConsumerIdentificationInfo) {
        loadPage(
            baseURL: info.webViewBaseURL,
            template: SwedbankPayWebContent.checkInTemplate,
            scriptUrl: info.viewConsumerIdentification
        ) { [weak self] (event, argument) in
            self?.on(consumerEvent: event, argument: argument)
        }
    }
    
    private func showPaymentOrder(info: SwedbankPaySDK.ViewPaymentLinkInfo, delay: Bool, options: SwedbankPaySDK.VersionOptions) {
        //TODO: use isV3 to select template
        if info.isV3 {
            print(SwedbankPayWebContent.paymentTemplateV3)
        }
        loadPage(
            baseURL: info.webViewBaseURL,
            template: info.isV3 ? SwedbankPayWebContent.paymentTemplateV3 : SwedbankPayWebContent.paymentTemplate,
            scriptUrl: info.viewPaymentLink,
            delay: delay
        ) { [weak self] (event, argument) in
            self?.on(paymentEvent: event, argument: argument)
        }
        delegate?.paymentOrderDidShow(info: info)
    }
    
    private func reloadPaymentMenu(delay: Bool = false) {
        if case .paying(let info, options: let options, _) = viewModel?.state {
            dismissExtraWebViews()
            showPaymentOrder(info: info, delay: delay, options: options)
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
    
    // MARK: State Restoration
    
    private static let restorableStateVersion: Int64 = 1
    private enum RestorableStateKeys: String {
        case version = "com.swedbankpay.mobilesdk.version"
        case viewModel = "com.swedbankpay.mobilesdk.viewmodel"
        case hadNonpersistableConfiguration = "com.swedbankpay.mobilesdk.badconfig"
    }
    
    open class func viewController(
        withRestorationIdentifierPath identifierComponents: [String],
        coder: NSCoder
    ) -> UIViewController? {
        
        guard coder.decodeInt64(forKey: RestorableStateKeys.version.rawValue) == restorableStateVersion else {
            return nil
        }
        
        let viewController = Self()
        viewController.restorationIdentifier = identifierComponents.last
        viewController.restorationClass = self
        return viewController
    }
    
    open override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        
        coder.encode(SwedbankPaySDKController.restorableStateVersion, forKey: RestorableStateKeys.version.rawValue)
        
        guard nonpersistableConfiguration == nil else {
            print("""
Warning: SwedbankPaySDKController initialized with nonpersistable configuration but asked to save state.
State saving only works if SwedbankPaySDKController is created with the no-argument initializer or from a storyboard.
You need to supply the configuration either by SwedbankPaySDKController.defaultConfiguration, or by subclassing
and overriding the configuration property.
""")
            coder.encode(true, forKey: RestorableStateKeys.hadNonpersistableConfiguration.rawValue)
            return
        }
        
        guard let viewModel = viewModel else {
            return
        }
        
        do {
            let viewModelData = try PropertyListEncoder().encode(viewModel)
            coder.encode(viewModelData, forKey: RestorableStateKeys.viewModel.rawValue)
        } catch {
            print("Warning: Failed to encode state of \(self): \(error)")
        }
    }
    
    open override func decodeRestorableState(with coder: NSCoder) {
        super.decodeRestorableState(with: coder)
        guard coder.decodeInt64(forKey: RestorableStateKeys.version.rawValue) == SwedbankPaySDKController.restorableStateVersion else {
            print("Warning: incompatible SwedbankPaySDKController saved state version; are you a time traveler?")
            return
        }
        
        do {
            if coder.decodeBool(forKey: RestorableStateKeys.hadNonpersistableConfiguration.rawValue) {
                print("""
Warning: SwedbankPaySDKController initialized with nonpersistable configuration but asked to restore state.
State saving only works if SwedbankPaySDKController is created with the no-argument initializer or from a storyboard.
You need to supply the configuration either by SwedbankPaySDKController.defaultConfiguration, or by subclassing
and overriding the configuration property.
""")
                throw StateRestorationError.nonpersistableConfiguration
            } else {
                guard let viewModelData = coder.decodeObject(of: NSData.self, forKey: RestorableStateKeys.viewModel.rawValue) else {
                    // should never happen
                    throw StateRestorationError.unknown
                }
                // should never throw
                let viewModel = try PropertyListDecoder().decode(SwedbankPaySDKViewModel.self, from: viewModelData as Data)
                self.viewModel = viewModel
            }
        } catch {
            let viewModel = SwedbankPaySDKViewModel(consumer: nil, paymentOrder: nil, userData: nil)
            let stateRestorationError = error as? StateRestorationError ?? .unknown
            viewModel.onFailed(error: stateRestorationError)
            self.viewModel = viewModel
        }
    }
    
    open override func applicationFinishedRestoringState() {
        super.applicationFinishedRestoringState()
        viewModel?.awakeAfterDecode(configuration: configuration)
    }
}

// MARK: Payment process URLs
private extension SwedbankPaySDKController {
    private func ensurePath(url: URL) -> URL {
        return url.path.isEmpty ? URL(string: "/", relativeTo: url)!.absoluteURL : url.absoluteURL
    }
    
    func handlePaymentProcessUrl(url: URL) -> Bool {
        guard let vm = viewModel, let info = vm.viewPaymentOrderInfo else {
            return false
        }
        
        // WKWebView silently turns https://foo.bar to https://foo.bar/
        // So append a path to the payment urls if needed
        switch url.absoluteURL {
        case ensurePath(url: info.completeUrl):
            vm.onComplete()
            return true
        case info.cancelUrl.map(ensurePath(url:)):
            vm.onCanceled()
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
    func paymentFailed(error: Error) {
        viewModel?.onFailed(error: error)
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
        guard let paymentUrl = viewModel?.viewPaymentOrderInfo?.paymentUrl else {
            return false
        }
        // See SwedbankPaySDKConfiguration for discussion on why we need to do this.
        return url == paymentUrl
            || viewModel?.configuration.url(url, matchesPaymentUrl: paymentUrl) == true
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
        case .payerIdentified:
            debugPrint("user payer identity: \(argument ?? "no args")")
            viewModel?.handlePayerIdentified(argument)
        case .generalEvent:
            debugPrint("generalEvent from JS: \(argument ?? "no args")")
        }
    }
    
    /// Consumer identified event received
    /// - parameter messageBody: consumer identification String saved as consumerProfileRef
    private func handleConsumerIdentifiedEvent(_ messageBody: Any?) {
        debugPrint("SwedbankPaySDK: onConsumerIdentified event received")
        if let str = messageBody as? String {
            viewModel?.continue(consumerProfileRef: str)
            
            #if DEBUG
            debugPrint("SwedbankPaySDK: consumerProfileRef set to: \(str)")
            #endif
        } else {
            debugPrint("SwedbankPaySDK: onConsumerIdentified - failed to get consumerProfileRef")
        }
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
    
    func webViewControllerRetryWithBrowserRedirectBehavior(_ webViewController: SwedbankPayWebViewController) {
        if webViewController === rootWebViewController {
            webRedirectBehavior = .AlwaysUseBrowser
            reloadPaymentMenu()
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
                guard let configuration = viewModel?.configuration else {
                    completion(true)
                    return
                }
                configuration.decidePolicyForPaymentMenuRedirect(
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

extension SwedbankPaySDKController.WebContentError: Codable {
    private enum CodingKeys: String, CodingKey {
        case discriminator
        case scriptUrl
        case terminalFailure
        case error
        case codableErrorType
    }
    
    private enum Discriminator: String, Codable {
        case scriptLoadingFailure
        case scriptError
        case redirectFailure
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Discriminator.self, forKey: .discriminator) {
        case .scriptLoadingFailure:
            self = .ScriptLoadingFailure(scriptUrl: try container.decode(URL.self, forKey: .scriptUrl))
        case .scriptError:
            self = .ScriptError(try container.decodeIfPresent(SwedbankPaySDK.TerminalFailure.self, forKey: .terminalFailure))
        case .redirectFailure:
            let error = try container.decodeErrorIfPresent(codableTypeKey: .codableErrorType, valueKey: .error)
            self = .RedirectFailure(error: error ?? SwedbankPaySDKController.StateRestorationError.unknown)
        }
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .ScriptLoadingFailure(let scriptUrl):
            try container.encode(Discriminator.scriptLoadingFailure, forKey: .discriminator)
            try container.encode(scriptUrl, forKey: .scriptUrl)
        case .ScriptError(let terminalFailure):
            try container.encode(Discriminator.scriptError, forKey: .discriminator)
            try container.encodeIfPresent(terminalFailure, forKey: .terminalFailure)
        case .RedirectFailure(let error):
            try container.encode(Discriminator.redirectFailure, forKey: .discriminator)
            try container.encodeIfPresent(error: error, codableTypeKey: .codableErrorType, valueKey: .error)
        }
    }
}

extension SwedbankPaySDKController.StateRestorationError: Codable {
    private enum CodingKeys: String, CodingKey {
        case discriminator
        case unregisteredTypeName
    }
    
    private enum Discriminator: String, Codable {
        case unregisteredCodable
        case nonpersistableConfiguration
        case unknown
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Discriminator.self, forKey: .discriminator) {
        case .unregisteredCodable:
            self = .unregisteredCodable(try container.decode(String.self, forKey: .unregisteredTypeName))
        case .nonpersistableConfiguration:
            self = .nonpersistableConfiguration
        case .unknown:
            self = .unknown
        }
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .unregisteredCodable(let unregisteredTypeName):
            try container.encode(Discriminator.unregisteredCodable, forKey: .discriminator)
            try container.encode(unregisteredTypeName, forKey: .unregisteredTypeName)
        case .nonpersistableConfiguration:
            try container.encode(Discriminator.nonpersistableConfiguration, forKey: .discriminator)
        case .unknown:
            try container.encode(Discriminator.unknown, forKey: .discriminator)
        }
    }
}
