/*
* Copyright (c) 2016 Razeware LLC
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
* THE SOFTWARE.
*/

import UIKit
import StoreKit

class MasterViewController: UITableViewController {
  
    var products = [SKProduct]()

    override func viewDidLoad() {
    super.viewDidLoad()

    title = "Iap Test"

    refreshControl = UIRefreshControl()
    refreshControl?.addTarget(self, action: #selector(MasterViewController.reload), for: .valueChanged)

    let restoreButton = UIBarButtonItem(title: "Restore",
                                        style: .plain,
                                       target: self,
                                       action: #selector(MasterViewController.restoreTapped(_:)))
    navigationItem.rightBarButtonItem = restoreButton

    NotificationCenter.default.addObserver(self, selector: #selector(MasterViewController.handlePurchaseNotification(_:)),
                                                               name: NSNotification.Name(rawValue: IAPHelper.IAPHelperPurchaseNotification),
                                                             object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(MasterViewController.handlePurchaseFailNotification(_:)),
                                           name: NSNotification.Name(rawValue: IAPHelper.IAPHelperPurchaseFailNotification),
                                           object: nil)
    }
  
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        reload()
    }
  
    @objc func reload() {
        products = []
        
        tableView.reloadData()
        
        IAPHelper.shared.requestProducts{success, products in
          if success {
            self.products = products!
            
            self.tableView.reloadData()
          }
          
          self.refreshControl?.endRefreshing()
        }
    }
  
    @objc func restoreTapped(_ sender: AnyObject) {
        IAPHelper.shared.restorePurchases()
    }

    @objc func handlePurchaseNotification(_ notification: Notification) {
        guard let productID = notification.object as? String else { return }
        
        for (index, product) in products.enumerated() {
          guard product.productIdentifier == productID else { continue }
            DispatchQueue.main.async {
                self.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .fade)
            }
        }
    }
    
    @objc func handlePurchaseFailNotification(_ notification: Notification) {
    }
}

// MARK: - UITableViewDataSource

extension MasterViewController {
  
  override func numberOfSections(in tableView: UITableView) -> Int {
    return 1
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return products.count
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! ProductCell
    
    let product = products[(indexPath as NSIndexPath).row]
    
    cell.product = product
    cell.buyButtonHandler = { product in
        IAPHelper.shared.buyProduct(product)
    }
    return cell
  }
}

// MARK: - SimpleAlertHelperDelegate
extension MasterViewController: SimpleAlertHelperDelegate {
    func didTapOKButton() {
    }
}
