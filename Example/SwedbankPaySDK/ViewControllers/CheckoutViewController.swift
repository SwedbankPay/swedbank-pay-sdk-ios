import UIKit

class CheckoutViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet private weak var tableView: UITableView!
    @IBOutlet private weak var basketCounterView: UIView!
    @IBOutlet private weak var basketCounterLabel: UILabel!
    @IBOutlet private weak var shoppingCartView: UIView!
    
    private var shoppingCartVC: UIViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.register(UINib(nibName: "ProductTableViewCell", bundle: nil), forCellReuseIdentifier: "ProductCell")

        if #available(iOS 13, *) {
            self.navigationController?.overrideUserInterfaceStyle = UIUserInterfaceStyle.light
        } else {
            if let navigationBar = navigationController?.navigationBar {
                navigationBar.setBackgroundImage(UIImage(), for: .default)
                navigationBar.shadowImage = UIImage()
                navigationBar.layoutIfNeeded()
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.title = ""
        
        basketCounterView.isHidden = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        shoppingCartView.isHidden = true
        
        updateBasketCounter()
        
        tableView.reloadData()
    }
    
    /// Updates the shopping cart counter with animation
    private func updateBasketCounter() {
        let count = StoreViewModel.shared.getBasketCount()
        basketCounterView.isHidden = (count > 0) ? false : true
        if count > 0 {
            if basketCounterLabel.text != String(count) {
                UIView.animate(withDuration: 0.05, delay: 0, options: .curveEaseInOut, animations: { [weak self] in
                    self?.basketCounterView.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
                }, completion: { [weak self] _ in
                    UIView.animate(withDuration: 0.05, delay: 0.02, options: .curveEaseInOut, animations: { [weak self] in
                        self?.basketCounterView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
                    }, completion: { [weak self] _ in
                        UIView.animate(withDuration: 0.05, delay: 0.02, options: .curveEaseInOut, animations: { [weak self] in
                            self?.basketCounterView.transform = CGAffineTransform(scaleX: 1, y: 1)
                        }, completion: nil)
                    })
                })
            }
            basketCounterLabel.text = String(count)
        } else {
            basketCounterLabel.text = "0"
        }
    }
    
    func updateData() {
        updateBasketCounter()
        tableView.reloadData()
    }
    
    /// Shows the payment view
    public func startPayment() {
        self.title = "Cancel"
        performSegue(withIdentifier: "showPayment", sender: self)
    }
    
    // MARK: IBActions
    
    @IBAction func checkoutButtonClick(_ sender: Any) {
        showShoppingCart()
    }
    
    // MARK: Shopping Cart
    
    /// Shows the shopping cart with animation (creates the shopping cart view as a child viewcontroller inside shoppingCartView)
    private func showShoppingCart() {
        navigationController?.navigationBar.alpha = 0.001
        shoppingCartView.isHidden = false
        shoppingCartView.alpha = 0
        shoppingCartVC = storyboard!.instantiateViewController(withIdentifier: "ShoppingCartVC")
        if let vc = shoppingCartVC as? ShoppingCartViewController {
            addChildViewController(vc)
            shoppingCartView.addSubview(vc.view)
            vc.view.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                vc.view.topAnchor.constraint(equalTo: shoppingCartView.topAnchor),
                vc.view.leftAnchor.constraint(equalTo: shoppingCartView.leftAnchor),
                vc.view.rightAnchor.constraint(equalTo: shoppingCartView.rightAnchor),
                vc.view.bottomAnchor.constraint(equalTo: shoppingCartView.bottomAnchor),
            ])
            
            vc.didMove(toParentViewController: self)
            vc.showShoppingCart()
        }
        view.bringSubview(toFront: shoppingCartView)

        UIView.animate(withDuration: 0.2, animations: { [weak self] in
            self?.shoppingCartView.alpha = 1
        })
    }
    
    /// Hides the shopping cart with animation, updates the shopping cart counter
    public func hideShoppingCart() {
        
        updateBasketCounter()

        UIView.animate(withDuration: 0.2, animations: { [weak self] in
            self?.shoppingCartView.alpha = 0
        }, completion: { [weak self] _ in
            
            if let vc = self?.shoppingCartVC as? ShoppingCartViewController {
                vc.willMove(toParentViewController: nil)
                vc.view.removeFromSuperview()
                vc.removeFromParentViewController()
            }
            self?.shoppingCartVC = nil
            self?.shoppingCartView.isHidden = true
            
            self?.view.setNeedsLayout()
            self?.view.layoutIfNeeded()
        })
    }
    
    // MARK: TableView delegate methods
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return StoreViewModel.shared.products.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 395
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 100
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = UIView()
        let label = UILabel()
        label.text = "Shoes"
        label.font = UIFont.medium24()
        label.textColor = UIColor.black
        view.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.white    
        
        label.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20).isActive = true
        label.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        
        return view
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ProductCell", for: indexPath) as! ProductTableViewCell
        
        if StoreViewModel.shared.products.count > indexPath.row {
            let product = StoreViewModel.shared.products[indexPath.row]
            cell.setProductDetails(product)
        }
        
        cell.basketChangedCallback = {
            self.updateBasketCounter()
        }
        
        return cell
    }
}
