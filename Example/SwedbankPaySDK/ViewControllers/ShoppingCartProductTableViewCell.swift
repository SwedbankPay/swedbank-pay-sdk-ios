import UIKit

class ShoppingCartProductTableViewCell: UITableViewCell {
    
    @IBOutlet private weak var productImage: UIImageView!
    @IBOutlet private weak var productNameLabel: UILabel!
    @IBOutlet private weak var productPriceLabel: UILabel!
    @IBOutlet private weak var productHighlight: UIView!
    
    private var product: Product?
    
    var basketChangedCallback: (()->())?
    
    /// Removes the product from shopping basket
    @IBAction func removeFromBasketButtonClick(_ sender: Any) {
        if let product = product {
            StoreViewModel.shared.removeFromBasket(product)
            self.basketChangedCallback?()
        }
    }
    
    /// Sets the product details
    public func setProductDetails(_ product: Product?) {
        if let product = product {
            
            self.product = product
            
            if let image = product.image {
                productImage.image = UIImage.init(imageLiteralResourceName: image)
            }
            
            if let name = product.name {
                productNameLabel.text = name
            }
            
            let currency = UserViewModel.shared.getCurrency()
            let price = String((product.price[currency] ?? 0) / 100)
            
            productPriceLabel.text = "\(price) \(currency.rawValue)"
            
            productHighlight.backgroundColor = UIColor(rgb: product.highlightHexColor)
        }
    }
}
