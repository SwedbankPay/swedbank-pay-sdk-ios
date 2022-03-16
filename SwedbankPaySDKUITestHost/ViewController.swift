import UIKit
import SwedbankPaySDK

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
        }
    }
    
    private func createRootViewController() -> UIViewController {
        let viewController = SwedbankPaySDKController()
        
        viewController.restorationIdentifier = "paymentViewController"
        
        createPaymentDelegate()
        viewController.delegate = paymentDelegate
        
        let isV3 = CommandLine.arguments.contains("-testV3")
        let withCheckin = CommandLine.arguments.contains("-testCheckin")
        createTestButton(viewController) {
            print("no commands")
        }
        
        if isV3 {
            var payment = testPaymentOrder
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
            }
            
            viewController.startPayment(paymentOrder: payment)
        } else {
            let payment = withCheckin ? testPaymentOrderCheckin : testPaymentOrder
            viewController.startPayment(withCheckin: withCheckin, consumer: nil, paymentOrder: payment, userData: nil)
        }
        
        return viewController
    }
    
    // MARK: - test helpers
    
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
    
    struct PaymentTokenResponse: Codable {
        var recurrence: Bool?
        var unscheduled: Bool?
    }
    
    private func createTestButton(_ viewController: UIViewController, _ action: @escaping () -> Void) {
        let action = UIAction { _ in action() }
        let button = UIBarButtonItem(title: "Test change", image: nil, primaryAction: action)
        button.accessibilityIdentifier = "testMenuButton"
        viewController.navigationItem.rightBarButtonItem = button
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
