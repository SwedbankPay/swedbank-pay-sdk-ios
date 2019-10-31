import UIKit

class ProductTableViewCell: UITableViewCell {
    
    @IBOutlet private weak var productImage: UIImageView!
    @IBOutlet private weak var productNameLabel: UILabel!
    @IBOutlet private weak var productPriceLabel: UILabel!
    @IBOutlet private weak var productHighlight: UIView!
    @IBOutlet private weak var addedToBasketView: UIView!
    @IBOutlet private weak var addToBasketButton: UIButton!
    @IBOutlet private weak var removeFromBasketButton: UIButton!
    
    private var product: Product?
    
    var basketChangedCallback: (()->())?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        addedToBasketView.alpha = 0
    }
    
    @IBAction func addToBasketButtonClick(_ sender: Any) {
        if let product = product {
            StoreViewModel.shared.addToBasket(product)
            showAddedToBasket()
            updateBasketButtons()
            self.basketChangedCallback?()
        }
    }
    
    @IBAction func removeFromBasketButtonClick(_ sender: Any) {
        if let product = product {
            StoreViewModel.shared.removeFromBasket(product)
            updateBasketButtons()
            self.basketChangedCallback?()
        }
    }
    
    /// Updates the add to basket and remove from basket buttons
    private func updateBasketButtons() {
        if let product = product {
            if StoreViewModel.shared.checkIfBasketContains(product) {
                addToBasketButton.isHidden = true
                removeFromBasketButton.isHidden = false
            } else {
                addToBasketButton.isHidden = false
                removeFromBasketButton.isHidden = true
            }
        }
    }
    
    /// Shows animated "added to basket" notification
    private func showAddedToBasket() {
        UIView.animate(withDuration: 0.1, delay: 0, options: UIViewAnimationOptions.curveEaseInOut, animations: {
            self.addedToBasketView.alpha = 1
        }, completion: { [weak self] finished in
            UIView.animate(withDuration: 0.3, delay: 0.4, options: .curveLinear, animations: {
                self?.addedToBasketView.alpha = 0
            }, completion: nil)
        })
    }
    
    /// Sets the `Product` details in place
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
            
            updateBasketButtons()
        }
    }
}
