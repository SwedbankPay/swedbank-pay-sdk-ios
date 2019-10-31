import SwedbankPaySDK

/// Singleton ViewModel for payment data
class PaymentViewModel {
    
    static let shared = PaymentViewModel()
    
    private init() {}
    
    /// URL for the Swedbank Pay SDK to connect to
    private let backendUrl: String = "https://payex-merchant-samples.appspot.com"
    
    /// Creates api request header names and values dictionary; define these in the backend receiving the requests from the app
    private let headers: Dictionary<String, String> = [
        "x-payex-sample-apikey": "c339f53d-8a36-4ea9-9695-75048e592cc0",
        "x-payex-sample-access-token": NSUUID().uuidString.lowercased()
    ]
    
    /**
     List of allowed domains.
     
     By default, the domain of the backend URL is whitelisted, including its subdomains. If you wish to change that default,
     you must add all domains, including backend URL; in that situation it is not included by default.
     */
    private let domainWhitelist: [SwedbankPaySDK.WhitelistedDomain]? = [
        SwedbankPaySDK.WhitelistedDomain(domain: "payex-merchant-samples.appspot.com", includeSubdomains: false)
    ]
    
    /// Configuration for SwedbankPaySDK
    var configuration: SwedbankPaySDK.Configuration {
        get {
            return SwedbankPaySDK.Configuration.init(
                backendUrl: self.backendUrl,
                headers: self.headers,
                domainWhitelist: self.domainWhitelist
            )
        }
    }
    
    /// If consumerData is nil, payment is anonymous
    var consumerData: SwedbankPaySDK.Consumer? {
        get {
            UserViewModel.shared.getConsumer()
        }
    }
    
    /// Sample Merchant data
    var merchantData: PurchaseData {
        get {
            PurchaseData.init(
                basketId: NSUUID().uuidString.lowercased(),
                currency: UserViewModel.shared.getCurrency().rawValue,
                languageCode: UserViewModel.shared.getLanguageCode(),
                items: StoreViewModel.shared.getPurchaseItems()
            )
        }
    }
    
    /// Result handling
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
