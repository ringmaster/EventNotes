//
//  EKEventExt.swift
//  EventNotes
//
//  Created by Owen Winkler on 4/13/19.
//  Copyright © 2019 Owen Winkler. All rights reserved.
//

import Foundation
import EventKit
import Mustache

extension EKEvent {
    
    override open var mustacheBox: MustacheBox {
        let durationFormatter = DateComponentsFormatter()
        durationFormatter.allowedUnits = [.year,.month,.weekOfMonth,.day,.hour,.minute,.second]
        durationFormatter.unitsStyle = .abbreviated
        let duration = durationFormatter.string(from: self.startDate, to: self.endDate)!

        var attendeeData:[[String: String?]] = []

        var organizerName = ""
        if let oragnizer = self.organizer {
            organizerName = oragnizer.name ?? ""
        }
        var o3name = ""
        var o3emailname = ""

        if let attendees:[EKParticipant] = self.attendees {
            attendeeData = attendees.map {
                let attendee:EKParticipant = $0
                var result: [String: String] = ["name": attendee.name!]
                let cmmuser = attendee.url.absoluteString.capturedGroups(withRegex: "([^:]+)@covermymeds.com")
                if cmmuser.count > 0 {
                    result["link"] = "https://teamdirectory.covermymeds.com/members/" + cmmuser[0].lowercased()
                }
                result["emailname"] = BBCalendar.shared.attendeeEmailname(attendee: attendee)
                return result
            } as [[String: String?]]

            if(self.organizer!.isCurrentUser) {
                o3name = attendees.first!.name!
                o3emailname = BBCalendar.shared.attendeeEmailname(attendee: attendees.first!)
            }
            else {
                o3name = self.organizer!.name!
                o3emailname = BBCalendar.shared.attendeeEmailname(attendee: self.organizer!)
            }

        }
        
        return Box([
            "title": self.title ?? "",
            "start": self.startDate,
            "end": self.endDate,
            "duration": duration,
            "location": self.location ?? "",
            "id": self.eventIdentifier,
            "notes": self.notes ?? "",
            "attendees": attendeeData,
            "organizer": organizerName,
            "o3name": o3name,
            "o3emailname": o3emailname,
            "is_recurring": self.hasRecurrenceRules
        ])
    }
}
