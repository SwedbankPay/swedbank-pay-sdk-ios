import UIKit
import SwedbankPaySDK

class PaymentViewController: UIViewController {
    
    /// UIView to instantiate the SwedbankPaySDKController into; SwedbankPaySDKController will instantiate WKWebView
    @IBOutlet private weak var webViewContainer: UIView!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.title = "Payment"
        
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor: UIColor.black]
        UINavigationBar.appearance().titleTextAttributes = [NSAttributedStringKey.foregroundColor : UIColor.black]
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        navigationController?.navigationBar.alpha = 1

        let vm = PaymentViewModel.shared
        let swedbankPaySDKController = SwedbankPaySDKController.init(
            headers: vm.headers,
            backendUrl: vm.backendUrl,
            merchantData: vm.sampleMerchantData,
            consumerData: vm.consumerData
        )
        addChildViewController(swedbankPaySDKController)
        webViewContainer.addSubview(swedbankPaySDKController.view)
        swedbankPaySDKController.view.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            swedbankPaySDKController.view.topAnchor.constraint(equalTo: webViewContainer.topAnchor),
            swedbankPaySDKController.view.leftAnchor.constraint(equalTo: webViewContainer.leftAnchor),
            swedbankPaySDKController.view.rightAnchor.constraint(equalTo: webViewContainer.rightAnchor),
            swedbankPaySDKController.view.bottomAnchor.constraint(equalTo: webViewContainer.bottomAnchor),
        ])
        
        swedbankPaySDKController.didMove(toParentViewController: self)
        swedbankPaySDKController.delegate = self
    }
}

/// Need to conform to SwedbankPaySDKDelegate protocol
extension PaymentViewController: SwedbankPaySDKDelegate {
    
    /// Handle payment complete event
    func paymentComplete() {
        PaymentViewModel.shared.setResult(.success)
        performSegue(withIdentifier: "showResult", sender: self)
    }
    
    /// Handle payment failed event
    func paymentFailed(_ problem: SwedbankPaySDK.Problem) {
        PaymentViewModel.shared.setResult(.error, problem: problem)
        performSegue(withIdentifier: "showResult", sender: self)
    }
}
