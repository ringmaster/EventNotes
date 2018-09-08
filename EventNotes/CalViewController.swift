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
    
    @IBAction func pickerChange(_ sender: NSDatePicker) {
        
        let isoFormatter = DateFormatter()
        isoFormatter.dateFormat = "yyyy-MM-dd"
        
        build.title = "Create Notes from " + isoFormatter.string(from: sender.dateValue)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        picker.dateValue = Date()
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
