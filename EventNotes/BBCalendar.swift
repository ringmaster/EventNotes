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

class BBCalendar {
    private let store = EKEventStore()

    public func getStore() -> EKEventStore? {
        if EKEventStore.authorizationStatus(for: .event) != EKAuthorizationStatus.authorized {
            self.store.requestAccess(to: .event, completion: {granted, error in})
            return self.store
        } else {
            return self.store
        }
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
        var title = event.title!
        
        let isoFormatter = DateFormatter()
        isoFormatter.dateFormat = "yyyy-MM-dd"
        
        if event.hasRecurrenceRules {
            if let attendees:[EKParticipant] = event.attendees {
                if attendees.count == 1 {
                    var o3name = ""
                    if(event.organizer!.isCurrentUser) {
                        o3name = attendees.first!.name!
                    }
                    else {
                        o3name = event.organizer!.name!
                    }
                    title = "O3: " + o3name
                }
            }

            if returnDate {
                title = title + " " + isoFormatter.string(from: event.startDate)
            }
        }
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return title
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
    
    public func getEventTags(event: EKEvent) -> [String] {
        let slashFormatter = DateFormatter()
        slashFormatter.dateFormat = "yyyy/MM/dd"
        let attendees = event.attendees!
        
        var tags = ["deleteme", self.getDefault(prefix: "dateTagPrefix", postfix: "/") + slashFormatter.string(from: event.startDate)]
        
        if attendees.count == 1 {
            var o3name = ""
            if(event.organizer!.isCurrentUser) {
                o3name = attendees.first!.name!
            }
            else {
                o3name = event.organizer!.name!
            }
            
            let result = o3name.capturedGroups(withRegex: "^(\\S)\\S+\\s(.+)$")
            
            if(result.count>=2) {
                tags.append(self.getDefault(prefix: "o3TagPrefix", postfix: "/") + result[0].lowercased() + result[1].lowercased())
            }
            else {
                tags.append(self.getDefault(prefix: "o3TagPrefix", postfix: "/") + o3name)
            }
        }
        
        return tags
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
        
        var evts = getEventsByDate(target: target)
        
        var index:[String] = []
        let indexTitle = getSummaryTitle(target: target)
        
        evts.sort {
            return $0.startDate < $1.startDate
        }
        
        for event in evts {
            if event.hasAttendees {
                index.append("* [[" + getEventTitle(event: event) + "]] @ " + timeFormatter.string(from: event.startDate) + " for " + dateComponentsFormatter.string(from: event.startDate, to: event.endDate)!)
            }
        }
        
        var body = "### Schedule\n"
        body += index.joined(separator: "\n")
        body += "\n---\n"
        
        addNote(title: indexTitle, body: body, tags: ["deleteme", self.getDefault(prefix: "dateTagPrefix", postfix: "/") + slashFormatter.string(from: Calendar.current.startOfDay(for: target)), self.getDefault(prefix: "dateTagPrefix", postfix: "/") + "summary"], show: true)
    }
    
    public func noteFromEvent(event:EKEvent) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        
        formatter.formatterBehavior = .behavior10_4
        formatter.dateStyle = DateFormatter.Style.medium
        formatter.timeStyle = DateFormatter.Style.medium
        
        let isoFormatter = DateFormatter()
        isoFormatter.dateFormat = "yyyy-MM-dd"
        
        let attendees = event.attendees!
        let title = getEventTitle(event: event)
        let tags = getEventTags(event: event)
        
        var templateText = "\n---\n> *Subject:* {{title}}"
        templateText += "\n> *Start:* [{{start}}](x-fantastical2://show/mini/{{startiso}})"
        templateText += "\n> *End:* {{end}}"
        //templateText += "\n> *Attendees:* {{attendeecount}}"
        templateText += "{{#location}}\n> *Location:* {{location}}{{/location}}"
        templateText += "\n> *Index:* [[⭐️ Summary - {{startiso}}]]"
        templateText += "\n> *Organizer:* {{organizer}}"
        templateText += "\n> *Attendees:* {{attendeecount}}\n{{#attendees}}{{#link}}  [{{name}}]({{link}}){{/link}}{{^link}}  {{name}}{{/link}}{{/attendees}}"
        templateText += "\n> *Event ID:* {{eventid}}"
        templateText += "\n---\n{{notes}}\n---\n"
        
        do {
            let template = try Template(string: templateText)
            
            let attendeeData = attendees.map {
                let attendee:EKParticipant = $0
                var link:String? = nil
                let email = attendee.url.absoluteString
                let cmmuser = email.capturedGroups(withRegex: "([^:]+)@covermymeds.com")
                if cmmuser.count > 0 {
                    link = "https://teamdirectory.covermymeds.com/members/" + cmmuser[0].lowercased()
                }
                return ["name": attendee.name, "link": link]
            } as [[String: String?]]

            let data = [
                "event": event,
                "title": event.title,
                "start": formatter.string(from: event.startDate),
                "startiso": isoFormatter.string(from: event.startDate),
                "end": formatter.string(from: event.endDate),
                "attendeecount": attendees.count,
                "attendees": attendeeData,
                "organizer": String(event.organizer!.name!),
                "location": event.location ?? "",
                "eventid": event.eventIdentifier,
                "notes": event.notes ?? ""
                ] as [String : Any]

            var body:String = try template.render(data)
            body = body.replace(pattern: "https?://\\S*bluejeans.com/(\\S+)", withTemplate: "bjnb://meet/id/$1")
            
            addNote(title: title, body: body, tags: tags)
        }
        catch {
            
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
    
    
}
