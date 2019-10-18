import UIKit
import SwedbankPaySDK

class ResultViewController: UIViewController {
    
    @IBOutlet private weak var resultLabel: UILabel!

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.navigationItem.setHidesBackButton(true, animated:true);
        
        self.navigationController?.navigationBar.titleTextAttributes = [
            NSAttributedStringKey.foregroundColor: UIColor.black
        ]
        
        switch PaymentViewModel.shared.result {
        case .success:
            self.title = "Thank you"
            resultLabel.text = "Payment was successfully completed."
        case .error:
            if let problem = PaymentViewModel.shared.problem {
                handleProblem(problem)
            }
            self.title = "Error"
            resultLabel.text = "There was an error in processing the payment."
        case .unknown:
            resultLabel.text = "Something went wrong."
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
    
    /// Prints out the reveived errors, exhaustively, as an example
    private func handleProblem(_ problem: SwedbankPaySDK.Problem) {
        debugPrint("There was an error while handling the payment")
        
        switch problem {
        
        /// Client errors
        case .Client(.MobileSDK(.InvalidRequest(let message, let raw))):
            debugPrint("InvalidRequest: \(String(describing: message)), \(String(describing: raw))")
        case .Client(.MobileSDK(.Unauthorized(let message, let raw))):
            debugPrint("Unauthorized: \(String(describing: message)), \(String(describing: raw))")
        case .Client(.SwedbankPay(let type, let title, let detail, let instance, let action, let problems, let raw)):
            switch type {
            case .Forbidden:
                debugPrint("Forbidden: \(String(describing: title)), \(String(describing: detail)), \(String(describing: instance)),\(String(describing: action)),\(String(describing: problems)),\(String(describing: raw))")
            case .InputError:
                debugPrint("InputError: \(String(describing: title)), \(String(describing: detail)), \(String(describing: instance)),\(String(describing: action)),\(String(describing: problems)),\(String(describing: raw))")
            case .NotFound:
                debugPrint("NotFound: \(String(describing: title)), \(String(describing: detail)), \(String(describing: instance)),\(String(describing: action)),\(String(describing: problems)),\(String(describing: raw))")
            }
        case .Client(.UnexpectedContent(let status, let contentType, let body)):
            debugPrint("UnexpectedContent: \(status), \(String(describing: contentType)), \(String(describing: body))")
        case .Client(.Unknown(let type, let title, let status, let detail, let instance, let raw)):
            debugPrint("Unknown: \(String(describing: type)), \(String(describing: title)), \(String(describing: status)), \(String(describing: detail)), \(String(describing: instance)), \(String(describing: raw))")
        
        /// Server errors
        case .Server(.MobileSDK(.BackendConnectionFailure(let message, let raw))):
            debugPrint("BackendConnectionFailure: \(String(describing: message)), \(String(describing: raw))")
        case .Server(.MobileSDK(.BackendConnectionTimeout(let message, let raw))):
            debugPrint("BackendConnectionTimeout: \(String(describing: message)), \(String(describing: raw))")
        case .Server(.MobileSDK(.InvalidBackendResponse(let body, let raw))):
            debugPrint("InvalidBackendResponse: \(String(describing: body)), \(String(describing: raw))")
        case .Server(.SwedbankPay(let type, let title, let detail, let instance, let action, let problems, let raw)):
            switch type {
            case .ConfigurationError:
                debugPrint("ConfigurationError: \(String(describing: title)), \(String(describing: detail)), \(String(describing: instance)), \(String(describing: action)), \(String(describing: problems)), \(String(describing: raw))")
            case .NotFound:
                debugPrint("NotFound: \(String(describing: title)), \(String(describing: detail)), \(String(describing: instance)), \(String(describing: action)), \(String(describing: problems)), \(String(describing: raw))")
            case .SystemError:
                debugPrint("SystemError: \(String(describing: title)), \(String(describing: detail)), \(String(describing: instance)), \(String(describing: action)), \(String(describing: problems)), \(String(describing: raw))")
            }
        case .Server(.UnexpectedContent(let status, let contentType, let body)):
            debugPrint("UnexpectedContent: \(status), \(String(describing: contentType)), \(String(describing: body))")
        case .Server(.Unknown(let type, let title, let status, let detail, let instance, let raw)):
            debugPrint("Unknown: \(String(describing: type)), \(String(describing: title)), \(status), \(String(describing: detail)), \(String(describing: instance)), \(String(describing: raw))")
        }
    }
}
