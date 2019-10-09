import UIKit
import WebKit
import Alamofire
import AlamofireObjectMapper
import ObjectMapper

public protocol PayexSDKDelegate: AnyObject {
    func paymentComplete()
    
    func paymentFailed(_ problem: PayexSDK.Problem)
}

public class PayexSDKController: UIViewController {
    
    public weak var delegate: PayexSDKDelegate?
    
    lazy private var viewModel = PayexSDKViewModel()
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /**
     Initializes the Payex SDK, and depending on the consumerData, starts the payment process with user identification or anonymous process
     
     - parameter headers: header dictionary
     - parameter backendUrl: merchant's own backend URL
     - parameter merchantData: merchant and purchase information
     - parameter consumerData: consumer identification information, optional; if not provided, user will be anonymous
     */
    public init<T: Encodable>(headers: Dictionary<String, String>?, backendUrl: String?, merchantData: T?, consumerData: Any? = nil) {
        super.init(nibName: nil, bundle: nil)

        if let headers = headers {
            viewModel.setHeaders(headers)
        }
        
        viewModel.consumerProfileRef = nil
        viewModel.backendUrl = backendUrl
        
        /// Convert merchantData into JSON
        if let merchantData = merchantData {
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            if let data = try? encoder.encode(merchantData) {
                viewModel.merchantData = String(data: data, encoding: .utf8)
            } else {
                let msg: String = SDKProblemString.merchantDataSerializationFailed.rawValue
                self.paymentFailed(PayexSDK.Problem.Client(.MobileSDK(.InvalidRequest(message: msg, raw: nil))))
            }
        } else {
            let msg: String = SDKProblemString.merchantDataMissing.rawValue
            self.paymentFailed(PayexSDK.Problem.Client(.MobileSDK(.InvalidRequest(message: msg, raw: nil))))
        }
        
        viewModel.consumerData = consumerData
        
        if consumerData == nil {
            createPaymentOrder()
        } else {
            viewModel.identifyUser(successCallback: { [weak self] operationsList in
                self?.createConsumerURL(operationsList)
            }, errorCallback: { [weak self] problem in
                self?.paymentFailed(problem)
            })
        }
        
    }
    
    /// Creates paymentOrder
    private func createPaymentOrder() {
        viewModel.createPaymentOrder(successCallback: { [weak self] operationsList in
            self?.createPaymentOrderURL(operationsList)
        }, errorCallback: { [weak self] problem in
            self?.paymentFailed(problem)
        })
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.view.backgroundColor = UIColor.white
    }
    
    /// Dismisses the viewcontroller when close button has been pressed
    @objc func closeButtonPressed() -> Void {
        self.dismiss(animated: true, completion: nil)
    }
    
    /**
     Creates consumer identification JavaScript URL String from list of operations and executes loadWebViewURL with it along with correct type
     
     - parameter list: List of operations available; need to find correct type of operation from it
     */
    private func createConsumerURL(_ list: OperationsList) {
        let operationType = OperationTypeString.viewConsumerIdentification.rawValue
        if let jsURL: String = list.operations.first(where: {$0.contentType == "application/javascript" && $0.rel == operationType})?.href {
            loadWebViewURL(jsURL, type: .consumerIdentification)
        } else {
            let msg: String = SDKProblemString.consumerIdentificationWebviewCreationFailed.rawValue
            self.paymentFailed(PayexSDK.Problem.Client(.MobileSDK(.InvalidRequest(message: msg, raw: nil))))
        }
    }
    
    /**
     Creates payment order JavaScript URL String from list of operations and executes loadWebViewURL with it along with correct type
     
     - parameter list: List of operations available; need to find correct type of operation from it
     */
    private func createPaymentOrderURL(_ list: OperationsList) {
        let operationType = OperationTypeString.viewPaymentOrder.rawValue
        if let jsURL: String = list.operations.first(where: {$0.contentType == "application/javascript" && $0.rel == operationType})?.href {
            loadWebViewURL(jsURL, type: .paymentOrder)
        } else {
            let msg: String = SDKProblemString.paymentWebviewCreationFailed.rawValue
            self.paymentFailed(PayexSDK.Problem.Client(.MobileSDK(.InvalidRequest(message: msg, raw: nil))))
        }
    }
    
