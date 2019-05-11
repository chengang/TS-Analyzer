//
//  SingleFileBottomController.swift
//  TS Analyzer
//
//  Created by GangChen on 2017/8/5.
//  Copyright © 2017年 GangChen. All rights reserved.
//

import Cocoa

class SingleFileBottomController: NSViewController {

    @IBOutlet var bottomTextView: NSTextView!
    @IBOutlet weak var bottomTextViewScrollView: NSScrollView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.bottomTextView.font = NSFont.init(name: "Monaco", size: 12)
        self.bottomTextView.isContinuousSpellCheckingEnabled = false
        //self.bottomTextView.isEditable = false
        self.bottomTextView.isAutomaticLinkDetectionEnabled = false
        self.bottomTextView.delegate = self
    }
}

extension SingleFileBottomController: SingleFileTopProtocal {
    func showText(str: String) {
        self.bottomTextView.scrollToBeginningOfDocument(self)
        self.bottomTextView.string = str
    }
    
    func showAttributedText(text: NSAttributedString) {
        self.bottomTextView.scrollToBeginningOfDocument(self)
        self.bottomTextView.textStorage?.setAttributedString(text)
    }
}

extension SingleFileBottomController: NSTextViewDelegate {
    func textView(_ textView: NSTextView, willChangeSelectionFromCharacterRanges oldSelectedCharRanges: [NSValue], toCharacterRanges newSelectedCharRanges: [NSValue]) -> [NSValue] {
        var ranges: [NSValue] = []
        for range in newSelectedCharRanges {
            if (range as! NSRange).length <= 1536 {
                ranges.append(contentsOf: self.range2RangesDisselectLineNumbers(r: range as! NSRange) as [NSValue])
            } else {
                ranges.append(range)
            }
        }
        if ranges.count == 0 {
            ranges.append(NSMakeRange(0, 0) as NSValue)
        }
        return ranges
    }
    
    func range2RangesDisselectLineNumbers(r: NSRange) -> [NSRange] {
        var ranges: [NSRange] = []
        if r.length == 0 {
            return ranges
        }
        
        let selectedString: String = (self.bottomTextView.string as NSString).substring(with: r)
        let offsetInWholeString = r.location
        var startPostion = 0
        
        for i in selectedString.indices {
            let distance = selectedString.distance(from: selectedString.startIndex, to: i)
            
            if selectedString[i] == ":" {
                startPostion = distance + 2
                continue
            }
            //print("distance: \(distance), length: \(selectedString.characters.count), startPostion: \(startPostion), \(selectedString[i])")
            
            var aRange = NSMakeRange(0, 0)
            if selectedString[i] == "\n" && distance > startPostion {
                aRange = NSMakeRange(offsetInWholeString + startPostion, distance - startPostion - 1)
                startPostion = distance
            } else if distance == selectedString.count - 1  {
                if selectedString[i] == " " {
                    aRange = NSMakeRange(offsetInWholeString + startPostion, distance - startPostion)
                } else {
                    aRange = NSMakeRange(offsetInWholeString + startPostion, distance - startPostion + 1)
                }
            }
            
            if aRange.length != 0 {
                //print("rang: \(aRange.location), \(aRange.length)")
                ranges.append(aRange)
            }
        }
        
        return ranges
    }
    
//    func textViewDidChangeSelection(_ notification: Notification) {
//        print(self.bottomTextView.selectedRanges)
//    }
}
