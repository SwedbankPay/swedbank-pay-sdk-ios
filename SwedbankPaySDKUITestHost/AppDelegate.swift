import UIKit
import SwedbankPaySDK

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    private var theWindow: UIWindow?
    private var paymentDelegate: PaymentDelegate?
        
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions
            launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let window = UIWindow()
        theWindow = window
        window.rootViewController = createRootViewController()
        window.makeKeyAndVisible()
        
        return true
    }
    
    private func createRootViewController() -> UIViewController {
        let viewController = SwedbankPaySDKController(
            configuration: paymentTestConfiguration,
            paymentOrder: testPaymentOrder
        )
        
        createPaymentDelegate()
        viewController.delegate = paymentDelegate
        viewController.webRedirectBehavior = .AlwaysUseWebView // TODO: fix resources
        
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
