//
//  SingleFileTopController.swift
//  TS Analyzer
//
//  Created by GangChen on 2017/8/5.
//  Copyright © 2017年 GangChen. All rights reserved.
//

import Cocoa

protocol SingleFileTopProtocal {
    func showText(str: String)
    func showAttributedText(text: NSAttributedString)
}

class SingleFileTopController: NSViewController {
    
    var fileUrl: URL?
    var delegate: SingleFileTopProtocal?
    
    var dataLayer = "PESLayer"
    var PXXFilter = "All"
    var PXXIndexs: [String: [Int]] = [String: [Int]]()
    
    var PXXs: [(pid: UInt16, type: String, id: String, pts: UInt64, dts: UInt64, payloadOffset: UInt32, fileOffset: UInt64, size: UInt32)]
        = [(pid: UInt16, type: String, id: String, pts: UInt64, dts: UInt64, payloadOffset: UInt32, fileOffset: UInt64, size: UInt32)]()
    var TSPs: [(pid: UInt16, isStart: Bool, cCounter: UInt8, hasAdaptation: Bool, hasPayload: Bool, scrambleFlag: UInt8, PCR: UInt64, payloadSize: Int32, fileOffset: UInt64)]
        = [(pid: UInt16, isStart: Bool, cCounter: UInt8, hasAdaptation: Bool, hasPayload: Bool, scrambleFlag: UInt8, PCR: UInt64, payloadSize: Int32, fileOffset: UInt64)]()
    
    @IBOutlet weak var layerSwitch: NSSegmentedControl!
    @IBOutlet weak var filterSwitch: NSSegmentedControl!
    @IBOutlet weak var topTableView: NSTableView!
    @IBOutlet weak var topScrollView: NSScrollView!
    @IBOutlet weak var fileAnalyzeProgressBar: NSProgressIndicator!
    @IBOutlet weak var analyzingLabel: NSTextField!
    
    @IBAction func clickOnLayerSwitch(_ sender: Any) {
        switch self.layerSwitch.selectedSegment {
        case 0:
            self.dataLayer = "PESLayer"
            self.filterSwitch.isEnabled = true
        case 1:
            self.dataLayer = "TSLayer"
            self.filterSwitch.isEnabled = false
        default:
            return
        }
        self.initTopTableView()
    }
    
