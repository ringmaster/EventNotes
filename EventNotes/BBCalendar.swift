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

class BBCalendar {
    
    public func getStore() -> EKEventStore? {
        let store = EKEventStore()
        
        if EKEventStore.authorizationStatus(for: .event) != EKAuthorizationStatus.authorized {
            store.requestAccess(to: .event, completion: {granted, error in})
            return nil
        } else {
            return store
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
    
    public func getEventTitle(event: EKEvent) -> String {
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

            title = title + " " + isoFormatter.string(from: event.startDate)
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
            dateComponentsFormatter.allowedUnits = [.year,.month,.weekOfMonth,.day,.hour,.minute,.second]
            //dateComponentsFormatter.maximumUnitCount = 2
            dateComponentsFormatter.unitsStyle = .abbreviated

            
            for event:EKEvent in evts {
                if event.startDate > Date() {
                    return getEventTitle(event: event) + " in " + dateComponentsFormatter.string(from: Date(), to: event.startDate)!
                }
            }
            return "No events left today"
        }
    }
    
    public func noteFromEvent(event:EKEvent)->String {
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
        
        var body:String = "\n---\n> *Subject:* " + event.title
        body += "\n> *Start:* [" + formatter.string(from: event.startDate) + "](x-fantastical2://show/mini/" + isoFormatter.string(from: event.startDate) + ")"
        body += "\n> *End:* " + formatter.string(from: event.endDate)
        body += "\n> *Attendees:* " + String(attendees.count)
        body += "\n> *Organizer:* " + String(event.organizer!.name!)
        if let location:String = event.location {
            body += "\n> *Location:* " + location
        }
        body += "\n> *Index:* [[⭐️ Summary - " + isoFormatter.string(from: event.startDate) + "]]"
        body += "\n> *Event ID:* " + event.eventIdentifier
        if let notes:String = event.notes {
            body += "\n---\n" + notes + "\n---\n"
        }
        body = body.replace(pattern: "https?://\\S*bluejeans.com/(\\S+)", withTemplate: "bjnb://meet/id/$1")
        
        addNote(title: title, body: body, tags: tags)
        
        return title
    }
    
    public func buildToday() {
        let calendar = Calendar.current
        self.build(target: calendar.startOfDay(for: Date()))
    }
    
    public func getEventsByDate(target: Date) -> [EKEvent] {
        let store = EKEventStore()
        
        if EKEventStore.authorizationStatus(for: .event) != EKAuthorizationStatus.authorized {
            store.requestAccess(to: .event, completion: {granted, error in})
        } else {
            
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
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        
        let isoFormatter = DateFormatter()
        isoFormatter.dateFormat = "yyyy-MM-dd"

        let slashFormatter = DateFormatter()
        slashFormatter.dateFormat = "yyyy/MM/dd"
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mma"
        
        let dateComponentsFormatter = DateComponentsFormatter()
        dateComponentsFormatter.allowedUnits = [.year,.month,.weekOfMonth,.day,.hour,.minute,.second]
        //dateComponentsFormatter.maximumUnitCount = 2
        dateComponentsFormatter.unitsStyle = .abbreviated

        var evts = getEventsByDate(target: target)
        
        var index:[String] = []
        let indexTitle = "⭐️ Summary - " + isoFormatter.string(from: Calendar.current.startOfDay(for: target))
                
        evts.sort {
            return $0.startDate < $1.startDate
        }
        
        for event in evts {
            print(event.title)
            
            if event.hasAttendees {
                
                let title = noteFromEvent(event: event)
                
                index.append("* [[" + title + "]] @ " + timeFormatter.string(from: event.startDate) + " for " + dateComponentsFormatter.string(from: event.startDate, to: event.endDate)!)
            }
        }
        
        addNote(title: indexTitle, body: index.joined(separator: "\n"), tags: ["deleteme", self.getDefault(prefix: "dateTagPrefix", postfix: "/") + slashFormatter.string(from: Calendar.current.startOfDay(for: target)), self.getDefault(prefix: "dateTagPrefix", postfix: "/") + "summary"], show: true)
    }
    
    
}
