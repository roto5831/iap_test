//
//  ReceiptHelper.swift
//  IAP_TEST
//
//  Created by 小林 宏知 on 2018/06/28.
//  Copyright © 2018年 小林 宏知. All rights reserved.
//

import Foundation
private let itcAccountSecret = "YOUR_ACCOUNT_SECRET"

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
