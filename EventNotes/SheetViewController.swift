//
//  SheetViewController.swift
//  EventNotes
//
//  Created by Owen Winkler on 2/24/19.
//  Copyright © 2019 Owen Winkler. All rights reserved.
//

import Foundation
import Cocoa

class SheetViewController: NSViewController {

    @IBOutlet weak var dateTagPrefix: NSTextField!
    @IBOutlet weak var o3TagPrefix: NSTextField!
    @IBOutlet weak var calList: NSComboBox!
    
    @IBAction func dateTagChanged(_ sender: NSTextField) {
        UserDefaults.standard.set(sender.stringValue, forKey: "dateTagPrefix")
    }
    
    @IBAction func o3TagPrefixChanged(_ sender: NSTextField) {
        UserDefaults.standard.set(sender.stringValue, forKey: "o3TagPrefix")
    }
    
    @IBAction func calListChanged(_ sender: NSComboBox) {
        UserDefaults.standard.set(sender.stringValue, forKey: "calendarName")
    }
    
    override func viewDidLoad() {
        if let prefix = UserDefaults.standard.string(forKey: "o3TagPrefix") {
            o3TagPrefix.stringValue = prefix
        }
        else {
            o3TagPrefix.stringValue = "work/O3"
        }
        if let prefix = UserDefaults.standard.string(forKey: "dateTagPrefix") {
            dateTagPrefix.stringValue = prefix
        }
        else {
            dateTagPrefix.stringValue = "work/date"
        }
        let calendars = cal.getCalendarList()
        calList.addItems(withObjectValues: calendars)
        if let calendarName = UserDefaults.standard.string(forKey: "calendarName") {
            if let calindex = calendars.index(of: calendarName) {
                calList.selectItem(at: calindex)
                calList.stringValue = calendarName
            }
        }
    }
}
