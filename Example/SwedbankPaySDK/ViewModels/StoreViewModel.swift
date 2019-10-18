import UIKit

/// Singleton ViewModel for store data
class StoreViewModel {
    
    static let shared = StoreViewModel()
    
    private init() {}
    
    private var basket: [Product] = []
    
    /// Example static store data
    let products: [Product] = [
        Product.init(
            id: NSUUID().uuidString.lowercased(),
            name: "Pink Sneakers",
            image: "Product-Pink-Sneakers",
            price: [
                Currency.SEK: 159900,
                Currency.NOK: 148100
            ],
            vat: 25,
            highlightHexColor: 0xFFCFCF
        ),
        
        Product.init(
            id: NSUUID().uuidString.lowercased(),
            name: "Red Skate Shoes",
            image: "Product-Red-Skate-Shoes",
            price: [
                Currency.SEK: 99900,
                Currency.NOK: 92500
            ],
            vat: 25,
            highlightHexColor: 0x9A2D3A
        ),
        
        Product.init(
            id: NSUUID().uuidString.lowercased(),
            name: "Red Sneakers",
            image: "Product-Red-Sneakers",
            price: [
                Currency.SEK: 189900,
                Currency.NOK: 176000
            ],
            vat: 25,
            highlightHexColor: 0xF0312D
        ),
        
        Product.init(
            id: NSUUID().uuidString.lowercased(),
            name: "Yellow Skate Shoes",
            image: "Product-Yellow-Skate-Shoes",
            price: [
                Currency.SEK: 89900,
                Currency.NOK: 83300
            ],
            vat: 25,
            highlightHexColor: 0xF4B800
        ),
        
        Product.init(
            id: NSUUID().uuidString.lowercased(),
            name: "Grey Sneakers",
            image: "Product-Grey-Sneakers",
            price: [
                Currency.SEK: 249900,
                Currency.NOK: 231600
            ],
            vat: 25,
            highlightHexColor: 0xD0D0D0
        )
    ]
    
    /// Example shipping cost values for both countries
    let shippingCost: Dictionary<Currency, Int> = [
        Currency.NOK: 12000,
        Currency.SEK: 12700
    ]
    
    // MARK: Shopping Basket
    
    /// Returns the number of items in the shopping basket
    public func getBasketCount() -> Int {
        return basket.count
    }
    
    /// Returns the total value of shopping cart items plus shipping cost
    public func getBasketTotalPrice() -> Int {
        var totalPrice = 0
        if basket.count > 0 {
            let currency = UserViewModel.shared.getCurrency()
            for product in basket {
                if let price = product.price[currency] {
                    totalPrice = totalPrice + price
                }
            }
            totalPrice = totalPrice + getShippingCost()
        }
        return totalPrice
    }
    
    /// Returns the specific Product at certain index position (tableView index)
    public func getBasketProduct(_ index: Int) -> Product {
        return basket[index]
    }
    
    /// Returns shipping cost for specific currency
    public func getShippingCost() -> Int {
        return shippingCost[UserViewModel.shared.getCurrency()] ?? 0
    }
    
    /// Returns true if shopping basket contains specific product
    public func checkIfBasketContains(_ product: Product) -> Bool {
        return basket.contains(where: { $0.id == product.id })
    }
    
    /// Adds the Product into shopping basket
    public func addToBasket(_ product: Product) {
        basket.append(product)
    }
    
    /// Removes the specific Product from shopping basket
    public func removeFromBasket(_ product: Product) {
        basket.removeAll(where: { $0.id == product.id })
    }
    
    /// Removes all items from shopping basket
    public func clearBasket() {
        basket = []
    }
    
    /// Returns an array of PurchaseItems to be sent to the backend in merchantData
    public func getPurchaseItems() -> [PurchaseItem] {
        var items: [PurchaseItem] = []
        if basket.count > 0 {
            for product in basket {
                if !items.contains(where: { $0.itemId == product.id } ) {
                    if let id = product.id, let price = product.price[UserViewModel.shared.getCurrency()] {
                        let item = PurchaseItem.init(itemId: id, quantity: 1, price: price, vat: product.vat)
                        items.append(item)
                    }
                }
            }
            items.append(PurchaseItem.init(itemId: "shipping", quantity: 1, price: getShippingCost(), vat: 25))
        }
        
        return items
    }
}
