import UIKit

class ShoppingCartSummaryFooterView: UITableViewHeaderFooterView {
    
    @IBOutlet private weak var shippingPriceLabel: UILabel!
    @IBOutlet private weak var totalPriceLabel: UILabel!
    
    var checkoutCallback: (()->())?
    
    /// Checkout button click triggers the payment
    @IBAction func checkoutButtonClick(_ sender: Any) {
        checkoutCallback?()
    }
    
    /// Sets the summary values
    public func setPrices() {
        let currency = UserViewModel.shared.getCurrency()
        shippingPriceLabel.text = "\(StoreViewModel.shared.getShippingCost() / 100) \(currency.rawValue)"
        
        totalPriceLabel.text = "\(StoreViewModel.shared.getBasketTotalPrice() / 100) \(UserViewModel.shared.getCurrency().rawValue)"
    }
}
