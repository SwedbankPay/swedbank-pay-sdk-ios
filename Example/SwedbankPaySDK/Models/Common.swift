import SwedbankPaySDK

/// Example store data; it can be anything but it *must* conform to Encodable protocol
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

enum PaymentResult {
    case unknown
    case error
    case success
}
