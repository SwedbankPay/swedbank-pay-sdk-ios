
/// Example purchase data; *must* conform to Encodable protocol
struct PurchaseData: Encodable {
    var basketId: String
    var currency: String
    var languageCode: String
    var items: [PurchaseItem]
}

/// Part of the `PurchaseData` so must conform to Encodable protocol too
struct PurchaseItem: Encodable {
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

enum UserType {
    case Anonymous
    case Identified
}

enum Country {
    case Norway
    case Sweden
}

enum Currency: String {
    case SEK
    case NOK
}

struct Product {
    let id: String?
    let name: String?
    let image: String?
    let price: Dictionary<Currency, Int>
    let vat: Int
    let highlightHexColor: Int
}
