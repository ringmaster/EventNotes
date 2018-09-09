//
//  CalViewController.swift
//  EventNotes
//
//  Created by Owen Winkler on 9/3/18.
//  Copyright © 2018 Owen Winkler. All rights reserved.
//

import Cocoa

class CalViewController: NSViewController {

    @IBOutlet weak var picker: NSDatePicker!
    @IBOutlet weak var build: NSButton!
    
    @IBOutlet weak var calList: NSComboBox!
    @IBOutlet weak var dateTagPrefix: NSTextField!
    @IBOutlet weak var o3TagPrefix: NSTextField!
    
    @IBAction func pickerChange(_ sender: NSDatePicker) {
        
        let isoFormatter = DateFormatter()
        isoFormatter.dateFormat = "yyyy-MM-dd"
        
        build.title = "Create Notes from " + isoFormatter.string(from: sender.dateValue)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        picker.dateValue = Date()
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
        let cal = BBCalendar()
        let calendars = cal.getCalendarList()
        calList.addItems(withObjectValues: calendars)
        if let calendarName = UserDefaults.standard.string(forKey: "calendarName") {
            if let calindex = calendars.index(of: calendarName) {
                calList.selectItem(at: calindex)
                calList.stringValue = calendarName
            }
        }
    }
    
    @IBAction func calendarChanged(_ sender: NSComboBox) {
        UserDefaults.standard.set(sender.stringValue, forKey: "calendarName")
        let cal = BBCalendar()
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        appDelegate.statusItem.title = cal.currentEventTitle()
    }
    
    @IBAction func datePrefixChanged(_ sender: NSTextField) {
        UserDefaults.standard.set(sender.stringValue, forKey: "dateTagPrefix")
    }
    
    @IBAction func o3PrefixChanged(_ sender: NSTextField) {
        UserDefaults.standard.set(sender.stringValue, forKey: "o3TagPrefix")
    }
    
    @IBAction func buildClicked(_ sender: NSButtonCell) {
        let cal = BBCalendar()
        cal.build(target: picker.dateValue)
    }
    
    @IBAction func quitClicked(_ sender: NSButton) {
        NSApplication.shared.terminate(self)
    }
}

extension CalViewController {
    // MARK: Storyboard instantiation
    static func freshController() -> CalViewController {
        //1.
        let storyboard = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil)
        //2.
        let identifier = NSStoryboard.SceneIdentifier(rawValue: "CalViewController")
        //3.
        guard let viewcontroller = storyboard.instantiateController(withIdentifier: identifier) as? CalViewController else {
            fatalError("Why cant i find QuotesViewController? - Check Main.storyboard")
        }
        return viewcontroller
    }
}
