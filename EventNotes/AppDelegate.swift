//
//  AppDelegate.swift
//  EventNotes
//
//  Created by Owen Winkler on 9/3/18.
//  Copyright © 2018 Owen Winkler. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    
    let popover = NSPopover()
    
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        /*
         let icon = NSImage(named: "statusIcon")
         icon?.isTemplate = true // best for dark mode
         statusItem.image = icon
         */
        let cal = BBCalendar()
        self.statusItem.title = cal.currentEventTitle()
        
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) {_ in
            self.statusItem.title = cal.currentEventTitle()
        }
        
        if let button = statusItem.button {
            button.action = #selector(togglePopover(_:))
        }
        
        popover.contentViewController = CalViewController.freshController()
        
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
        }
    }
    
    func closePopover(sender: Any?) {
        popover.performClose(sender)
    }
    
    @IBAction func buildClicked(_ sender: NSMenuItem) {
        let cal = BBCalendar()
        cal.buildToday()
    }
    
    @IBAction func quitClicked(sender: NSMenuItem) {
        NSApplication.shared.terminate(self)
    }
}

