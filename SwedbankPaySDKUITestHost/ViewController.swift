import UIKit
import SwedbankPaySDK

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
        
        viewController.startPayment(withCheckin: withCheckin, isV3: isV3, consumer: nil, paymentOrder: testPaymentOrder, userData: nil)
        return viewController
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
