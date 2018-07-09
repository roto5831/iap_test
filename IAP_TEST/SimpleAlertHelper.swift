//
//  SimpleAlertHelper.swift
//  FirstPassport
//
//  Created by Kentaro on 2017/07/01.
//  Copyright © 2017年 Smart Tech Ventures. All rights reserved.
//

import UIKit

protocol SimpleAlertHelperDelegate: class {
    /// OKボタンタップ時の処理
    func didTapOKButton()
}

/// シンプルなアラート用ヘルパークラス
final class SimpleAlertHelper {
    
    weak var delegate: SimpleAlertHelperDelegate?
    private var alert: UIAlertController?
    
    /// OKボタンとメッセージを表示するだけのアラートを返す
    /// - タイトルが渡されればタイトルも表示
    ///
    /// - Parameters:
    ///   - message: アラートメッセージ
    ///   - title: アラートタイトル (default: "")
    ///   - delegate: 完了通知用のdelegate (default: nil)
    /// - Returns: 完了通知用のdelegate (default: nil)
    func alert(message: String,
               title: String = "",
               delegate: SimpleAlertHelperDelegate? = nil) -> UIAlertController? {
        
        self.delegate = delegate
        
        /* メソッド化
         alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
         let ok = UIAlertAction(title: "BUTTON_OK".localized(), style: .cancel) { _ in
         self.delegate?.didTapOKButton()
         }
         
         alert?.addAction(ok)
         */
        
        let okHandler: ((UIAlertAction) -> Void)? = { _ in
            self.delegate?.didTapOKButton()
        }
        createAlert(title: title, message: message, preferredStyle: .alert, okHandler: okHandler, cancelHandler: nil)
        
        return alert
    }
    
    
    /// クロージャ版
    func alert(message: String,
               title: String = "",
               didTapOKButton: @escaping ((UIAlertAction) -> Void)) -> UIAlertController? {
        
        createAlert(title: title, message: message, preferredStyle: .alert, okHandler: didTapOKButton, cancelHandler: nil)
        
        return alert
    }
    
    
    private func createAlert(title: String?, message: String?, preferredStyle: UIAlertControllerStyle,
                             okHandler: ((UIAlertAction) -> Void)?,
                             cancelHandler: ((UIAlertAction) -> Void)?) {
        alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let ok = UIAlertAction(title: "OK", style: .cancel, handler: okHandler)
        
        alert?.addAction(ok)
    }
}
