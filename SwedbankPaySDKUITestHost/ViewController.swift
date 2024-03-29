import UIKit
@testable import SwedbankPaySDK

//Quick errors by using strings
extension String: LocalizedError {
    public var errorDescription: String? { return self }
}

class ViewController: UINavigationController {
    
    private var paymentDelegate: PaymentDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if !shouldRestoreState {
            
            viewControllers = [createRootViewController()]
            
            if CommandLine.arguments.contains("-testModalController") {
                
                //Don't dissmiss ourself during process, then we will never get the result.
                let emptyController = UIViewController()
                viewControllers = [emptyController]
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [self] in
                    emptyController.present(createRootViewController(), animated: true)
                }
                
            } else {
                viewControllers = [createRootViewController()]
            }
        }
    }
    
    private func getPaymentOrder(_ withCheckin: Bool, _ nonMerchant: Bool) -> SwedbankPaySDK.PaymentOrder {
        if withCheckin {
            return testPaymentOrderCheckin
        }
        return nonMerchant ? testNonMerchantPaymentOrder : testPaymentOrder
    }
    
    private func createRootViewController() -> UIViewController {
        //To test the webView we need to mock its controllers
        let testExternalURL = CommandLine.arguments.contains("-testExternalURL")
        let viewController = testExternalURL ? MockSwedbankPaySDKController() : SwedbankPaySDKController()
        
        viewController.restorationIdentifier = "paymentViewController"
        
        createPaymentDelegate()
        viewController.delegate = paymentDelegate
        
        let isV3 = CommandLine.arguments.contains("-testV3")
        let withCheckin = CommandLine.arguments.contains("-testCheckin")
        let nonMerchant = CommandLine.arguments.contains("-testNonMerchant")
        let regeneratePayerRef = CommandLine.arguments.contains("-regeneratePayerRef")
        let testEnterprisePayerReference = CommandLine.arguments.contains("-testEnterprisePayerReference")
        if regeneratePayerRef {
            payerRef = UUID.init().uuidString
        }
        var payment = getPaymentOrder(withCheckin, nonMerchant)
        createTestButton(viewController) {
            
            if let order = viewController.currentPaymentOrder {
                print("Current payment order: \n\(order)")
            } else {
                print("No payment order set")
            }
        }
        
        if isV3 {
            if CommandLine.arguments.contains("-testInstrument") {
                payment.instrument = SwedbankPaySDK.Instrument.creditCard
                createTestButton(viewController) {
                    let order = viewController.currentPaymentOrder!
                    let instruments = order.availableInstruments!
                    let instrument = instruments.first { order.instrument != $0 }   //select any that we havn't selected
                    viewController.updatePaymentOrder(updateInfo: instrument!)
                }
                
            } else if CommandLine.arguments.contains("-testAbortPayment") {
                createTestButton(viewController) {
                    viewController.abortPayment()
                }
            } else if CommandLine.arguments.contains("-testVerifyUnscheduledToken") {
                
                payment.operation = .Verify
                payment.generateRecurrenceToken = true
                payment.generateUnscheduledToken = true
                createTestButton(viewController) {
                    
                    self.testExpandTokens(viewController)
                }
            } else if testEnterprisePayerReference || CommandLine.arguments.contains("-testOneClickPayments") {
                
                print("starting with unique ref: \(payerRef)")
                payment.operation = .Verify
                if currentConfig.backendUrl == paymentTestConfigurationPaymentsOnly.backendUrl {
                    
                    payment.generatePaymentToken = true
                    payment.payer = .init(consumerProfileRef: nil, payerReference: payerRef)
                } else {
                    
                    if testEnterprisePayerReference {
                        payment.payer = .init(consumerProfileRef: nil, email: "leia.ahlstrom@payex.com", msisdn: "+46739000001", payerReference: payerRef)
                    } else {
                        
                        // This isn't working!
                        payment.payer = .init(consumerProfileRef: nil, payerReference: payerRef)
                        payment.payer?.nationalIdentifier = .init(socialSecurityNumber: "199710202392", countryCode: "SE")
                    }
                }
                
                createTestButton(viewController) {
                    
                    self.testExpandOneClickTokens(viewController)
                }
            } else if CommandLine.arguments.contains("-debugOneClick") {
                
                payerRef = "A3EB2265-A6EF-4E44-BED8-50E5D6B764AC"
                expandOneClick("/psp/paymentorders/fd1b96f0-07ff-4b96-5c8e-08da2771f05d", viewController.configuration)
            }
            
            viewController.startPayment(paymentOrder: payment)
        } else {
            
            viewController.startPayment(withCheckin: withCheckin, consumer: nil, paymentOrder: payment, userData: nil)
        }
        
        return viewController
    }
    
    // MARK: - test helpers
    
    struct PaymentTokenResponse: Codable {
        var recurrence: Bool?
        var unscheduled: Bool?
    }
    
    private func testExpandTokens(_ viewController: SwedbankPaySDKController) {
        
        guard let paymentId = viewController.currentPaymentOrder?.paymentId else {
            paymentDelegate?.paymentFailed(error: "No payment id found: \(String(describing: viewController.currentPaymentOrder))")
            return
        }
        
        _ = viewController.configuration.expandOperation(paymentId: paymentId, expand: [.paid], endpoint: "tokens") { [self] (result: Result<PaymentTokenResponse, Error>) in
            switch result {
                case .success(let success):
                    if success.recurrence == nil {
                        paymentDelegate?.paymentFailed(error: "No recurrence token created")
                    } else if success.unscheduled == nil {
                        paymentDelegate?.paymentFailed(error: "No unscheduled token created")
                    } else {
                        paymentDelegate?.paymentComplete()
                    }
                case .failure(let failure):
                    paymentDelegate?.paymentFailed(error: failure)
            }
        }
    }
    
    // MARK: one-click tokens
    
    var payerRef = UUID.init().uuidString
    struct ExpandResponse: Codable {
        var paymentOrder: ExpandPaymentOrder
    }
    struct ExpandPaymentOrder: Codable {
        var paid: ExpandPaid?
    }
    struct ExpandPaid: Codable {
        var payeeReference: String
        var tokens: [ExpandTokens]
    }
    struct ExpandTokens: Codable {
        var token: String
    }
    
    private func testExpandOneClickTokens(_ viewController: SwedbankPaySDKController) {
        
        guard let order = viewController.currentPaymentOrder, let paymentId = order.paymentId else {
            paymentDelegate?.paymentFailed(error: "No payment id found: \(String(describing: viewController.currentPaymentOrder))")
            return
        }
        expandOneClick(paymentId, viewController.configuration)
    }
    
    private func expandOneClick(_ paymentId: String, _ configuration: SwedbankPaySDKConfiguration) {
        _ = configuration.expandOperation(paymentId: paymentId, expand: [.paid], endpoint: "expand") { [self] (result: Result<ExpandResponse, Error>) in
            switch result {
                case .success(let success):
                    if let token = success.paymentOrder.paid?.tokens.first?.token {
                        
                        //now redo the purchase with this token!
                        var payment = testPaymentOrder
                        payment.paymentToken = token
                        payment.payer = .init(consumerProfileRef: nil, payerReference: payerRef)
                        redoPurchaseFlow(payment)
                        
                    } else {
                        paymentDelegate?.paymentFailed(error: "No token created, \(String(describing: success))")
                    }
                case .failure(let failure):
                    print(failure)
                    
                    if case SwedbankPaySDK.MerchantBackendError.problem(.server(.unexpectedContent(_, _, let body))) = failure, let body = body {
                        
                        //JSON format miss-match
                        print("could not build data of JSON: \(String(data: body, encoding: .utf8)!)")
                    }
                
                    paymentDelegate?.paymentFailed(error: failure)
            }
        }
    }
    
    private func redoPurchaseFlow(_ payment: SwedbankPaySDK.PaymentOrder) {
        let viewController = SwedbankPaySDKController()
        DispatchQueue.main.async {
            self.pushViewController(viewController, animated: true)
        }
        viewController.delegate = paymentDelegate
        viewController.startPayment(paymentOrder: payment)
    }

    var testButtonAction: (() -> Void)?
    private func createTestButton(_ viewController: UIViewController, _ action: @escaping () -> Void) {
        testButtonAction = action
        let button = UIBarButtonItem(title: "Test change", style: .plain,
                                     target: self, action: #selector(testMenuButtonAction))
        button.accessibilityIdentifier = "testMenuButton"
        viewController.navigationItem.rightBarButtonItem = button
    }
    
    @objc func testMenuButtonAction() {
        testButtonAction?()
    }
    
    private func createPaymentDelegate() {
        guard CommandLine.arguments.count >= 2,
              let port = UInt16(CommandLine.arguments[1]) else {
            return
        }
        do {
            paymentDelegate = try PaymentDelegate(port: port)
        } catch {
            print("Unable to create PaymentDelegate: \(error)")
        }
    }
    
    override func applicationFinishedRestoringState() {
        super.applicationFinishedRestoringState()
        if let viewController = topViewController as? SwedbankPaySDKController {
            createPaymentDelegate()
            viewController.delegate = paymentDelegate
        } else {
            print("Error: top view controller is not SwedbankPaySDKController")
        }
    }
}