    @IBAction func clickOnFilterSwitch(_ sender: Any) {
        switch self.filterSwitch.selectedSegment {
        case 0:
            self.PXXFilter = "All"
        case 1:
            self.PXXFilter = "PSIOnly"
        case 2:
            self.PXXFilter = "VideoOnly"
        case 3:
            self.PXXFilter = "AudioOnly"
        default:
            return
        }
        self.topTableView.reloadData()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear() {
        self.dataLayer = "PESLayer"
        self.PXXIndexs["All"] = [Int]()
        self.PXXIndexs["PSIOnly"] = [Int]()
        self.PXXIndexs["VideoOnly"] = [Int]()
        self.PXXIndexs["AudioOnly"] = [Int]()
        
        self.filterSwitch.isEnabled = false
        self.layerSwitch.isEnabled = false
        self.topScrollView.isHidden = true
        self.analyzingLabel.isHidden = false
        self.fileAnalyzeProgressBar.isHidden = false
        
        self.initTopTableView()
        self.topTableView.delegate = self
        self.topTableView.dataSource = self
    }
    
    override func viewDidAppear() {
        DispatchQueue.global().async {
            DispatchQueue.main.async {
                self.fileAnalyzeProgressBar.minValue = 0
                self.fileAnalyzeProgressBar.doubleValue = 0
            }
            
            self.analyzeTS()
            
            DispatchQueue.main.async {
                self.layerSwitch.isEnabled = true
                self.filterSwitch.isEnabled = true
                self.topScrollView.isHidden = false
                self.analyzingLabel.isHidden = true
                self.fileAnalyzeProgressBar.isHidden = true
                self.topTableView.reloadData()
            }
        }
    }
    
    
}

extension SingleFileTopController {
    func initTopTableView() {
        self.topTableView.scrollRowToVisible(0)
        for column in self.topTableView.tableColumns {
            self.topTableView.removeTableColumn(column)
        }
        
        if self.dataLayer == "PESLayer" {
            self.tableViewAddColumn(tableview: self.topTableView, columnnName: "No.", width: 50)
            self.tableViewAddColumn(tableview: self.topTableView, columnnName: "PID", width: 50)
            self.tableViewAddColumn(tableview: self.topTableView, columnnName: "Type", width: 50)
            self.tableViewAddColumn(tableview: self.topTableView, columnnName: "TableID / StreamID", width: 150)
            self.tableViewAddColumn(tableview: self.topTableView, columnnName: "DTS", width: 80)
            self.tableViewAddColumn(tableview: self.topTableView, columnnName: "PTS", width: 80)
            self.tableViewAddColumn(tableview: self.topTableView, columnnName: "HeaderSize", width: 80)
            self.tableViewAddColumn(tableview: self.topTableView, columnnName: "OffsetInFile", width: 100)
            self.tableViewAddColumn(tableview: self.topTableView, columnnName: "Size", width: 100)
        } else if self.dataLayer == "TSLayer" {
            self.tableViewAddColumn(tableview: self.topTableView, columnnName: "No.", width: 50)
            self.tableViewAddColumn(tableview: self.topTableView, columnnName: "PID", width: 50)
            self.tableViewAddColumn(tableview: self.topTableView, columnnName: "isPesStart", width: 65)
            self.tableViewAddColumn(tableview: self.topTableView, columnnName: "cCounter", width: 60)
            self.tableViewAddColumn(tableview: self.topTableView, columnnName: "Adaptation", width: 65)
            self.tableViewAddColumn(tableview: self.topTableView, columnnName: "Payload", width: 50)
            self.tableViewAddColumn(tableview: self.topTableView, columnnName: "isScrambled", width: 80)
            self.tableViewAddColumn(tableview: self.topTableView, columnnName: "PCR", width: 100)
            self.tableViewAddColumn(tableview: self.topTableView, columnnName: "PayloadSize", width: 100)
            self.tableViewAddColumn(tableview: self.topTableView, columnnName: "OffsetInFile", width: 100)
        }
        
        self.topTableView.reloadData()
    }
    
    func tableViewAddColumn(tableview: NSTableView, columnnName: String, width: Int) {
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: columnnName))
        column.headerCell.title = columnnName
        column.width = CGFloat(width)
        tableview.addTableColumn(column)
    }
}

