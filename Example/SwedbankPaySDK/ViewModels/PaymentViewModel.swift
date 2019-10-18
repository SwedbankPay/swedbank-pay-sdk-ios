import SwedbankPaySDK

/// Singleton ViewModel for payment data
class PaymentViewModel {
    
    static let shared = PaymentViewModel()
    
    private init() {}
    
    /// URL for the Swedbank Pay SDK to connect to
    let backendUrl: String = "https://payex-merchant-samples.appspot.com/"
    
    /// Creates api request header names and values dictionary; define these in the backend receiving the requests from the app
    let headers: Dictionary<String, String> = [
        "x-payex-sample-apikey": "c339f53d-8a36-4ea9-9695-75048e592cc0",
        "x-payex-sample-access-token": NSUUID().uuidString.lowercased()
    ]
    
    /// If consumerData is nil, payment is anonymous
    var consumerData: SwedbankPaySDK.Consumer? {
        get {
            UserViewModel.shared.getConsumer()
        }
    }
    
    /// Sample Merchant data
    var sampleMerchantData: PurchaseData {
        get {
            PurchaseData.init(
                basketId: NSUUID().uuidString.lowercased(),
                currency: UserViewModel.shared.getCurrency().rawValue,
                languageCode: UserViewModel.shared.getLanguageCode(),
                items: StoreViewModel.shared.getPurchaseItems()
            )
        }
    }
    
    /// For result handling
    private(set) var result: PaymentResult = .unknown
    private(set) var problem: SwedbankPaySDK.Problem?
    
    /// Sets the result of the payment, and if the payment was successful, empties the shopping basket
    func setResult(_ result: PaymentResult, problem: SwedbankPaySDK.Problem? = nil) {
        if result == .success {
            StoreViewModel.shared.clearBasket()
        }
        self.result = result
        self.problem = problem
    }
}
