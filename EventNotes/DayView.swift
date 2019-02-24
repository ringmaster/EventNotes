//
//  CalendarView.swift
//  HdM App
//
//  Created by Daniel Grießhaber on 14.06.17.
//  Copyright © 2017 Daniel Grießhaber. All rights reserved.
//

import Foundation
import AppKit
import EventKit

class CalendarDate {
    public let begin: Date
    public let end: Date
    public let color: NSColor
    public let title: String
    public let place: String
    public let id: String
    
    init(with id: String, from: Date, to: Date, title: String, place: String, color: NSColor) {
        self.begin = from
        self.end = to
        self.title = title
        self.place = place
        self.color = color
        self.id = id
    }
}

protocol DayViewDelegate {
    func dayView(_: DayView, didReceiveClickForDate date: EKEvent)
}

class DayView : NSView {
    
    static let VERTICAL_MARGIN : CGFloat = 10
    static let HOUR_HEIGHT : CGFloat = 60
    static let SCROLL_HEIGHT : CGFloat = 24 * HOUR_HEIGHT + 2 * VERTICAL_MARGIN
    static let LABEL_SIZE = NSSize(width: 45, height: 15)
    static let BACKGROUND_COLOR = NSColor.controlTextColor.withAlphaComponent(0.4)
    static let NOW_LINE_COLOR = NSColor.red
    static let COLORS = [NSColor.red, NSColor.blue, NSColor.orange, NSColor.green, NSColor.magenta]
    
