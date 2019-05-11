//
//  SingleFileController.swift
//  TS Analyzer
//
//  Created by GangChen on 2017/8/5.
//  Copyright © 2017年 GangChen. All rights reserved.
//

import Cocoa

class SingleFileController: NSSplitViewController {
    
    var fileUrl: URL?
    var topController: SingleFileTopController!
    var bottomController: SingleFileBottomController!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        //self.view.wantsLayer = true
        self.view.translatesAutoresizingMaskIntoConstraints = true
        self.title = self.fileUrl?.path
        
        for item in self.splitViewItems {
            let controller = item.viewController
            if controller is SingleFileTopController {
                self.topController = controller as! SingleFileTopController
                self.topController.fileUrl = self.fileUrl
            } else if controller is SingleFileBottomController {
                self.bottomController = controller as! SingleFileBottomController
            }
        }
        
        self.topController.delegate = self.bottomController

    }
    
    override func viewDidAppear() {
        let _ = self.view.window?.styleMask.remove(NSWindow.StyleMask.resizable)
    }
    
    override func splitView(_ splitView: NSSplitView, constrainSplitPosition proposedPosition: CGFloat, ofSubviewAt dividerIndex: Int) -> CGFloat {
        return self.view.bounds.height / 2.0
    }
    
}