extension SingleFileTopController {
    func analyzeTS() {
        let tsFileAttr = try! FileManager.default.attributesOfItem(atPath: (self.fileUrl?.path)!)
        let tsFileSize = tsFileAttr[FileAttributeKey.size] as! UInt64
        DispatchQueue.main.async {
            self.fileAnalyzeProgressBar.maxValue = Double(tsFileSize * 2)
        }
        
        let demux_context: UnsafeMutablePointer<cgts_demux_context>? = cgts_demux_context_alloc_with_file((self.fileUrl?.path)!)
        
        // Parse PES layer
        var packet: UnsafeMutablePointer<cgts_pid_buffer>? = nil
        while(cgts_read_pxx_packet(demux_context, &packet) == true) {
            let pid: UInt16 = (packet?.pointee.pid)!
            let payloadOffset: UInt32 = (packet?.pointee.payload_offset)!
            let pts: UInt64 = (packet?.pointee.pts)!
            let dts: UInt64 = (packet?.pointee.dts)!
            let startAtFileOffset: UInt64 = (packet?.pointee.offset_in_file)!
            let fileOffset: UInt64 = UInt64(ftell(demux_context?.pointee.input_fp))
            
            var type: String = "Unknown"
            switch (packet?.pointee.type)! {
            case UInt8(PXX_BUF_TYPE_PSI):
                type = "PSI"
            case UInt8(PXX_BUF_TYPE_PES):
                type = "PES"
            default:
                type = "Unknown"
            }
            
            var size: UInt32 = (packet?.pointee.buf_pos)!
            let expectLength: UInt32 = (packet?.pointee.expect_len)!
            if expectLength > 0 && expectLength < size {
                size = (packet?.pointee.expect_len)!
            }
            
            var id: String = ""
            if type == "PSI" {
                let tableId = (packet?.pointee.table_id)!
                switch cgts_demux_context_pid_type(demux_context, pid) {
                case Int16(CGTS_PID_TYPE_PAT):
                    id = "PAT"
                case Int16(CGTS_PID_TYPE_PMT):
                    id = "PMT"
                case Int16(CGTS_PID_TYPE_PES):
                    id = "PES weird"
                default:
                    if tableId == UInt8(CGTS_PID_CAT) {
                        id = "CAT"
                    } else if tableId == UInt8(CGTS_PID_SDT) {
                        id = "SDT"
                    } else {
                        id = "Unknown"
                    }
                }
                id = id + " (\(tableId))"
            } else if type == "PES" {
                let streamId = (packet?.pointee.stream_id)!
                switch streamId {
                case UInt8(CGTS_STREAM_ID_AUDIO_MPEG1_MPEG2_MPEG4_AAC):
                    id = "Audio"
                case UInt8(CGTS_STREAM_ID_VIDEO_MPEG1_MPEG2_MPEG4_AVC_HEVC):
                    id = "Video"
                case UInt8(CGTS_STREAM_ID_PRIVATE_STREAM_1):
                    id = "Audio / Private"
                case UInt8(CGTS_STREAM_ID_PADDING_STREAM):
                    id = "Padding"
                case UInt8(CGTS_STREAM_ID_PROGRAM_STREAM_MAP):
                    id = "Program Map"
                case UInt8(CGTS_STREAM_ID_PRIVATE_STREAM_2):
                    id = "Private 2"
                case UInt8(CGTS_STREAM_ID_ECM):
                    id = "ECM"
                case UInt8(CGTS_STREAM_ID_EMM):
                    id = "EMM"
                case UInt8(CGTS_STREAM_ID_PROGRAM_STREAM_DIRECTORY):
                    id = "Program Directory"
                case UInt8(CGTS_STREAM_ID_DSMCC_STREAM):
                    id = "DSMCC"
                case UInt8(CGTS_STREAM_ID_H_222_1_TYPE_E):
                    id = "H.222.1 Type E"
                default:
                    id = "Unknown"
                }
                id = id + " (\(streamId))"
            } else {
                // todo...
                id = "Unknown"
                continue
            }
            
            self.PXXs.append((pid: pid, type: type, id: id, pts: pts, dts: dts, payloadOffset: payloadOffset, fileOffset: startAtFileOffset, size: size))
            
            let PXXIndex = self.PXXs.count-1
            self.PXXIndexs["All"]!.append(PXXIndex)
            if type == "PSI" {
                self.PXXIndexs["PSIOnly"]!.append(PXXIndex)
            }
            if id.contains("Video") {
                self.PXXIndexs["VideoOnly"]!.append(PXXIndex)
            }
            if id.contains("Audio") {
                self.PXXIndexs["AudioOnly"]!.append(PXXIndex)
            }
            
            DispatchQueue.main.async {
                self.fileAnalyzeProgressBar.doubleValue = Double(fileOffset)
            }
        }
        
        // Parse TS layer
        cgts_demux_context_rewind(demux_context)
        let tsp: UnsafeMutablePointer<cgts_ts_packet>? = cgts_ts_packet_alloc()
        let tsp_buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(CGTS_TS_PACKET_SIZE))
        tsp_buffer.initialize(to: 0)
        var fileOffset: UInt64 = 0
        