    private var dates: [EKEvent] = []
    public var delegate: DayViewDelegate?
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.frame = NSRect(x: self.frame.minX, y: self.frame.minY, width: self.frame.width, height: DayView.SCROLL_HEIGHT)
    }
    
    func setDates(newDates: [EKEvent]){
        self.dates = newDates.sorted(by: {$0.startDate < $1.startDate})
        self.needsDisplay = true
    }
    
    func scrollToNow(){
        let scrollView = self.superview?.superview as! NSScrollView
        let currentTimeHeight = getPosition(for: Date())
        let center = NSPoint(x: 0, y:currentTimeHeight - scrollView.frame.height / 2)
        scrollView.contentView.scroll(center)
    }
    
    func civilianTime(hour: Int)->Int {
        let newHour = hour % 12
        if newHour == 0 {
            return 12
        }
        return newHour
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        //calculate the current time for the red line
        let now = Date()
        let currentTimeLine = getPosition(for: now)
        let (nowHour, nowMinute) = getTime(for: now)
        
        //get and set up the graphics context
        let context = NSGraphicsContext.current!.cgContext
        
        // draw a label and line for every hour
        for hour in 0...24{
            
            //calculate the position for the current line
            let verticalCenter = DayView.HOUR_HEIGHT * CGFloat(24 - hour) + DayView.VERTICAL_MARGIN
            
            //check if the current time label would interfere with this hour label
            if(abs(verticalCenter - currentTimeLine) > 20){
                let labelText : NSString = NSString(format: "%2d:00", civilianTime(hour: hour))
                drawLabel(in: context, text: labelText, timePosition: verticalCenter, color: DayView.BACKGROUND_COLOR)
            }
            
            drawLine(in: context, timePosition: verticalCenter, color: DayView.BACKGROUND_COLOR)
        }
        
        //draw the dates
        drawDates(in: context, dates: self.dates)
        
        //draw the label for the current time
        let labelText : NSString = NSString(format: "%02d:%02d", civilianTime(hour: nowHour), nowMinute)
        drawLabel(in: context, text: labelText, timePosition: currentTimeLine, color: DayView.NOW_LINE_COLOR)
        
        //draw the line for the current time
        drawLine(in: context, timePosition: currentTimeLine, color: DayView.NOW_LINE_COLOR)
        
    }
    
    func getTime(for date: Date) -> (Int, Int){
        let calendar = Calendar.current
        
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        
        return (hour, minute)
    }
    
    func getPosition(for date: Date) -> CGFloat{
        let (hour, minute) = getTime(for: date)
        
        return
            (DayView.HOUR_HEIGHT * CGFloat(23 - hour)) +
                ((DayView.HOUR_HEIGHT / 60) * CGFloat(60 - minute)) +
                DayView.VERTICAL_MARGIN
    }
    
    func drawLabel(in context: CGContext, text: NSString, timePosition: CGFloat, color: NSColor){
        
        let origin = NSPoint(x: 0, y: timePosition - DayView.LABEL_SIZE.height / 2)
        let rect = NSRect(origin: origin, size: DayView.LABEL_SIZE)
        let textAttributes = [
            NSAttributedStringKey.font : NSFont.controlContentFont(ofSize: 10),
            NSAttributedStringKey.foregroundColor: color
        ]
        
        text.draw(in: rect, withAttributes: textAttributes)
    }
    
    func drawLine(in context: CGContext, timePosition: CGFloat, color: NSColor){
        let labelWidth = DayView.LABEL_SIZE.width
        var startPoint = CGPoint(x: labelWidth, y: timePosition)
        let endPoint = CGPoint(x: self.frame.width, y: timePosition)
        
        if color == DayView.NOW_LINE_COLOR {
            startPoint.x -= 10
        }
        
        context.setLineWidth(0.5)
        context.setStrokeColor(color.cgColor)
        
        //draw a line for every hour
        context.beginPath()
        context.move(to: startPoint)
        context.addLine(to: endPoint)
        context.strokePath()
    }
    
    func checkOverlappingEvents(for event: EKEvent) -> (Int, Int){
        var afterCurrentDate = false
        var overlappingEventsBefore = 0
        var overlappingEventsAfter = 0
        for otherDate in dates {
            if ((event.startDate >= otherDate.startDate && otherDate.endDate > event.startDate)
                || (event.startDate < otherDate.startDate && otherDate.startDate < event.endDate))
                && otherDate !== event && !otherDate.isAllDay {
                // other date overlaps with this date
                if afterCurrentDate {
                    overlappingEventsAfter += 1
                }else{
                    overlappingEventsBefore += 1
                }
            }
            if otherDate === event {
                //now switch the
                afterCurrentDate = true
                continue
            }
        }
        
        return (overlappingEventsBefore, overlappingEventsAfter)
    }
    
    func drawDates(in context: CGContext, dates: [EKEvent]){
        
        for date in dates {
            
            //check if there are multiple dates on this start time
            let (overlappingEventsBefore, overlappingEventsAfter) = checkOverlappingEvents(for: date)
            
            let lineWidth = CGFloat(8)
            let margin = CGFloat(3)
            
            //calculate the width so there is enough space for all overlapping events
            let maxWidth: CGFloat = self.frame.width - DayView.LABEL_SIZE.width
            let eventWidth = maxWidth / CGFloat(overlappingEventsBefore + overlappingEventsAfter + 1)
            
            let startX : CGFloat = DayView.LABEL_SIZE.width + (eventWidth * CGFloat(overlappingEventsBefore))
            let endX : CGFloat = startX + eventWidth
            let startY : CGFloat = getPosition(for: date.startDate)
            let endY : CGFloat = getPosition(for: date.endDate)
            
            
            var rect = NSRect(x: startX, y: startY, width: endX - startX, height: endY - startY + 2)
            
            //print the box to represent the date
            //let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
            var path = CGPath(rect: rect, transform: nil)
            var color = NSColor(red: 0.7843137254901961, green: 0.4745098039215686, blue: 0.8666666666666667, alpha: 1.0)
            // Check for 1:1s
            if let attendees:[EKParticipant] = date.attendees {
                if attendees.count == 1 {
                   color = NSColor(red: 0.3411764705882353, green: 0.7019607843137254, blue: 0.29411764705882354, alpha: 1.0)
                }
            }
            if date.status == .tentative {
                color = NSColor(red: 0.34, green: 0.34, blue: 0.34, alpha: 1.0)
            }
            
            context.setFillColor(color.withAlphaComponent(0.5).cgColor)
            context.beginPath()
            context.addPath(path)
            context.fillPath()
            
            //draw the line on the left side of the box
            context.beginPath()
            context.setFillColor(color.cgColor)
            rect = NSRect(x: startX, y: startY, width: 2, height: endY - startY + 2)
            path = CGPath(rect: rect, transform: nil)
            context.addPath(path)
            context.fillPath()
            /*
            context.move(to: CGPoint(x: startX, y: startY - radius))
            context.addArc(tangent1End: CGPoint(x: startX, y: startY), tangent2End: CGPoint(x: startX + radius, y: startY), radius: radius)
            context.addLine(to: CGPoint(x: startX + lineWidth, y: startY))
            context.addLine(to: CGPoint(x: startX + lineWidth, y: endY))
            context.addLine(to: CGPoint(x: startX + radius, y: endY))
            context.addArc(tangent1End: CGPoint(x: startX, y: endY), tangent2End: CGPoint(x: startX, y: startY - radius), radius: radius)
            context.addLine(to: CGPoint(x: startX, y: startY - radius))
            context.fillPath()
            */
            
            //draw the text information
            let titleOrigin = NSPoint(x: startX + lineWidth + margin, y: endY - margin)
            let textSize = NSSize(width: (endX - startX) - lineWidth, height: startY - endY)
            let titleRect = NSRect(origin: titleOrigin, size: textSize)
            var titleAttributes: [NSAttributedString.Key : Any]? = [
                NSAttributedStringKey.font : NSFont.systemFont(ofSize: 10),
                NSAttributedStringKey.foregroundColor: NSColor.black
            ]
            if let organizer:EKParticipant = date.organizer {
                if organizer.isCurrentUser {
                    titleAttributes = [
                        NSAttributedStringKey.font : NSFont.boldSystemFont(ofSize: 10),
                        NSAttributedStringKey.foregroundColor: NSColor.black
                    ]
                }
            }
            
            //draw the title
            let title = NSString(string: date.title)
            title.draw(in: titleRect, withAttributes: titleAttributes)
            let titleBounds = title.boundingRect(with: textSize, options: .usesLineFragmentOrigin,  attributes: titleAttributes)
            
            //draw the place
            let placeOrigin = NSPoint(x: startX + lineWidth + margin, y: endY - margin - titleBounds.height)
            let placeRect = NSRect(origin: placeOrigin, size: textSize)
            let placeAttributes = [
                NSAttributedStringKey.font : NSFont.controlContentFont(ofSize: 8),
                NSAttributedStringKey.foregroundColor: NSColor.black
            ]
            let place = NSString(string: date.location ?? "")
            place.draw(in: placeRect, withAttributes: placeAttributes)
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        let windowMargin = CGFloat(20)
        let scrollview = self.superview?.superview as! NSScrollView
        let clickY = event.locationInWindow.y + scrollview.contentView.visibleRect.minY - windowMargin
        let clickX = event.locationInWindow.x + scrollview.contentView.visibleRect.minX - windowMargin
        
        for date in dates {
            let startHeight = getPosition(for: date.startDate)
            let endHeight = getPosition(for: date.endDate)
            
            //check if there are multiple dates on this start time
            let (overlappingEventsBefore, overlappingEventsAfter) = checkOverlappingEvents(for: date)
            
            //calculate the width so there is enough space for all overlapping events
            let maxWidth: CGFloat = self.frame.width - DayView.LABEL_SIZE.width
            let eventWidth = maxWidth / CGFloat(overlappingEventsBefore + overlappingEventsAfter + 1)
            
            let startX : CGFloat = DayView.LABEL_SIZE.width + (eventWidth * CGFloat(overlappingEventsBefore))
            let endX : CGFloat = startX + eventWidth
            
            
            //check if click happened inside this date
            if startHeight > clickY && clickY > endHeight && startX < clickX && clickX < endX  {
                self.delegate?.dayView(self, didReceiveClickForDate: date)
            }
        }
    }
}
