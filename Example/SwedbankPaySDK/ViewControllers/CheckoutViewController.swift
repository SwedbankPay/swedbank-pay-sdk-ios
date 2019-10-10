import UIKit

class CheckoutViewController: UIViewController {
    
    /// Initialize payment process for anonymous user
    @IBAction func startAnonymousPayment(_ sender: Any) {
        PaymentViewModel.shared.setUser(known: false)
        performSegue(withIdentifier: "showPayment", sender: self)
    }
    
    /// Initialize payment process for registered user
    @IBAction func startRegisteredPayment(_ sender: Any) {
        PaymentViewModel.shared.setUser(known: true)
        performSegue(withIdentifier: "showPayment", sender: self)
    }
}