        while(cgts_get188(demux_context, tsp_buffer)) {
            cgts_ts_packet_parse(demux_context, tsp, tsp_buffer)
            
            let pid = (tsp?.pointee.pid)!
            var isStart = false
            if (tsp?.pointee.unit_start_indicator)! == 1 {
                isStart = true
            }
            
            let cCounter = (tsp?.pointee.continuity_counter)!
            
            var hasAdaptation = false
            if (tsp?.pointee.has_adaptation)! == 1 {
                hasAdaptation = true
            }
            var hasPayload = false
            if (tsp?.pointee.has_payload)! == 1 {
                hasPayload = true
            }
            
            let scrambleFlag = (tsp?.pointee.scrambling_control)!
            let PCR = (tsp?.pointee.pcr)!
            let payloadSize = (tsp?.pointee.payload_len)!
            
            self.TSPs.append((pid: pid, isStart: isStart, cCounter: cCounter, hasAdaptation: hasAdaptation, hasPayload: hasPayload, scrambleFlag: scrambleFlag, PCR: PCR, payloadSize: payloadSize, fileOffset: fileOffset))
            
            fileOffset = UInt64(ftell(demux_context?.pointee.input_fp))
            DispatchQueue.main.async {
                self.fileAnalyzeProgressBar.doubleValue = Double(fileOffset + tsFileSize)
            }
        }
        tsp_buffer.deinitialize(count: Int(CGTS_TS_PACKET_SIZE))
        tsp_buffer.deallocate(capacity: Int(CGTS_TS_PACKET_SIZE))
        cgts_ts_packet_free(tsp)
        
        cgts_demux_context_free(demux_context)
    }
}


extension SingleFileTopController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        if self.dataLayer == "PESLayer" {
            var rowCount = 0
            switch self.PXXFilter {
            case "All":
                rowCount = self.PXXIndexs["All"]!.count
            case "PSIOnly":
                rowCount = self.PXXIndexs["PSIOnly"]!.count
            case "VideoOnly":
                rowCount = self.PXXIndexs["VideoOnly"]!.count
            case "AudioOnly":
                rowCount = self.PXXIndexs["AudioOnly"]!.count
            default:
                rowCount = 0
            }
            //print("PESLayer")
            //print(String(rowCount))
            return rowCount
        } else if self.dataLayer == "TSLayer" {
            //print("TSLayer")
            //print(String(self.TSPs.count))
            return self.TSPs.count
        } else {
            return 0
        }
    }
}

