//
//  AppDelegate.swift
//  TS Analyzer
//
//  Created by GangChen on 2017/8/3.
//  Copyright © 2017年 GangChen. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let receiptValidation = ReceiptValidation()
        if receiptValidation == nil {
            exit(173);
        }
    }


    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }


}

