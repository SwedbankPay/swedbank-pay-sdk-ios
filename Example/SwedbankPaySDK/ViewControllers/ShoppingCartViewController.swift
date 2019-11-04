import UIKit

class ShoppingCartViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var shoppingCartView: UIView!
    @IBOutlet private weak var shoppingCartEmptyView: UIView!
    
    @IBOutlet private weak var settingsContainerView: UIView!
    @IBOutlet private weak var settingsContainerTrailingConstraint: NSLayoutConstraint!
    @IBOutlet private weak var settingsContainerBottomConstraint: NSLayoutConstraint!
    
    @IBOutlet private weak var anonymousUnderlineView: UIView!
    @IBOutlet private weak var identifiedUnderlineView: UIView!
    @IBOutlet private weak var norwayUnderlineView: UIView!
    @IBOutlet private weak var swedenUnderlineView: UIView!
    
    @IBOutlet private weak var anonymousLabel: UILabel!
    @IBOutlet private weak var identifiedLabel: UILabel!
    @IBOutlet private weak var norwayLabel: UILabel!
    @IBOutlet private weak var swedenLabel: UILabel!
    
    private var blurEffectView: UIVisualEffectView?
    
    private let settingsContainerTrailingConstant: CGFloat = 93
    private let settingsContainerBottomConstant: CGFloat = 89
    
    override func viewDidLoad() {
        super.viewDidLoad()
 
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.register(UINib(nibName: "ShoppingCartProductTableViewCell", bundle: nil), forCellReuseIdentifier: "ShoppingCartProductCell")
        tableView.register(UINib(nibName: "ShoppingCartSummaryFooterView", bundle: nil), forHeaderFooterViewReuseIdentifier: "ShoppingCartSummary")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        let blurEffect = UIBlurEffect(style: UIBlurEffect.Style.dark)
        blurEffectView = UIVisualEffectView(effect: blurEffect)
        if let blurEffectView = blurEffectView {
            blurEffectView.frame = view.bounds
            blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            view.addSubview(blurEffectView)
            blurEffectView.isHidden = false
        }
        
        setCountry(UserViewModel.shared.getCountry())
        
        setUser(UserViewModel.shared.getUserType())
        
        view.bringSubview(toFront: shoppingCartView)
    }
    
    /// Animates the updates in tableView content
    private func updateTableView() {
        let range = NSMakeRange(0, self.tableView.numberOfSections)
        let sections = NSIndexSet(indexesIn: range)
        self.tableView.reloadSections(sections as IndexSet, with: .fade)
        if let parent = self.parent as? CheckoutViewController {
            parent.updateData()
        }
    }
    
    // MARK: IBActions
    
    @IBAction func closeShoppingCartButtonClick(_ sender: Any) {
        hideShoppingCart()
    }
    
    @IBAction func openSettingsButtonClick(_ sender: Any) {
        openSettings()
    }
    
    @IBAction func closeSettingsButtonClick(_ sender: Any) {
        closeSettings()
    }
    
    @IBAction func setAnonymousButtonClick(_ sender: Any) {
        setUser(.Anonymous)
    }
    
    @IBAction func setIdentifiedButtonClick(_ sender: Any) {
        setUser(.Identified)
    }
    
    @IBAction func setCountryNorwayButtonClick(_ sender: Any) {
        setCountry(.Norway)
    }
    
    @IBAction func setCountrySwedenButtonClick(_ sender: Any) {
        setCountry(.Sweden)
    }
    
    /// Hides the shopping cart and shows the payment view
    private func checkout() {
        if StoreViewModel.shared.getBasketCount() > 0 {
            if let parent = self.parent as? CheckoutViewController {
                hideShoppingCart()
                parent.startPayment()
            }
        }
    }
    
    // MARK: Shopping Cart
    
    /// Shows the shopping cart view
    public func showShoppingCart() {
        setSettingsClosed()
        shoppingCartEmptyView.isHidden = (StoreViewModel.shared.getBasketCount() > 0)
    }
    
    /// Hides the shopping cart view
    private func hideShoppingCart() {
        view.setNeedsLayout()
        view.layoutIfNeeded()
        if let parent = self.parent as? CheckoutViewController {
            parent.hideShoppingCart()
        }
    }
    
    // MARK: Settings
    
    /// Opens the settings view
    private func openSettings() {
        settingsContainerTrailingConstraint.constant = 15
        settingsContainerBottomConstraint.constant = 0
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut, animations: { [weak self] in
            self?.view.layoutIfNeeded()
        }, completion: { [weak self] _ in
            self?.settingsContainerView.isHidden = false
        })
    }
    
    /// Closes the settings view
    private func closeSettings() {
        setSettingsClosed()
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut, animations: { [weak self] in
            self?.view.layoutIfNeeded()
        }, completion: nil)
    }
    
    private func setSettingsClosed() {
        settingsContainerView.isHidden = true
        settingsContainerTrailingConstraint.constant = UIScreen.main.bounds.width - self.settingsContainerTrailingConstant
        settingsContainerBottomConstraint.constant = self.settingsContainerBottomConstant
    }
    
    /// Sets the user either anonymous or identified in settings view
    private func setUser(_ type: UserType) {
        UserViewModel.shared.setUserType(type)
        switch type {
        case .Anonymous:
            anonymousUnderlineView.isHidden = false
            identifiedUnderlineView.isHidden = true
            anonymousLabel.font = UIFont.bold12()
            identifiedLabel.font = UIFont.medium12()
        case .Identified:
            anonymousUnderlineView.isHidden = true
            identifiedUnderlineView.isHidden = false
            anonymousLabel.font = UIFont.medium12()
            identifiedLabel.font = UIFont.bold12()
        }
    }
    
    /// Sets the country in settings view
    private func setCountry(_ country: Country) {
        UserViewModel.shared.setCountry(country)
        switch country {
        case .Norway:
            norwayUnderlineView.isHidden = false
            swedenUnderlineView.isHidden = true
            norwayLabel.font = UIFont.bold12()
            swedenLabel.font = UIFont.medium12()
        case .Sweden:
            norwayUnderlineView.isHidden = true
            swedenUnderlineView.isHidden = false
            norwayLabel.font = UIFont.medium12()
            swedenLabel.font = UIFont.bold12()
        }
        updateTableView()
    }
    
    // MARK: TableView delegate methods
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return StoreViewModel.shared.getBasketCount()
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 160
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ShoppingCartProductCell", for: indexPath) as! ShoppingCartProductTableViewCell
        
        let product = StoreViewModel.shared.getBasketProduct(indexPath.row)
        cell.setProductDetails(product)
        
        cell.basketChangedCallback = {
            self.updateTableView()
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 230
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        if StoreViewModel.shared.getBasketCount() > 0 {
            let cell = tableView.dequeueReusableHeaderFooterView(withIdentifier: "ShoppingCartSummary") as! ShoppingCartSummaryFooterView
            cell.setPrices()
            
            cell.checkoutCallback = {
                self.checkout()
            }
            
            return cell
        } else {
            return UIView()
        }
    }
}
