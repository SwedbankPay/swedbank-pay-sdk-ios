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
        
        if isV3 {
            var payment = testPaymentOrder
            if CommandLine.arguments.contains("-testInstrument") {
                payment.instrument = SwedbankPaySDK.Instrument.creditCard
                let action = UIAction { action in
                    print("perform test")
                    let order = viewController.currentPaymentOrder!
                    let instruments = order.availableInstruments!
                    let instrument = instruments.first { order.instrument != $0 }   //select any that we havn't selected
                    viewController.updatePaymentOrder(updateInfo: instrument!)
                
                }
                let button = UIBarButtonItem(title: "Test change", image: nil, primaryAction: action)
                button.accessibilityIdentifier = "testMenuButton"
                viewController.navigationItem.rightBarButtonItem = button
            }
            viewController.startPayment(paymentOrder: payment)
        } else {
            let payment = withCheckin ? testPaymentOrderCheckin : testPaymentOrder
            viewController.startPayment(withCheckin: withCheckin, consumer: nil, paymentOrder: payment, userData: nil)
        }
        
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
