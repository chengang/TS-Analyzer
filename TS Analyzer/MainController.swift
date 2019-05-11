//
//  MainController.swift
//  TS Analyzer
//
//  Created by GangChen on 2017/8/3.
//  Copyright © 2017年 GangChen. All rights reserved.
//

import Cocoa

class MainController: NSViewController {
    let singleFileStoryboard = NSStoryboard(name: NSStoryboard.Name(rawValue: "SingleFile"), bundle: nil)
    var popedWindows: [NSWindow] = [NSWindow]()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.window?.windowController?.shouldCascadeWindows = true
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    @IBAction func clickOnChooseFiles(_ sender: Any) {
        let dialog = NSOpenPanel()
        dialog.title = "Choose .ts files"
        dialog.showsResizeIndicator = true
        dialog.showsHiddenFiles = false
        dialog.canChooseDirectories = false
        dialog.canCreateDirectories = false
        dialog.allowsMultipleSelection = true
        dialog.allowedFileTypes = ["ts", "mpg", "mpeg"]
        
        if dialog.runModal() == NSApplication.ModalResponse.OK {
            processTSs(urls: dialog.urls)
        }
        return
    }
    
    func processTSs(urls: [URL]) {
        for url in urls {
            guard let file: FileHandle = FileHandle(forReadingAtPath: url.path) else {
                continue
            }
            
            let tsStartByte = Data(bytes: [0x47])
            
            let firstCharacter = file.readData(ofLength: 1)
            file.closeFile()
            
            if firstCharacter != tsStartByte {
                //print("not valid MPEG-TS")
                self.showAlertWindow(url: url)
                continue
            }
            //print("vaild")
            
            self.showSingleFileWindow(url: url)
        }
    }
    
    func showSingleFileWindow(url: URL) {
        let singleFileVC = singleFileStoryboard.instantiateInitialController() as! SingleFileController
        singleFileVC.fileUrl = url
        
        let w = NSWindow(contentViewController: singleFileVC)
        w.windowController?.shouldCascadeWindows = true
        
        let topOffset : CGFloat = 20 * CGFloat(self.popedWindows.count + 1)
        let leftOffset: CGFloat = 20 * CGFloat(self.popedWindows.count + 1)
        let newOriginY = (w.screen?.visibleFrame)!.maxY - w.frame.height - topOffset
        w.setFrameOrigin(NSPoint(x: leftOffset, y: newOriginY))
        
        w.makeKeyAndOrderFront(self)
        self.popedWindows.append(w) // MUST hold the ref, otherwise the window will be killed by GC
    }
    
    func showAlertWindow(url: URL) {
        let alert = NSAlert()
        alert.messageText = "Not valid MPEG-TS file"
        alert.informativeText = url.absoluteString
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

