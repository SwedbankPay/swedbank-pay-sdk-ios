import UIKit
import SwedbankPaySDK

class PaymentViewController: UIViewController {
    
    /// SwedbankPaySDKController will instantiate UIViewController into this view and a WKWebView afterwards
    @IBOutlet private weak var webViewContainer: UIView!
    
    var paymentData: PaymentData?
    var result: PaymentResult = .unknown
    var problem: SwedbankPaySDK.Problem?
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let swedbankPaySDKController = SwedbankPaySDKController.init(headers: paymentData?.headers, backendUrl: paymentData?.backendUrl, merchantData: paymentData?.merchantData, consumerData: paymentData?.consumerData)
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
        // Example
        result = .success
        performSegue(withIdentifier: "showResult", sender: self)
    }
    
    /// Handle payment failed event
    func paymentFailed(_ problem: SwedbankPaySDK.Problem) {
        // Example
        self.result = .error
        self.problem = problem
        performSegue(withIdentifier: "showResult", sender: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showResult" {
            if let vc = segue.destination as? ResultViewController {
                vc.result = self.result
                vc.problem = self.problem
            }
        }
    }
}
