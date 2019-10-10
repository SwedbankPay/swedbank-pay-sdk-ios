import UIKit
import SwedbankPaySDK

class PaymentViewController: UIViewController {
    
    /// UIView to instantiate the SwedbankPaySDKController into; SwedbankPaySDKController will instantiate WKWebView
    @IBOutlet private weak var webViewContainer: UIView!

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        let vm = PaymentViewModel.shared
        let swedbankPaySDKController = SwedbankPaySDKController.init(
            headers: vm.headers,
            backendUrl: vm.backendUrl,
            merchantData: vm.sampleMerchantData,
            consumerData: vm.consumerData
        )
        addChildViewController(swedbankPaySDKController)
        swedbankPaySDKController.view.translatesAutoresizingMaskIntoConstraints = false
        webViewContainer.addSubview(swedbankPaySDKController.view)
        
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
