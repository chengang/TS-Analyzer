//
//  MainView.swift
//  TS Analyzer
//
//  Created by ChenGang on 2017/8/4.
//  Copyright © 2017年 GangChen. All rights reserved.
//

import Cocoa

class MainView: NSView {
    
    var isReceivingDrag = false {
        didSet {
            needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        if self.isReceivingDrag {
            NSColor.selectedControlColor.set()
            
            let path = NSBezierPath(rect: bounds)
            path.lineWidth = 9
            path.stroke()
        }
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([NSPasteboard.PasteboardType.fileURL, NSPasteboard.PasteboardType.font])
        //registerForDraggedTypes([NSFilenamesPboardType, NSFontPboardType])
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard let board = sender.draggingPasteboard().propertyList(forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType"))  as? NSArray else {
            return []
        }
        
        guard let path = board[0] as? String else {
            return []
        }
        
        let url = URL(fileURLWithPath: path)
        
        if url.pathExtension.lowercased() == "ts" {
            self.isReceivingDrag = true
            return NSDragOperation.copy
        } else {
            return []
        }
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        self.isReceivingDrag = false
    }
    
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pasteBoard = sender.draggingPasteboard()
        if pasteBoard.canReadObject(forClasses: [NSURL.self], options: nil) {
            return true
        }
        return false
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        self.isReceivingDrag = false
        
        let pastBoard = sender.draggingPasteboard()
        if let urls = pastBoard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], urls.count > 0 {
            let myController = self.window?.contentViewController as! MainController
            myController.processTSs(urls: urls)
            return true
        }
        return false
    }
}
