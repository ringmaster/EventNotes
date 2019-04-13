//
//  CalViewController.swift
//  EventNotes
//
//  Created by Owen Winkler on 9/3/18.
//  Copyright © 2018 Owen Winkler. All rights reserved.
//

import Cocoa
import EventKit

let cal = BBCalendar.shared
var bizcache = [String]()
var nextEvent: EKEvent?

class CalViewController: NSViewController, NSUserNotificationCenterDelegate, DayViewDelegate {

    @IBOutlet weak var picker: NSDatePicker!
    @IBOutlet weak var build: NSButton!
    @IBOutlet weak var join: NSButton!
    
    @IBOutlet weak var calList: NSComboBox!
    @IBOutlet weak var dateTagPrefix: NSTextField!
    @IBOutlet weak var o3TagPrefix: NSTextField!
    @IBOutlet weak var dayView: DayView!
    
    lazy var sheetViewController: NSViewController = {
        return self.storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "SheetViewController"))
            as! NSViewController
    }()
    
    @IBAction func pickerChange(_ sender: NSDatePicker) {
        
        let isoFormatter = DateFormatter()
        isoFormatter.dateFormat = "yyyy-MM-dd"
        
        build.title = "Create Notes from " + isoFormatter.string(from: sender.dateValue)
        
        self.updateStatus()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        picker.dateValue = Date()
        dayView.delegate = self
        
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) {_ in
            self.updateStatus()
        }
        self.updateStatus()

        NSUserNotificationCenter.default.delegate = self
        
        self.view.window?.acceptsMouseMovedEvents = true
    }
    
    override func viewWillDisappear() {
        self.dismiss(sheetViewController)
    }
    
    func updateStatus() {
        if let current:EKEvent = cal.currentEvent() {
            if cal.bluejeansRoom() != nil {
                join.title = "Join " + current.title!
                join.isEnabled = true
            }
            else {
                join.title = "Note for " + current.title!
                join.isEnabled = true
            }
        }
        else {
            join.title = "No Current Meeting"
            join.isEnabled = false
        }
        if let newEvent:EKEvent = cal.nextEvent() {
            if nextEvent == nil || nextEvent!.eventIdentifier != newEvent.eventIdentifier {
                nextEvent = newEvent
                
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm"
                
                let notification = NSUserNotification()
                notification.identifier = nextEvent!.eventIdentifier
                notification.title = nextEvent!.title
                notification.subtitle = formatter.string(from: nextEvent!.startDate)
                // notification.informativeText = "This is a test"
                // notification.soundName = NSUserNotificationDefaultSoundName
                // notification.contentImage = NSImage(contentsOfURL: NSURL(string: "https://placehold.it/300")!)
                notification.hasActionButton = true
                if let _:String = cal.bluejeansRoom(event: nextEvent) {
                    notification.actionButtonTitle = "Join"
                }
                else {
                    notification.actionButtonTitle = "Read"
                }
                
                // Manually display the notification
                let notificationCenter = NSUserNotificationCenter.default
                //notificationCenter.deliver(notification)
                
                var dayComp = DateComponents()
                dayComp.minute = -4
                let date = Calendar.current.date(byAdding: dayComp, to: nextEvent!.startDate)
                
                notification.deliveryDate = date
                notificationCenter.scheduleNotification(notification)
            }
        }
        
        let appDelegate = NSApplication.shared.delegate as! AppDelegate
        appDelegate.statusItem.title = cal.currentEventTitle()
        
        let events = cal.getEventsByDate(target: picker.dateValue)
        self.dayView.setDates(newDates: events)
    }
    
    func userNotificationCenter(_ center: NSUserNotificationCenter, didActivate notification: NSUserNotification) {
        switch (notification.activationType) {
        case .actionButtonClicked:
            joinMeeting()
            break;
        default:
            break;
        }
    }
    
    func userNotificationCenter(_ center: NSUserNotificationCenter, shouldPresent notification: NSUserNotification) -> Bool {
        return true
    }
    
    @IBAction func calendarChanged(_ sender: NSComboBox) {
        UserDefaults.standard.set(sender.stringValue, forKey: "calendarName")
        self.updateStatus()
    }
    
    @IBAction func datePrefixChanged(_ sender: NSTextField) {
        UserDefaults.standard.set(sender.stringValue, forKey: "dateTagPrefix")
    }
    
    @IBAction func o3PrefixChanged(_ sender: NSTextField) {
        UserDefaults.standard.set(sender.stringValue, forKey: "o3TagPrefix")
    }
    
    @IBAction func buildClicked(_ sender: Any) {
        cal.build(target: picker.dateValue)
    }
    
    @IBAction func buildTodayClicked(_ sender: Any) {
        cal.buildToday()
    }
    @IBAction func buildTomorrowClicked(_ sender: Any) {
        cal.buildTomorrow()
    }
    @IBAction func quitClicked(_ sender: Any) {
        NSApplication.shared.terminate(self)
    }
    
    @IBAction func joinClicked(_ sender: NSButton) {
        joinMeeting()
    }
    
    @IBAction func getTemplatesClicked(_ sender: Any) {
        cal.getTemplates()
    }
    
    @IBAction func settingsClicked(_ sender: Any) {
        self.presentViewControllerAsSheet(sheetViewController)
    }
    
    func joinMeeting() {
        if let bjRoom:String = cal.bluejeansRoom() {
            print("BlueJeans room: " + bjRoom)
            var urlComponents = URLComponents()
            urlComponents.scheme = "bjnb"
            urlComponents.host = "meet"
            urlComponents.path = "/id/" + bjRoom
            
            let url = urlComponents.url
            if let url:URL = url, NSWorkspace.shared.open(url){
                print("Opened the browser to " + url.absoluteString)
            }
            else {
                print("Couldn't open: " + urlComponents.url!.absoluteString)
            }
        }
        else {
            if let title:String = cal.currentMeetingNoteName() {
                var urlComponents = URLComponents()
                urlComponents.scheme = "bear"
                urlComponents.host = "x-callback-url"
                urlComponents.path = "/open-note/"
                urlComponents.queryItems = [
                    URLQueryItem(name: "title", value: title)
                ]
                
                let url = urlComponents.url
                if let url:URL = url, NSWorkspace.shared.open(url){
                    print("Opened the browser to " + url.absoluteString)
                }
                else {
                    print("Couldn't open: " + urlComponents.url!.absoluteString)
                }
            }
        }
    }
    
    func dateUpdate() {
        if Date().timeIntervalSince(picker.dateValue) >= 86400 {
            picker.dateValue = Date()
        }
    }
    
    /**************************************
     DayViewDelegate
     **************************************/
    
    func dayView(_: DayView, didReceiveClickForDate date: EKEvent) {
        cal.upsertNoteFromEvent(event: date)
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

