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
    
    var shownSunday: Date = Date()
    var selectedDay: Date = Date()

    @IBOutlet weak var dayView: DayView!
    
    @IBOutlet weak var dayButton1: NSButton!
    @IBOutlet weak var dayButton2: NSButton!
    @IBOutlet weak var dayButton3: NSButton!
    @IBOutlet weak var dayButton4: NSButton!
    @IBOutlet weak var dayButton5: NSButton!
    @IBOutlet weak var dayButton6: NSButton!
    @IBOutlet weak var dayButton7: NSButton!
    
    lazy var sheetViewController: NSViewController = {
        return self.storyboard!.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "SheetViewController"))
            as! NSViewController
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        dayView.delegate = self
        
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) {_ in
            self.updateStatus()
        }
        self.updateStatus()

        NSUserNotificationCenter.default.delegate = self
        
        self.view.window?.acceptsMouseMovedEvents = true
        
        selectedDay = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month, .day], from: Date()))!
        shownSunday = selectedDay

        setDayButtons()
    }
    
    override func viewWillDisappear() {
        self.dismiss(sheetViewController)
    }
    
    func setDayButtons() {
        let sundiff = Calendar.current.component(.weekday, from: shownSunday) % 7
        shownSunday = Calendar.current.date(byAdding: .day, value: -sundiff+1, to: shownSunday)!

        setDayButton(btn: dayButton1, day: shownSunday, diff: 0)
        setDayButton(btn: dayButton2, day: shownSunday, diff: 1)
        setDayButton(btn: dayButton3, day: shownSunday, diff: 2)
        setDayButton(btn: dayButton4, day: shownSunday, diff: 3)
        setDayButton(btn: dayButton5, day: shownSunday, diff: 4)
        setDayButton(btn: dayButton6, day: shownSunday, diff: 5)
        setDayButton(btn: dayButton7, day: shownSunday, diff: 6)
    }
    
    func setDayButton(btn: NSButton, day: Date, diff: NSInteger = 0) {
        let btnDate = Calendar.current.date(byAdding: .day, value: diff, to: shownSunday)!
        let dayint = Calendar.current.component(.day, from: btnDate)
        
        if dayint == 1 {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "LLL"
            btn.title = dateFormatter.string(from: Calendar.current.date(byAdding: .day, value: diff, to: shownSunday)!)
        }
        else {
            btn.title = String(dayint)
        }
        let selected = (selectedDay == btnDate)
        btn.isBordered = !selected
    }
    
    @IBAction func prevWeekClick(_ sender: Any) {
        shownSunday = Calendar.current.date(byAdding: .day, value: -7, to: shownSunday)!
        setDayButtons()
    }
    @IBAction func newWeekClick(_ sender: Any) {
        shownSunday = Calendar.current.date(byAdding: .day, value: 7, to: shownSunday)!
        setDayButtons()
    }
    
    @IBAction func todayClick(_ sender: Any) {
        selectedDay = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month, .day], from: Date()))!
        shownSunday = selectedDay
        setDayButtons()
        self.updateStatus()
    }
    @IBAction func btn0Click(_ sender: Any) {
        setSelectedDay(diff: 0)
    }
    @IBAction func btn1Click(_ sender: Any) {
        setSelectedDay(diff: 1)
    }
    @IBAction func btn2Click(_ sender: Any) {
        setSelectedDay(diff: 2)
    }
    @IBAction func btn3Click(_ sender: Any) {
        setSelectedDay(diff: 3)
    }
    @IBAction func btn4Click(_ sender: Any) {
        setSelectedDay(diff: 4)
    }
    @IBAction func btn5Click(_ sender: Any) {
        setSelectedDay(diff: 5)
    }
    @IBAction func btn6Click(_ sender: Any) {
        setSelectedDay(diff: 6)
    }
    func setSelectedDay(diff: NSInteger) {
        let btnDate = Calendar.current.date(byAdding: .day, value: diff, to: shownSunday)!
        selectedDay = btnDate
        setDayButtons()
        self.updateStatus()
    }
    
    
    func updateStatus() {
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
        
        let events = cal.getEventsByDate(target: selectedDay)
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
    
    @IBAction func buildClicked(_ sender: Any) {
        cal.build(target: selectedDay)
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