extension SingleFileTopController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var cellText = ""
        guard let title = tableColumn?.title else {
            return nil
        }
        
        let cellView = NSTextField()
        cellView.identifier = tableColumn?.identifier
        cellView.isBordered = false
        cellView.isBezeled = false
        cellView.isEditable = false
        cellView.isSelectable = true
        cellView.drawsBackground = false
        cellView.font = NSFont.systemFont(ofSize: 11)
        
        if self.dataLayer == "PESLayer" {
            if self.PXXIndexs[self.PXXFilter]!.count <= row {
                return nil
            }
            
            let indexInPXX = self.PXXIndexs[self.PXXFilter]![row]
            switch title {
            case "No.":
                cellText = String(row)
            case "PID":
                cellText = String(self.PXXs[indexInPXX].pid)
            case "Type":
                cellText = self.PXXs[indexInPXX].type
            case "TableID / StreamID":
                cellText = self.PXXs[indexInPXX].id
            case "PTS":
                cellText = String(self.PXXs[indexInPXX].pts)
            case "DTS":
                cellText = String(self.PXXs[indexInPXX].dts)
            case "HeaderSize":
                cellText = String(self.PXXs[indexInPXX].payloadOffset)
            case "OffsetInFile":
                cellText = String(self.PXXs[indexInPXX].fileOffset)
            case "Size":
                cellText = String(self.PXXs[indexInPXX].size)
            default:
                cellText = ""
            }
            
            cellView.stringValue = cellText
            if self.PXXs[indexInPXX].type == "PSI" {
                cellView.textColor = NSColor.blue
            } else if self.PXXs[indexInPXX].id.contains("Audio") {
                cellView.textColor = NSColor.darkGray
            }
        } else if self.dataLayer == "TSLayer" {
            switch title {
            case "No.":
                cellText = String(row)
            case "PID":
                cellText = String(self.TSPs[row].pid)
            case "isPesStart":
                cellText = bool2String(flag: self.TSPs[row].isStart)
            case "cCounter":
                cellText = String(self.TSPs[row].cCounter)
            case "Adaptation":
                cellText = bool2String(flag: self.TSPs[row].hasAdaptation)
            case "Payload":
                cellText = bool2String(flag: self.TSPs[row].hasPayload)
            case "isScrambled":
                cellText = String(self.TSPs[row].scrambleFlag)
            case "PCR":
                cellText = String(self.TSPs[row].PCR)
            case "PayloadSize":
                cellText = String(self.TSPs[row].payloadSize)
            case "OffsetInFile":
                cellText = String(self.TSPs[row].fileOffset)
            default:
                cellText = ""
            }
            cellView.stringValue = cellText
        }
        return cellView
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = self.topTableView.selectedRow
        if row == -1 {
            return
        }
        guard let path = self.fileUrl?.path else {
            return
        }
        guard let file: FileHandle = FileHandle(forReadingAtPath: path) else {
            return
        }
        
        let hexString: NSMutableAttributedString = NSMutableAttributedString()
        if self.dataLayer == "PESLayer" {
            let indexInPXX = self.PXXIndexs[self.PXXFilter]![row]
            let offset = UInt64(self.PXXs[indexInPXX].fileOffset)
            let pidOfPES = UInt16(self.PXXs[indexInPXX].pid)
            
            let demux_context: UnsafeMutablePointer<cgts_demux_context>? = cgts_demux_context_alloc_with_file((self.fileUrl?.path)!)
            fseek(demux_context?.pointee.input_fp, Int(offset), SEEK_SET)
            let tsp: UnsafeMutablePointer<cgts_ts_packet>? = cgts_ts_packet_alloc()
            
            let tsp_buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(CGTS_TS_PACKET_SIZE))
            tsp_buffer.initialize(to: 0)
            
            var startPacketFound = false
            while(cgts_get188(demux_context, tsp_buffer)) {
                cgts_ts_packet_parse(demux_context, tsp, tsp_buffer)
                
                let pid = (tsp?.pointee.pid)!
                if pid != pidOfPES {
                    continue
                }
                
                var isStart = false
                if (tsp?.pointee.unit_start_indicator)! == 1 {
                    isStart = true
                }
                
                if isStart == true {
                    if startPacketFound == false {
                        startPacketFound = true
                        hexString.append(self.unsafeMutablePointer2AttributedString(buffer: tsp_buffer, bufferLength: Int(CGTS_TS_PACKET_SIZE)))
                    } else {
                        break
                    }
                } else {
                    hexString.append(self.unsafeMutablePointer2AttributedString(buffer: tsp_buffer, bufferLength: Int(CGTS_TS_PACKET_SIZE)))
                }
                hexString.append(NSAttributedString(string: "\n\n"))
                
            }
            
            tsp_buffer.deinitialize(count: Int(CGTS_TS_PACKET_SIZE))
            tsp_buffer.deallocate(capacity: Int(CGTS_TS_PACKET_SIZE))
            
            cgts_ts_packet_free(tsp)
            cgts_demux_context_free(demux_context)
        } else if self.dataLayer == "TSLayer" {
            let offset = UInt64(self.TSPs[row].fileOffset)
            let size = Int(CGTS_TS_PACKET_SIZE)
            
            file.seek(toFileOffset: offset)
            hexString.append(self.data2AttributedString(data: file.readData(ofLength: size)))
        } else {
            file.closeFile()
            return
        }
        
        file.closeFile()
        self.delegate?.showAttributedText(text: hexString)
    }
}

