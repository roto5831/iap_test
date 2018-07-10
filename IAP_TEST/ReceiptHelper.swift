//
//  ReceiptHelper.swift
//  IAP_TEST
//
//  Created by 小林 宏知 on 2018/06/28.
//  Copyright © 2018年 小林 宏知. All rights reserved.
//

import Foundation
//iTunes Connectからアプリ毎に発行
private let itcAccountSecret = "95a2b9bcba974ec98ae04d68336b9517"

public enum Result<T> {
    case failure(ReceiptError)
    case success(T)
}

public typealias UploadReceiptCompletion = (_ result: Result<(sessionId: String, currentSubscription: PaidSubscription?)>) -> Void

public typealias SessionId = String

public enum ReceiptError: Error {
    case missingAccountSecret
    case invalidSession
    case noActiveSubscription
    case other(Error)
}
/// レシートお助けマン
/// TODO upload処理はサーバーサイドで実装
/// 検証終了後、アプリに課金コンテンツを反映させるクラスを持たせても良いかも
public class ReceiptHelper {
    
    public static let shared = ReceiptHelper()
    let simulatedStartDate: Date
    
    private var sessions = [SessionId: Session]()
    
    init() {
        let persistedDateKey = "RWSSimulatedStartDate"
        if let persistedDate = UserDefaults.standard.object(forKey: persistedDateKey) as? Date {
            simulatedStartDate = persistedDate
        } else {
            let date = Date().addingTimeInterval(-30) // 30 second difference to account for server/client drift.
            UserDefaults.standard.set(date, forKey: "RWSSimulatedStartDate")
            
            simulatedStartDate = date
        }
    }
    
    /// レシートをロードする
    ///
    /// - Returns:
    public func loadReceipt() -> Data? {
        guard let url = Bundle.main.appStoreReceiptURL else {
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            return data
        } catch {
            print("Error loading receipt data: \(error.localizedDescription)")
            return nil
        }
    }
    
    //TODO レシートをAppleに送信はサーバーサイド側でやる　クライアント側ではやらない
    public func upload(receipt data: Data, completion: @escaping UploadReceiptCompletion) {
        let body = [
            "receipt-data": data.base64EncodedString(),
            "password": itcAccountSecret
        ]
        let bodyData = try! JSONSerialization.data(withJSONObject: body, options: [])
        /*
         本番と開発とで送信する場所が違うのでレシートを本番環境へ送信する際には実装に工夫が必要
            戻り値を確認
            Codeが"0"の場合は、成功処理へ
            Codeが"21007"の場合は、サンドボックス環境へ送信する
                戻り値を確認
                Codeが"0"の場合は、成功処理へ
                Codeが上記以外の場合は、エラー処理へ
            Codeが上記以外の場合は、エラー処理へ
         参考：http://developer.wonderpla.net/entry/blog/engineer/ios_in-app-purchase/
         */
        let url = URL(string: "https://sandbox.itunes.apple.com/verifyReceipt")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        let task = URLSession.shared.dataTask(with: request) { (responseData, response, error) in
            if let error = error {
                completion(.failure(.other(error)))
            } else if let responseData = responseData {
                let json = try! JSONSerialization.jsonObject(with: responseData, options: []) as! Dictionary<String, Any>
                print(json)
                let session = Session(receiptData: data, parsedReceipt: json)
                self.sessions[session.id] = session
                let result = (sessionId: session.id, currentSubscription: session.currentSubscription)
                completion(.success(result))
            }
        }
        task.resume()
    }
}