    /**
     Creats a HTML string to load into WKWebView
     
     - parameter url: JavaScript URL String to replace a placeholder with from HTML template
     - parameter type: the type of the WKWebView HTML to load, and what kind of JavaScript events to create for it
     */
    private func loadWebViewURL(_ url: String, type: WebViewType) {
        
        let html: String
        let contentController = WKUserContentController();
        switch type {
        case .consumerIdentification:
            html = createCheckinHTML(url)
            contentController.add(self, name: ConsumerEvent.onConsumerIdentified.rawValue)
            contentController.add(self, name: ConsumerEvent.onShippingDetailsAvailable.rawValue)
            contentController.add(self, name: ConsumerEvent.onError.rawValue)
        case .paymentOrder:
            html = createCheckoutHTML(url)
            contentController.add(self, name: PaymentEvent.onPaymentMenuInstrumentSelected.rawValue)
            contentController.add(self, name: PaymentEvent.onPaymentCompleted.rawValue)
            contentController.add(self, name: PaymentEvent.onPaymentFailed.rawValue)
            contentController.add(self, name: PaymentEvent.onPaymentCreated.rawValue)
            contentController.add(self, name: PaymentEvent.onPaymentToS.rawValue)
            contentController.add(self, name: PaymentEvent.onError.rawValue)
        }
        
        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        
        let webView = WKWebView(frame: view.bounds, configuration: config)
        webView.navigationDelegate = self
        webView.contentMode = .scaleAspectFill
        view.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        
        // Constrain the WKWebView into the area below navigation Bar
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor, constant: self.topLayoutGuide.length),
            webView.leftAnchor.constraint(equalTo: view.leftAnchor),
            webView.rightAnchor.constraint(equalTo: view.rightAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        
        // Load the created HTML
        webView.loadHTMLString(html, baseURL: nil)
    }
    
    /// Show terms and conditions URL using ToSViewController
    fileprivate func showTos(url: String) {
        debugPrint("PayexSDK: Open Terms of Service URL \(url)")
        
        let tos = ToSViewController.init(tosUrl: url)
        self.present(tos, animated: true, completion: nil)
    }
}

/// Extension to conform to PayexSDKDelegate protocol
extension PayexSDKController: WKNavigationDelegate {
    fileprivate func paymentFailed(_ problem: PayexSDK.Problem) {
        debugPrint("PayexSDK: Payment failed")
        
        self.delegate?.paymentFailed(problem)
    }
    
    fileprivate func paymentComplete() {
        debugPrint("PayexSDK: Payment complete")
        
        self.delegate?.paymentComplete()
    }
}

/// Extension handles the WKWebview JavaScript events
extension PayexSDKController: WKScriptMessageHandler {
    
    // Create event handlers
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
            
        // Consumer identification events
        case ConsumerEvent.onConsumerIdentified.rawValue:
            handleConsumerIdentifiedEvent(message.body)
        case ConsumerEvent.onShippingDetailsAvailable.rawValue:
            debugPrint("PayexSDK: onShippingDetailsAvailable event received")
        case ConsumerEvent.onError.rawValue:
            let msg: String = message.body as? String ?? "Unknown error"
            self.paymentFailed(PayexSDK.Problem.Client(.MobileSDK(.InvalidRequest(message: msg, raw: nil))))
            
        // Payment events
        case PaymentEvent.onPaymentMenuInstrumentSelected.rawValue:
            debugPrint("PayexSDK: onPaymentMenuInstrumentSelected event received")
        case PaymentEvent.onPaymentCompleted.rawValue:
            debugPrint("PayexSDK: onPaymentCompleted event received")
            paymentComplete()
        case PaymentEvent.onPaymentFailed.rawValue:
            let msg: String = message.body as? String ?? "Unknown error"
            self.paymentFailed(PayexSDK.Problem.Client(.MobileSDK(.InvalidRequest(message: msg, raw: nil))))
        case PaymentEvent.onPaymentCreated.rawValue:
            debugPrint("PayexSDK: onPaymentCreated event received")
        case PaymentEvent.onPaymentToS.rawValue:
            handleToSEvent(message.body)
        case PaymentEvent.onError.rawValue:
            let msg: String = message.body as? String ?? "Unknown error"
            self.paymentFailed(PayexSDK.Problem.Client(.MobileSDK(.InvalidRequest(message: msg, raw: nil))))
        default:
            debugPrint("PayexSDK: undefined event received")
        }
    }
    
    /**
     User identified event received
     
     - parameter messageBody: user identification String saved as consumerProfileRef
     */
    private func handleConsumerIdentifiedEvent(_ messageBody: Any) {
        debugPrint("PayexSDK: onConsumerIdentified event received")
        if let str = messageBody as? String {
            viewModel.consumerProfileRef = str
            debugPrint("PayexSDK: consumerProfileRef: \(str)")
        } else {
            debugPrint("PayexSDK: onConsumerIdentified - failed to get consumerProfileRef")
        }
        createPaymentOrder()
    }
    
    /**
     Terms of service event received
     
     - parameter messageBody: terms of service URL String in an NSDictionary
     */
    private func handleToSEvent(_ messageBody: Any) {
        debugPrint("PayexSDK: onPaymentToS event received")
        if let dict = messageBody as? NSDictionary {
            if let url = dict["openUrl"] as? String {
                showTos(url: url)
            }
        } else {
            debugPrint("PayexSDK: Terms of Service URL could not be found")
        }
    }
}

