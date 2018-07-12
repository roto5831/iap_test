import StoreKit

public typealias ProductIdentifier = String
public typealias ProductsRequestCompletionHandler = (_ success: Bool, _ products: [SKProduct]?) -> ()

/// アプリ内課金お助けマン
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
        super.init()
    }
}

// MARK: - StoreKit API
extension IAPHelper {
    public static func getProductIdentifiers() -> Set<ProductIdentifier>{
        //TODO 商品の追加や修正があった時のためにサーバーから取得
        return [
            "jp.co.ixit.iap.test.consumable",
            "jp.co.ixit.iap.test.sub.monthly"
        ]
    }
    
    /// 商品の名前をアプリで内部的に使用したい時
    ///
    /// - Parameter productIdentifier:
    /// - Returns:
    public func resourceNameForProductIdentifier(_ productIdentifier: String) -> String? {
        return productIdentifier.components(separatedBy: ".").last
    }

    
    /// 商品情報取得要求
    /// SKProductsRequestDelegateに結果処理を委譲
    /// - Parameter completionHandler:
    public func requestProducts(completionHandler: @escaping ProductsRequestCompletionHandler) {
        productsRequest?.cancel()
        productsRequestCompletionHandler = completionHandler

        productsRequest = SKProductsRequest(productIdentifiers: productIdentifiers)
        productsRequest!.delegate = self
        productsRequest!.start()
    }

    /// 商品購入
    /// 購入処理はSKPaymentTransactionObserverにより監視される
    /// - Parameter product: SKProduct
    public func buyProduct(_ product: SKProduct) {
        print("Buying \(product.productIdentifier)...")
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }
    
    /// 購読型の商品を購入したかどうか
    ///
    /// - Parameter productIdentifier:
    /// - Returns:
    public func isProductPurchasedForSubscribe(_ productIdentifier: ProductIdentifier) -> Bool {
        guard !productIdentifier.contains("consumable") else{
            return false
        }
        return purchasedProductIdentifiers.contains(productIdentifier)
    }

    /// 支払い能力があるかどうか　※親が子供の携帯に制限をかけたりできる
    ///
    /// - Returns:
    public class func canMakePayments() -> Bool {
        return SKPaymentQueue.canMakePayments()
    }

    
    /// 支払い情報復元　※消費型はデバイス変えても復元されない
    public func restorePurchases() {
        SKPaymentQueue.default().restoreCompletedTransactions()
    }

    
    /// レシート情報のアップロード
    ///
    /// - Parameter completion:
    public func uploadReceipt(completion: ((_ success: Bool) -> Void)? = nil) {
        /// TODO 課金は成功したのにデータ上登録されいてないのを避けるために
        /// 正常系であれば確実にこの処理が成功するようリトライをかけ続ける必要がある
        /// この処理が終了した後の返り値でコンテンツの解放、追加もしくは成功結果を元に再度データ取得のAPIを投げる
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
                    /// 失敗だった場合はなぜ失敗しているのかをユーザーに伝えて、内容によってはリトライが必要かも
                    print("🚫 Receipt Upload Failed: \(error)")
                    completion?(false)
                }
            }
        }
    }
}

// MARK: - SKProductsRequestDelegate
extension IAPHelper: SKProductsRequestDelegate {
    
    /// Storeから商品情報を取得成功
    ///
    /// - Parameters:
    ///   - request:
    ///   - response:
    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        let products = response.products
        print("Loaded list of products...")
        productsRequestCompletionHandler?(true, products)
        clearRequestAndHandler()

        for p in products {
          print("Found product: \(p.productIdentifier) \(p.localizedTitle) \(p.price.floatValue)")
        }
    }

    
    /// Storeから商品情報を取得失敗
    ///
    /// - Parameters:
    ///   - request:
    ///   - error:
    public func request(_ request: SKRequest, didFailWithError error: Error) {
        print("Failed to load list of products.")
        print("Error: \(error.localizedDescription)")
        productsRequestCompletionHandler?(false, nil)
        clearRequestAndHandler()
    }
    
    /// 商品情報を取得要求クリア
    private func clearRequestAndHandler() {
        productsRequest = nil
        productsRequestCompletionHandler = nil
    }
}

// MARK: - SKPaymentTransactionObserver
extension IAPHelper: SKPaymentTransactionObserver {

    
    /// 支払い要求の処理の監視
    /// TODO 支払いの途中でアプリが落ちてもトランザクションの終了を呼び出さない限り終了しないかどうかのテスト
    /// 支払いの監視はAppDelegateで登録している
    /// - Parameters:
    ///   - queue:
    ///   - transactions:
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
            print("deferred... \(transaction.payment.productIdentifier)")
            break
          case .purchasing:
            print("purchasing... \(transaction.payment.productIdentifier)")
            break
          }
        }
    }
    
    /// 完了
    ///
    /// - Parameter transaction:
    private func complete(transaction: SKPaymentTransaction) {
        print("complete...")
        self.uploadReceipt{ result in
            //TODO サーバー上でのレシート検証が終了し、コンテンツの付与が終了した段階でトランザクションを終了
            //課金はされているのに通信障害などでアイテムの付与がされていない状況を防ぐ
            if result {
                //TODO テスト　この分岐に入る前に通信をOFFにして再度起動した際にこの分岐に入れば、
                //独自にリトライ実装しなくて良い
                //contents取得
                SKPaymentQueue.default().finishTransaction(transaction)
                self.deliverPurchaseNotificationFor(identifier: transaction.payment.productIdentifier)
            }else{
            //レシートが不正だったことをユーザーに通知？
            }
        }
    }

    /// 復元 ボタンなどUI上からレストア処理をかけるようにしないとリジェクトされるらしい
    ///
    /// - Parameter transaction:
    private func restore(transaction: SKPaymentTransaction) {
        guard let productIdentifier = transaction.original?.payment.productIdentifier else { return }
        print("restore... \(productIdentifier)")
        //contents取得
        deliverPurchaseNotificationFor(identifier: productIdentifier)
        SKPaymentQueue.default().finishTransaction(transaction)
    }
    
    /// 失敗
    ///
    /// - Parameter transaction:
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
    
    /// 完了もしくはレストアの処理後、ユーザーに何か伝えたい時
    ///
    /// - Parameter identifier:
    private func deliverPurchaseNotificationFor(identifier: String?) {
        guard let identifier = identifier else { return }

        purchasedProductIdentifiers.insert(identifier)
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: IAPHelper.IAPHelperPurchaseNotification), object: identifier)
    }
    
    /// 失敗したことを元に何かユーザーに伝えたい時
    ///
    /// - Parameter error:
    private func deliverPurchaseFailNotificationFor(error: Error?) {
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: IAPHelper.IAPHelperPurchaseFailNotification), object: error)
    }
}
