import StoreKit

public typealias ProductIdentifier = String
public typealias ProductsRequestCompletionHandler = (_ success: Bool, _ products: [SKProduct]?) -> ()

open class IAPHelper : NSObject  {
    
    static let shared = IAPHelper()
    static let IAPHelperPurchaseNotification = "IAPHelperPurchaseNotification"
    static let IAPHelperPurchaseFailNotification = "IAPHelperPurchaseFailNotification"
    fileprivate let productIdentifiers: Set<ProductIdentifier>
    fileprivate var purchasedProductIdentifiers = Set<ProductIdentifier>()
    fileprivate var productsRequest: SKProductsRequest?
    fileprivate var productsRequestCompletionHandler: ProductsRequestCompletionHandler?

    public init(productIds: Set<ProductIdentifier>? = nil) {
        if let productIds = productIds{
            self.productIdentifiers = productIds
        }else{
            self.productIdentifiers = IAPHelper.getProductIdentifiers()
        }
        for productIdentifier in self.productIdentifiers {
          let purchased = UserDefaults.standard.bool(forKey: productIdentifier)
          if purchased {
            purchasedProductIdentifiers.insert(productIdentifier)
            print("Previously purchased: \(productIdentifier)")
          } else {
            print("Not purchased: \(productIdentifier)")
          }
        }
        super.init()
    }
}

// MARK: - StoreKit API
extension IAPHelper {
    public static func getProductIdentifiers() -> Set<ProductIdentifier>{
        //TODO サーバーから取得
        return [
            "jp.co.ixit.iap.test.consumable",
            "jp.co.ixit.iap.test.sub.weekly",
            "jp.co.ixit.iap.test.sub.monthly"
        ]
    }

    public func resourceNameForProductIdentifier(_ productIdentifier: String) -> String? {
        return productIdentifier.components(separatedBy: ".").last
    }

    public func requestProducts(completionHandler: @escaping ProductsRequestCompletionHandler) {
        productsRequest?.cancel()
        productsRequestCompletionHandler = completionHandler

        productsRequest = SKProductsRequest(productIdentifiers: productIdentifiers)
        productsRequest!.delegate = self
        productsRequest!.start()
    }

    public func buyProduct(_ product: SKProduct) {
        print("Buying \(product.productIdentifier)...")
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }

    public func isProductPurchased(_ productIdentifier: ProductIdentifier) -> Bool {
        return purchasedProductIdentifiers.contains(productIdentifier)
    }

    public class func canMakePayments() -> Bool {
        return SKPaymentQueue.canMakePayments()
    }

    public func restorePurchases() {
        SKPaymentQueue.default().restoreCompletedTransactions()
    }

    public func uploadReceipt(completion: ((_ success: Bool) -> Void)? = nil) {
        if let receiptData = ReceiptHelper.shared.loadReceipt() {
            ReceiptHelper.shared.upload(receipt: receiptData) { [weak self] (result) in
                guard let _ = self else { return }
                switch result {
                case .success(let result):
                    print("Receipt Upload Successed: \(result)")
                    print("sessionId:\(result.sessionId)")
                    print("currentSubscription:\(String(describing: result.currentSubscription))")
                    completion?(true)
                case .failure(let error):
                    print("🚫 Receipt Upload Failed: \(error)")
                    completion?(false)
                }
            }
        }
    }
}

// MARK: - SKProductsRequestDelegate
extension IAPHelper: SKProductsRequestDelegate {
    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        let products = response.products
        print("Loaded list of products...")
        productsRequestCompletionHandler?(true, products)
        clearRequestAndHandler()

        for p in products {
          print("Found product: \(p.productIdentifier) \(p.localizedTitle) \(p.price.floatValue)")
        }
    }

    public func request(_ request: SKRequest, didFailWithError error: Error) {
        print("Failed to load list of products.")
        print("Error: \(error.localizedDescription)")
        productsRequestCompletionHandler?(false, nil)
        clearRequestAndHandler()
    }

    private func clearRequestAndHandler() {
        productsRequest = nil
        productsRequestCompletionHandler = nil
    }
}

// MARK: - SKPaymentTransactionObserver
extension IAPHelper: SKPaymentTransactionObserver {

    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
          switch (transaction.transactionState) {
          case .purchased:
            complete(transaction: transaction)
            break
          case .failed:
            fail(transaction: transaction)
            break
          case .restored:
            restore(transaction: transaction)
            break
          case .deferred:
            break
          case .purchasing:
            break
          }
        }
    }

    private func complete(transaction: SKPaymentTransaction) {
        print("complete...")
        deliverPurchaseNotificationFor(identifier: transaction.payment.productIdentifier)
        self.uploadReceipt{ result in
            if result {
                SKPaymentQueue.default().finishTransaction(transaction)
            }else{
                //TODO alert
            }
        }
    }

    private func restore(transaction: SKPaymentTransaction) {
        guard let productIdentifier = transaction.original?.payment.productIdentifier else { return }
        print("restore... \(productIdentifier)")
        deliverPurchaseNotificationFor(identifier: productIdentifier)
        SKPaymentQueue.default().finishTransaction(transaction)
    }

    private func fail(transaction: SKPaymentTransaction) {
        print("fail...")
        if let transactionError = transaction.error as NSError? {
          if transactionError.code != SKError.paymentCancelled.rawValue {
            print("Transaction Error: \(String(describing: transaction.error?.localizedDescription))")
            deliverPurchaseFailNotificationFor(error: transaction.error)
          }
        }
        SKPaymentQueue.default().finishTransaction(transaction)
    }

    private func deliverPurchaseNotificationFor(identifier: String?) {
        guard let identifier = identifier else { return }

        purchasedProductIdentifiers.insert(identifier)
        UserDefaults.standard.set(true, forKey: identifier)
        UserDefaults.standard.synchronize()
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: IAPHelper.IAPHelperPurchaseNotification), object: identifier)
    }
    
    private func deliverPurchaseFailNotificationFor(error: Error?) {
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: IAPHelper.IAPHelperPurchaseFailNotification), object: error)
    }
}
