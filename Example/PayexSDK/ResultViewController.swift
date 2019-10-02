import UIKit

enum PaymentResult {
    case error
    case success
}

class ResultViewController: UIViewController {
    
    @IBOutlet private weak var resultLabel: UILabel!
    
    var result: PaymentResult = .success
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationItem.setHidesBackButton(true, animated:true);
        
        switch result {
        case .success:
            self.title = "Thank you"
            resultLabel.text = "Payment was successfully completed"
        case .error:
            self.title = "Error"
            resultLabel.text = "There was an error in processing the payment."
        }
    }
    
    @IBAction func doneButtonClicked(_ sender: Any) {
        let viewControllers = self.navigationController!.viewControllers as [UIViewController];
        for viewController: UIViewController in viewControllers {
            if viewController.isKind(of: CheckoutViewController.self) {
                _ = self.navigationController?.popToViewController(viewController, animated: true)
            }
        }
    }
}
