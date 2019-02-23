//
//  AppDelegate.swift
//  EventNotes
//
//  Created by Owen Winkler on 9/3/18.
//  Copyright © 2018 Owen Winkler. All rights reserved.
//

import Cocoa
import CallbackURLKit
import EventKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    let popover = NSPopover()
    var eventMonitor: EventMonitor?
    let cal = BBCalendar()

    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        /*
         let icon = NSImage(named: "statusIcon")
         icon?.isTemplate = true // best for dark mode
         statusItem.image = icon
         */
        
        if let button = statusItem.button {
            button.action = #selector(togglePopover(_:))
        }
        
        popover.contentViewController = CalViewController.freshController()

        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) {_ in
            self.updateStatus()
        }
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) {_ in
            self.updateStatus()
        }
        
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let strongSelf = self, strongSelf.popover.isShown {
                strongSelf.closePopover(sender: event)
            }
        }
        
        let manager = Manager.shared
        manager.callbackURLScheme = Manager.urlSchemes?.first
        manager.registerToURLEvent()

        CallbackURLKit.register(action: "test") { parameters, success, failure, cancel in
            print("Success?")
            success(nil)
        }
        CallbackURLKit.register(action: "create") { parameters, success, failure, cancel in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.formatterBehavior = .behavior10_4
            formatter.dateStyle = DateFormatter.Style.short

            print("CREATING EVENT " + parameters["id"]! + " FROM CALLBACK")
            self.cal.callbackCreateEvent(id: parameters["id"]!, date: formatter.date(from: parameters["date"]!)!)
            success(nil)
        }
        CallbackURLKit.register(action: "today") { parameters, success, failure, cancel in
            self.cal.buildToday()
            success(nil)
        }
        CallbackURLKit.register(action: "tomorrow") { parameters, success, failure, cancel in
            self.cal.buildTomorrow()
            success(nil)
        }
        CallbackURLKit.register(action: "summary") { parameters, success, failure, cancel in
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.formatterBehavior = .behavior10_4
            formatter.dateStyle = DateFormatter.Style.short
            
            print("CREATING SUMMARY " + parameters["date"]! + " FROM CALLBACK")
            self.cal.summaryFromDate(target: formatter.date(from: parameters["date"]!)!)
            success(nil)
        }

    }
    
    func updateStatus() {
        self.statusItem.title = self.cal.currentEventTitle()
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    

    @objc func togglePopover(_ sender: Any?) {
        if popover.isShown {
            closePopover(sender: sender)
        } else {
            showPopover(sender: sender)
        }
    }
    
    func showPopover(sender: Any?) {
        if let button = statusItem.button {
            popover.animates = false
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
            eventMonitor?.start()
        }
    }
    
    func closePopover(sender: Any?) {
        popover.performClose(sender)
        eventMonitor?.stop()
    }
}

