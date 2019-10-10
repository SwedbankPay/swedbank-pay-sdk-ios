import Foundation
import SwedbankPaySDK

/// Singleton ViewModel to hold example app data
class PaymentViewModel {
    
    static let shared = PaymentViewModel()
    
    private init() {}
    
    /// URL for the Swedbank SDK to connect to
    let backendUrl: String = "https://payex-merchant-samples.appspot.com/"
    
    /// Creates api request header names and values dictionary; define these in the backend receiving the requests of from the app
    let headers: Dictionary<String, String> = [
        "x-payex-sample-apikey": "c339f53d-8a36-4ea9-9695-75048e592cc0",
        "x-payex-sample-access-token": NSUUID().uuidString.lowercased()
    ]
    
    /// If consumerData is nil, payment is anonymous
    private(set) var consumerData: SwedbankPaySDK.Consumer?
    
    /// For result handling
    private(set) var result: PaymentResult = .unknown
    private(set) var problem: SwedbankPaySDK.Problem?
    
    /// Sample Merchant data
    let sampleMerchantData: StoreData = StoreData.init(
        basketId: NSUUID().uuidString.lowercased(),
        currency: "SEK",
        languageCode: "sv-SE",
        items: [
            StoreItem.init(itemId: "1", quantity: 1, price: 1200, vat: 25),
            StoreItem.init(itemId: "2", quantity: 1, price: 1800, vat: 25)
        ]
    )
    
    /// Sample Consumer data
    private let sampleConsumerData = SwedbankPaySDK.Consumer.init(
        consumerCountryCode: "NO",
        msisdn: "+4798765432",
        email: "olivia.nyhuus@payex.com",
        nationalIdentifier: SwedbankPaySDK.NationalIdentifier.init(
            socialSecurityNumber: "26026708248",
            countryCode: "NO"
        )
    )
    
    func setUser(known: Bool) {
        if known {
            consumerData = sampleConsumerData
        }
    }
    
    func setResult(_ result: PaymentResult, problem: SwedbankPaySDK.Problem? = nil) {
        self.result = result
        self.problem = problem
    }
}
