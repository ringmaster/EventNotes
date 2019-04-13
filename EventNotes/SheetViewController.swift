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

    @IBOutlet weak var bearTokenBox: NSTextField!
    @IBOutlet weak var templatesTagsBox: NSTextField!
    @IBOutlet weak var calList: NSComboBox!
    
    @IBAction func bearTokenChanged(_ sender: NSTextField) {
        UserDefaults.standard.set(sender.stringValue, forKey: "bearToken")
    }
    
    @IBAction func templatesTagChanged(_ sender: NSTextField) {
        UserDefaults.standard.set(sender.stringValue, forKey: "templatesTag")
    }
    
    @IBAction func calListChanged(_ sender: NSComboBox) {
        UserDefaults.standard.set(sender.stringValue, forKey: "calendarName")
    }
    
    override func viewDidLoad() {
        if let templatestag = UserDefaults.standard.string(forKey: "templatesTag") {
            templatesTagsBox.stringValue = templatestag
        }
        else {
            templatesTagsBox.stringValue = "templates"
        }
        if let token = UserDefaults.standard.string(forKey: "bearToken") {
            bearTokenBox.stringValue = token
        }
        else {
            bearTokenBox.stringValue = ""
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
