import UIKit
import SwedbankPaySDK

class ViewController: UINavigationController {
    private var paymentDelegate: PaymentDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        viewControllers = [createRootViewController()]
    }
    
    private func createRootViewController() -> UIViewController {
        let viewController = SwedbankPaySDKController(
            configuration: paymentTestConfiguration,
            paymentOrder: testPaymentOrder
        )
        
        createPaymentDelegate()
        viewController.delegate = paymentDelegate
        
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
}
