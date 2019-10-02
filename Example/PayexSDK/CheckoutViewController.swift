import PayexSDK

/// This is just a structure to pass the data to PaymentViewController
struct PaymentData {
    var backendUrl: String = "https://payex-merchant-samples.appspot.com/"
    var headers: Dictionary<String, String>?
    var merchantData: StoreData?  //Dictionary<String, Any>?
    var consumerData: PayexSDK.Consumer?
}

/// Example store data, can be anything - but needs to conform to Encodable protocol
struct StoreData: Encodable {
    var basketId: String
    var currency: String
    var languageCode: String
    var items: [StoreItem]
}

struct StoreItem: Encodable {
    var itemId: String
    var quantity: Int
    var price: Int
    var vat: Int
}

class CheckoutViewController: UIViewController {
    
    private var paymentData: PaymentData? = PaymentData()
    
    /// Creates api request header names and values dictionary; you define these in the backend receiving the requests of from the app
    private let payexSDKConfiguration: Dictionary<String, String> = [
        "x-payex-sample-apikey": "c339f53d-8a36-4ea9-9695-75048e592cc0",
        "x-payex-sample-access-token": NSUUID().uuidString.lowercased()
    ]
    
    /// Sample Merchant data dictionary
    private let sampleMerchantData: StoreData = StoreData.init(
        basketId: "123-4567-89012",
        currency: "SEK",
        languageCode: "sv-SE",
        items: [
            StoreItem.init(itemId: "1", quantity: 1, price: 1200, vat: 25),
            StoreItem.init(itemId: "2", quantity: 1, price: 1800, vat: 25)
        ]
    )
    
    /// Sample Consumer data
    private let sampleConsumerData = PayexSDK.Consumer.init(
        consumerCountryCode: "NO",
        msisdn: "+4798765432",
        email: "olivia.nyhuus@payex.com",
        nationalIdentifier: PayexSDK.NationalIdentifier.init(
            socialSecurityNumber: "26026708248",
            countryCode: "NO"
        )
    )
    
    /**
     Initialize payment process for anonymous user

     - parameter headers: api request header names and values dictionary, see sample data above
     - parameter backendUrl: url to your backend
     - parameter merchantData: merchant and purchase information, see sample data above
     */
    @IBAction func startAnonymousPayment(_ sender: Any) {
        self.paymentData?.headers = payexSDKConfiguration
        self.paymentData?.merchantData = sampleMerchantData
        self.paymentData?.consumerData = nil
        performSegue(withIdentifier: "showPayment", sender: self)
    }
    
    /**
     Initialize payment process for registered user

     - parameter headers: api request header names and values dictionary, see sample data above
     - parameter backendUrl: url to your backend
     - parameter merchantData: merchant and purchase information, see sample data above
     - parameter customerData: customer information, see sample data above
     */
    @IBAction func startRegisteredPayment(_ sender: Any) {
        self.paymentData?.headers = payexSDKConfiguration
        self.paymentData?.merchantData = sampleMerchantData
        self.paymentData?.consumerData = sampleConsumerData
        performSegue(withIdentifier: "showPayment", sender: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showPayment" {
            let vc = segue.destination as! PaymentViewController
            vc.paymentData = self.paymentData
        }
    }
}
