//
//  BBCalendar.swift
//  BearCalBar
//
//  Created by Owen Winkler on 9/2/18.
//  Copyright © 2018 Owen Winkler. All rights reserved.
//

import Foundation
import Cocoa
import EventKit
import Mustache
import CallbackURLKit

struct BearNoteMeta: Codable {
    var creationDate: String
    var title: String
    var modificationDate: String
    var identifier: String
    var pin: String
}

class BBCalendar {
    static let shared = BBCalendar()
    private let store = EKEventStore()
    private var templates: [String: [String: String]] = [:]

    private init() {
        _ = getStore()
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) {_ in
            self.getTemplates()
        }
    }
    
    public func getTemplates() {
        // Register the callbacks to handle Bear returning templates
        CallbackURLKit.register(action: "test") { parameters, success, failure, cancel in
            print("Success?")
            success(nil)
        }
        CallbackURLKit.register(action: "settemplates") { parameters, success, failure, cancel in
            print("Templates supplied")
            print(parameters)
            let decoder = JSONDecoder()
            let notes = try? decoder.decode([BearNoteMeta].self, from: (parameters["notes"]?.data(using: String.Encoding.utf8))!)
            notes?.forEach { note in
                var cback = URLComponents()
                cback.scheme = "eventnotes"
                cback.host = "x-callback-url"
                cback.path = "/settemplate"
                
                var urlComponents = URLComponents()
                urlComponents.scheme = "bear"
                urlComponents.host = "x-callback-url"
                urlComponents.path = "/open-note"
                urlComponents.queryItems = [
                    URLQueryItem(name: "id", value: note.identifier),
                    URLQueryItem(name: "token", value: self.getDefault(prefix: "bearToken")),
                    URLQueryItem(name: "x-success", value: cback.url?.absoluteString),
                ]
                let url = urlComponents.url
                if let url:URL = url, NSWorkspace.shared.open(url){
                    print("Fetched template")
                }
                else {
                    print("Couldn't fetch template!")
                }
            }
            success(nil)
        }
        CallbackURLKit.register(action: "settemplate") { parameters, success, failure, cancel in
            print("Template supplied")
            self.templates[parameters["title"]!] = self.parseTemplateSections(template: parameters["note"]!)
            success(nil)
        }

        // Search for templates in Bear
        var cback = URLComponents()
        cback.scheme = "eventnotes"
        cback.host = "x-callback-url"
        cback.path = "/settemplates"
        
        var urlComponents = URLComponents()
        urlComponents.scheme = "bear"
        urlComponents.host = "x-callback-url"
        urlComponents.path = "/search"
        urlComponents.queryItems = [
            URLQueryItem(name: "tag", value: self.getDefault(prefix: "templatesTag")),
            URLQueryItem(name: "token", value: self.getDefault(prefix: "bearToken")),
            URLQueryItem(name: "x-success", value: cback.url?.absoluteString),
            URLQueryItem(name: "x-error", value: "eh")
        ]
        
        let url = urlComponents.url
        if let url:URL = url, NSWorkspace.shared.open(url){
            print("Searched for templates")
        }
        else {
            print("Couldn't search for templates!")
        }

        
    }
    
    public func parseTemplateSections(template: String) -> [String: String] {
        let matches = template.allCapturedGroups(withRegex: "```(\\w+)$(.+?)```")
        var result = [String: String]()
        for match in matches {
            let tmpl = match[1]
            let range = tmpl.index(tmpl.startIndex, offsetBy: 1) ..< tmpl.index(tmpl.endIndex, offsetBy: -1)
            result[match[0]] = String(tmpl[range])
        }
        return result
    }
    
    public func getStore() -> EKEventStore? {
        if EKEventStore.authorizationStatus(for: .event) != EKAuthorizationStatus.authorized {
            self.store.requestAccess(to: .event, completion: {granted, error in})
            NotificationCenter.default.addObserver(self, selector: #selector(self.updateStore), name: .EKEventStoreChanged, object: self.store)
            return self.store
        } else {
            return self.store
        }
    }
    
    @objc private func updateStore() {
        self.store.refreshSourcesIfNecessary()
    }
    
    func getCalendar(name:String, store:EKEventStore) -> EKCalendar?{
        var calUID:String = "?"
        let cal = store.calendars(for: EKEntityType.event) as [EKCalendar]
        for i in cal {
            if i.title == name {
                calUID = i.calendarIdentifier
            }
        }
        return store.calendar(withIdentifier: calUID)
    }
    
    public func getCalendarList() -> [String] {
        if let store = self.getStore() {
            let cals = store.calendars(for: EKEntityType.event)
            let calnames = cals.map { $0.title }
            return calnames
        }
        else {
            return []
        }
    }
    
    public func addNote(title: String, body: String, tags: [String], show: Bool = false) {
        var urlComponents = URLComponents()
        urlComponents.scheme = "bear"
        urlComponents.host = "x-callback-url"
        urlComponents.path = "/create"
        urlComponents.queryItems = [
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: "text", value: body),
            URLQueryItem(name: "tags", value: tags.joined(separator: ",")),
            URLQueryItem(name: "show_window", value: show ? "yes" : "no"),
            URLQueryItem(name: "open_note", value: show ? "yes" : "no")
        ]
        
        let url = urlComponents.url
        if let url:URL = url, NSWorkspace.shared.open(url){
            print("Opened the browser to " + url.absoluteString)
        }
        else {
            print("Couldn't open: " + urlComponents.url!.absoluteString)
        }
        
    }
    
    public func getEventTitle(event: EKEvent, returnDate: Bool = true) -> String {
        let data = [
            "event": event,
            "year": Calendar.current.component(.year, from: event.startDate),
            "month": Calendar.current.component(.month, from: event.startDate),
            "day": Calendar.current.component(.day, from: event.startDate),
            "weekday": Calendar.current.component(.weekday, from: event.startDate),
            "week": Calendar.current.component(.weekOfYear, from: event.startDate),
            "is_o3": isO3(event: event),
            "is_summary": false,
            "is_recurring": event.hasRecurrenceRules
            ] as [String : Any]
        
        var titletype = "title"
        if !returnDate {
            titletype = "menu"
        }
        
        if let title:String = renderTemplate(data: data, type: titletype) {
            return title.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        }
        else {
            return event.title
        }
    }
    
    public func isO3(event: EKEvent) -> Bool {
        if let attendees:[EKParticipant] = event.attendees {
            if attendees.count == 1 {
                return true
            }
        }
        return false
    }
    
    public func getDefault(prefix: String, postfix: String = "") -> String {
        if let value = UserDefaults.standard.string(forKey: prefix) {
            if value == "" {
                return ""
            }
            else {
                return value + postfix
            }
        }
        else {
            return ""
        }
    }
    
    public func bluejeansRoom(event:EKEvent? = nil)->String? {
        if let current:EKEvent = (event ?? currentEvent()) {
            
            if let location:String = current.location {
            
                let locationRoom = location.capturedGroups(withRegex: "bluejeans.com/(\\d+)")
                if locationRoom.count > 0 {
                    return locationRoom[0]
                }
            }
            let desc = current.notes ?? ""
            let descriptionRoom = desc.capturedGroups(withRegex: "bluejeans.com/(\\d+)")
            if descriptionRoom.count > 0 {
                return descriptionRoom[0]
            }
        }
        return nil
    }
    
    public func currentMeetingNoteName()->String? {
        if let current:EKEvent = currentEvent() {
            return getEventTitle(event: current)
        }
        return nil
    }
    
    public func currentEvent(minutesOffset:NSInteger = 10)->EKEvent? {
        var evts = getEventsByDate(target: Date())
        if(evts.count == 0) {
            return nil
        }
        else {
            evts.sort {
                return $0.startDate < $1.startDate
            }
            
            let now = Calendar.current.date(byAdding: .minute, value: minutesOffset, to: Date())!
            for event:EKEvent in evts {
                if event.startDate! < now && event.endDate > now {
                    return event
                }
            }
            return nil
        }
    }
    
    public func nextEvent()->EKEvent? {
        var evts = getEventsByDate(target: Date())
        evts.sort {
            return $0.startDate < $1.startDate
        }
        let now = Date()
        for event:EKEvent in evts {
            if event.startDate! > now {
                return event
            }
        }
        return nil
    }
    
    public func currentEventTitle()->String {
        var evts = getEventsByDate(target: Date())
        if(evts.count == 0) {
            return "No events today"
        }
        else {
            evts.sort {
                return $0.startDate < $1.startDate
            }
            let dateComponentsFormatter = DateComponentsFormatter()
            dateComponentsFormatter.allowedUnits = [.hour,.minute]
            //dateComponentsFormatter.maximumUnitCount = 2
            dateComponentsFormatter.unitsStyle = .positional
            dateComponentsFormatter.zeroFormattingBehavior = .pad

            var nextup = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
            let now = Date()
            for event:EKEvent in evts {
                if event.startDate! < now && event.endDate > now {
                    nextup = event.endDate
                }
                if event.startDate! > now {
                    if nextup < event.startDate! {
                        return "Break in " + dateComponentsFormatter.string(from: now, to: nextup)! + " then " + getEventTitle(event: event, returnDate: false) + " in " + dateComponentsFormatter.string(from: nextup, to: event.startDate)!
                    }
                    else {
                        return getEventTitle(event: event, returnDate: false) + " in " + dateComponentsFormatter.string(from: now, to: event.startDate)!
                    }
                }
            }
            return "No events left today"
        }
    }
    
    public func callbackCreateEvent(id:String, date:Date) {
        if let store = self.getStore() {
            store.requestAccess(to: .event, completion: {granted, error in})

            let events = getEventsByDate(target: date)
            
            for event:EKEvent in events {
                if event.eventIdentifier == id {
                    noteFromEvent(event: event)
                }
            }
        }
    }
    
    public func upsertNoteFromEvent(event:EKEvent) {
        let title = getEventTitle(event: event)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.formatterBehavior = .behavior10_4
        formatter.dateStyle = DateFormatter.Style.short
        
        var cback = URLComponents()
        cback.scheme = "eventnotes"
        cback.host = "x-callback-url"
        cback.path = "/create"
        cback.queryItems = [
            URLQueryItem(name: "id", value: event.eventIdentifier),
            URLQueryItem(name: "date", value: formatter.string(from: event.startDate))
        ]
    
        var urlComponents = URLComponents()
        urlComponents.scheme = "bear"
        urlComponents.host = "x-callback-url"
        urlComponents.path = "/open-note"
        urlComponents.queryItems = [
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: "show_window", value: "no"),
            URLQueryItem(name: "exclude_trashed", value: "yes"),
            URLQueryItem(name: "x-error", value: cback.url?.absoluteString)
        ]
    
        let url = urlComponents.url
        if let url:URL = url, NSWorkspace.shared.open(url){
            print("Opened the browser to " + url.absoluteString)
        }
        else {
            print("Couldn't open: " + urlComponents.url!.absoluteString)
        }
    }
    
    public func getSummaryTitle(target: Date)-> String {
        let isoFormatter = DateFormatter()
        isoFormatter.dateFormat = "yyyy-MM-dd"

        return "⭐️ Summary - " + isoFormatter.string(from: Calendar.current.startOfDay(for: target))
    }
    
    public func upsertSummary(target:Date) {
        let title = getSummaryTitle(target: target)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.formatterBehavior = .behavior10_4
        formatter.dateStyle = DateFormatter.Style.short
        
        var cback = URLComponents()
        cback.scheme = "eventnotes"
        cback.host = "x-callback-url"
        cback.path = "/summary"
        cback.queryItems = [
            URLQueryItem(name: "date", value: formatter.string(from: target))
        ]
        
        var urlComponents = URLComponents()
        urlComponents.scheme = "bear"
        urlComponents.host = "x-callback-url"
        urlComponents.path = "/open-note"
        urlComponents.queryItems = [
            URLQueryItem(name: "title", value: title),
            URLQueryItem(name: "show_window", value: "no"),
            URLQueryItem(name: "exclude_trashed", value: "yes"),
            URLQueryItem(name: "x-error", value: cback.url?.absoluteString)
        ]
        
        let url = urlComponents.url
        if let url:URL = url, NSWorkspace.shared.open(url){
            print("Opened the browser to " + url.absoluteString)
        }
        else {
            print("Couldn't open: " + urlComponents.url!.absoluteString)
        }
    }
    
    public func summaryFromDate(target:Date) {
        let slashFormatter = DateFormatter()
        slashFormatter.dateFormat = "yyyy/MM/dd"
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mma"
        
        let dateComponentsFormatter = DateComponentsFormatter()
        dateComponentsFormatter.allowedUnits = [.year,.month,.weekOfMonth,.day,.hour,.minute,.second]
        dateComponentsFormatter.unitsStyle = .abbreviated
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        
        formatter.formatterBehavior = .behavior10_4
        formatter.dateStyle = DateFormatter.Style.medium
        formatter.timeStyle = DateFormatter.Style.medium
        
        let isoFormatter = DateFormatter()
        isoFormatter.dateFormat = "yyyy-MM-dd"
        
        var evts = getEventsByDate(target: target)
        
        var dataEvents:[[String:Any]] = [[:]]
        let indexTitle = getSummaryTitle(target: target)
        
        evts.sort {
            return $0.startDate < $1.startDate
        }
        
        for event in evts {
            let evt = [
                "title": getEventTitle(event: event),
                "time": timeFormatter.string(from: event.startDate),
                "duration": dateComponentsFormatter.string(from: event.startDate, to: event.endDate)!,
                "has_attendees": event.hasAttendees
            ] as [String: Any]
            dataEvents.append(evt)
        }
        
        let data = [
            "events": dataEvents,

            "start": target,
            "end": target,

            "year": Calendar.current.component(.year, from: target),
            "month": Calendar.current.component(.month, from: target),
            "day": Calendar.current.component(.day, from: target),
            "weekday": Calendar.current.component(.weekday, from: target),
            "week": Calendar.current.component(.weekOfYear, from: target),
            
            "is_o3": false,
            "is_summary": true,
            "is_recurring": false
        ] as [String: Any]
        
        if let body = renderTemplate(data: data) {
            addNote(title: indexTitle, body: body, tags: ["deleteme"], show: true)
        }
        else {
            alert(message: "Could not render templates", identifier: "addnote")
        }
    }
    
    public func attendeeEmailname(attendee: EKParticipant) -> String {
        let emailuser = attendee.url.absoluteString.capturedGroups(withRegex: "([^:]+)@")
        if emailuser.count > 0 {
            return emailuser[0].lowercased()
        }
        else {
            return attendee.name!
        }
    }
    
    public func noteFromEvent(event:EKEvent) {
        let title = getEventTitle(event: event)
        
        let data = [
            "event": event,
            "year": Calendar.current.component(.year, from: event.startDate),
            "month": Calendar.current.component(.month, from: event.startDate),
            "day": Calendar.current.component(.day, from: event.startDate),
            "weekday": Calendar.current.component(.weekday, from: event.startDate),
            "week": Calendar.current.component(.weekOfYear, from: event.startDate),
            "is_o3": isO3(event: event),
            "is_summary": false,
        ] as [String : Any]

        if let body:String = renderTemplate(data: data) {
            addNote(title: title, body: body, tags: ["deleteme"])
        }
        else {
            alert(message: "Could not render templates", identifier: "addnote")
        }
    }
    
    public func renderTemplate(data: [String: Any], type: String = "body") -> String? {
        let templatemap = self.templates.mapValues { t in
            return t[type] ?? ""
        }
        if self.templates.count == 0 {
            return nil
        }
        
        let isoFormatter = DateFormatter()
        isoFormatter.dateFormat = "yyyy-MM-dd"
        let dateTimeFormatter = DateFormatter()
        dateTimeFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        dateTimeFormatter.formatterBehavior = .behavior10_4
        dateTimeFormatter.dateStyle = DateFormatter.Style.medium
        dateTimeFormatter.timeStyle = DateFormatter.Style.medium
        let slashFormatter = DateFormatter()
        slashFormatter.dateFormat = "yyyy/MM/dd"
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mma"
        let bluejeansFormatter = Filter { (s: String?) in
            return (s ?? "").replace(pattern: "\\b(?:https?://\\S*)?bluejeans.com/([\\w\\/]+)", withTemplate: "[☎️ $1](bjnb://meet/id/$1)")
        }
    
        let templaterepo = TemplateRepository(templates: templatemap)
        templaterepo.configuration.contentType = .text
        do {
            let template = try templaterepo.template(named: "eventnotes")
            template.register(isoFormatter, forKey: "iso_date")
            template.register(dateTimeFormatter, forKey: "datetime_date")
            template.register(slashFormatter, forKey: "slash_date")
            template.register(timeFormatter, forKey: "time_date")
            template.register(bluejeansFormatter, forKey: "bluejeans")
            let body:String = try template.render(data)
            
            return body
        }
        catch let error as MustacheError {
            print(error)
            return "There is an error in your template on line \(error.lineNumber!): \(error.description)  #template_error"
        }
        catch {
            return "There was an unknown error while rendering a template.  #template_error"
        }
    }
    
    public func buildToday() {
        let calendar = Calendar.current
        self.build(target: calendar.startOfDay(for: Date()))
    }
    
    public func buildTomorrow() {
        let calendar = Calendar.current
        let tomorrowComponents = DateComponents(day: 1)
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: tomorrowComponents, to: today)!
        self.build(target: calendar.startOfDay(for: tomorrow))
    }
    
    public func getEventsByDate(target: Date) -> [EKEvent] {
        if let store = self.getStore() {
            let calendar = Calendar.current
            
            let today = calendar.startOfDay(for: target)
            
            let tomorrowComponents = DateComponents(day: 1)
            let tomorrow = calendar.date(byAdding: tomorrowComponents, to: today)!
            
            // Create the predicate from the event store's instance method.
            var predicate: NSPredicate? = nil
            if let cal = self.getCalendar(name: self.getDefault(prefix: "calendarName"), store: store) {
                predicate = store.predicateForEvents(withStart: today, end: tomorrow, calendars: [cal])
                
                // Fetch all events that match the predicate.
                var events: [EKEvent]? = nil
                if let aPredicate = predicate {
                    events = store.events(matching: aPredicate)
                }
                if let evts: [EKEvent] = events {
                    return evts
                }
            }
        }
        return []
    }
    
    public func build(target:Date) {
        var evts = getEventsByDate(target: target)
        
        evts.sort {
            return $0.startDate < $1.startDate
        }
        
        for event in evts {
            print(event.title)
            
            if event.hasAttendees {
                upsertNoteFromEvent(event: event)
            }
        }
        
        upsertSummary(target: target)
    }
    
    public func alert(message: String, identifier: String) {
        
        let notification = NSUserNotification()
        notification.identifier = identifier
        notification.title = "EventNotes Error"
        notification.subtitle = message
        
        // Manually display the notification
        let notificationCenter = NSUserNotificationCenter.default
        notificationCenter.deliver(notification)
    }
    
    
}