extension SingleFileTopController {
    func bool2String(flag: Bool) -> String {
        if flag == true {
            return "yes"
        } else {
            return "no"
        }
    }
    
    func data2AttributedString(data: Data) -> NSAttributedString {
        let hexString: NSMutableAttributedString = NSMutableAttributedString()
        let attrA: [NSAttributedStringKey : Any] = [NSAttributedStringKey.font: NSFont(name: "Monaco", size: 12)!, NSAttributedStringKey.foregroundColor: NSColor.gray]
        let attrB: [NSAttributedStringKey : Any] = [NSAttributedStringKey.font: NSFont(name: "Monaco", size: 12)!, NSAttributedStringKey.foregroundColor: NSColor.black]
        let attrC: [NSAttributedStringKey : Any] = [NSAttributedStringKey.font: NSFont(name: "Monaco", size: 12)!, NSAttributedStringKey.foregroundColor: NSColor.orange]
        
        for i in 0 ..< data.count {
            if i % 32 == 0 {
                hexString.append(NSAttributedString(string: "0x\(String(format: "%06x", i)): ", attributes: attrA))
            }
            
            if i < Int(CGTS_TS_PACKET_HEADER_SIZE) {
                hexString.append(NSAttributedString(string: String(format: "%02x ", data[i]), attributes: attrC))
            } else {
                hexString.append(NSAttributedString(string: String(format: "%02x ", data[i]), attributes: attrB))
            }
            
            if (i + 1) % 32 == 0 {
                hexString.append(NSAttributedString(string: "\n"))
            }
        }
        
        return hexString as NSAttributedString
    }
    
    func unsafeMutablePointer2AttributedString(buffer: UnsafeMutablePointer<UInt8>, bufferLength: Int) -> NSAttributedString {
        let hexString: NSMutableAttributedString = NSMutableAttributedString()
        let attrA: [NSAttributedStringKey : Any] = [NSAttributedStringKey.font: NSFont(name: "Monaco", size: 12)!, NSAttributedStringKey.foregroundColor: NSColor.gray]
        let attrB: [NSAttributedStringKey : Any] = [NSAttributedStringKey.font: NSFont(name: "Monaco", size: 12)!, NSAttributedStringKey.foregroundColor: NSColor.black]
        let attrC: [NSAttributedStringKey : Any] = [NSAttributedStringKey.font: NSFont(name: "Monaco", size: 12)!, NSAttributedStringKey.foregroundColor: NSColor.orange]
        
        for i in 0 ..< bufferLength {
            if i % 32 == 0 {
                hexString.append(NSAttributedString(string: "0x\(String(format: "%06x", i)): ", attributes: attrA))
            }
            
            if i < Int(CGTS_TS_PACKET_HEADER_SIZE) {
                hexString.append(NSAttributedString(string: String(format: "%02x ", buffer[i]), attributes: attrC))
            } else {
                hexString.append(NSAttributedString(string: String(format: "%02x ", buffer[i]), attributes: attrB))
            }
            
            if (i + 1) % 32 == 0 {
                hexString.append(NSAttributedString(string: "\n"))
            }
        }
        
        return hexString as NSAttributedString
    }
    
    func data2HexString(data: Data) -> String {
        var hexString: String = ""
        for i in 0 ..< data.count {
            if i % 32 == 0 {
                hexString += "0x\(String(format: "%06x", i)): "
            }
            hexString += String(format: "%02x ", data[i])
            if (i + 1) % 32 == 0 {
                hexString += "\n"
            }
        }
        return hexString
    }
    
    func unsafeMutablePointer2HexString(buffer: UnsafeMutablePointer<UInt8>, bufferLength: Int) -> String {
        var hexString: String = ""
        for i in 0 ..< bufferLength {
            if i % 32 == 0 {
                hexString += "0x\(String(format: "%06x", i)): "
            }
            hexString += String(format: "%02x ", buffer[i])
            if (i + 1) % 32 == 0 {
                hexString += "\n"
            }
        }
        return hexString
    }
}


