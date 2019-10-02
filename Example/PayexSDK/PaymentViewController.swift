import UIKit
import PayexSDK

class PaymentViewController: UIViewController {
    
    /// PayexSDKController will instantiate UIViewController into this view and a WKWebView afterwards
    @IBOutlet private weak var webViewContainer: UIView!
    
    var paymentData: PaymentData?
    var result: PaymentResult = .success
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let payexSDKController = PayexSDKController.init(headers: paymentData?.headers, backendUrl: paymentData?.backendUrl, merchantData: paymentData?.merchantData, consumerData: paymentData?.consumerData)
        addChildViewController(payexSDKController)
        payexSDKController.view.translatesAutoresizingMaskIntoConstraints = false
        webViewContainer.addSubview(payexSDKController.view)
        
        NSLayoutConstraint.activate([
            payexSDKController.view.topAnchor.constraint(equalTo: webViewContainer.topAnchor),
            payexSDKController.view.leftAnchor.constraint(equalTo: webViewContainer.leftAnchor),
            payexSDKController.view.rightAnchor.constraint(equalTo: webViewContainer.rightAnchor),
            payexSDKController.view.bottomAnchor.constraint(equalTo: webViewContainer.bottomAnchor),
        ])
        
        payexSDKController.didMove(toParentViewController: self)
        payexSDKController.delegate = self
    }
}

/// Need to conform to PayexSDKDelegate protocol
extension PaymentViewController: PayexSDKDelegate {
    
    /// Handle payment complete event
    func paymentComplete() {
        // Example
        result = .success
        performSegue(withIdentifier: "showResult", sender: self)
    }
    
    /// Handle payment failed event
    func paymentFailed() {
        // Example
        result = .error
        performSegue(withIdentifier: "showResult", sender: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showResult" {
            if let vc = segue.destination as? ResultViewController {
                vc.result = self.result
            }
        }
    }
}
