//
//  AppDelegate.swift
//  IAP_TEST
//
//  Created by 小林 宏知 on 2018/06/28.
//  Copyright © 2018年 小林 宏知. All rights reserved.
//

import UIKit
import StoreKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        //いつ支払トランザクション処理を受け取っても大丈夫なようにアプリ起動時に登録
        SKPaymentQueue.default().add(IAPHelper.shared)
        return true
    }
}

