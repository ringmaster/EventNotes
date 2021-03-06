//
//  StringExt.swift
//  BearCalBar
//
//  Created by Owen Winkler on 9/2/18.
//  Copyright © 2018 Owen Winkler. All rights reserved.
//

import Foundation


extension String {
    func capturedGroups(withRegex pattern: String) -> [String] {
        var results = [String]()
        
        var regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: pattern, options: [])
        } catch {
            return results
        }
        
        let matches = regex.matches(in: self, options: [], range: NSRange(location:0, length: self.count))
        
        guard let match = matches.first else { return results }
        
        let lastRangeIndex = match.numberOfRanges - 1
        guard lastRangeIndex >= 1 else { return results }
        
        for i in 1...lastRangeIndex {
            let capturedGroupIndex = match.range(at: i)
            let matchedString = (self as NSString).substring(with: capturedGroupIndex)
            results.append(matchedString)
        }
        
        return results
    }
    
    func allCapturedGroups(withRegex pattern: String) -> [[String]] {
        var innerresult = [String]()
        var results = [[String]]()
        
        var regex: NSRegularExpression
        do {
            regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators, .anchorsMatchLines, .caseInsensitive])
        } catch {
            return results
        }
        
        let matches = regex.matches(in: self, options: [], range: NSRange(location:0, length: self.count))
        
        guard matches.first != nil else { return results }
        
        for match in matches {
            innerresult = [String]()

            let lastRangeIndex = match.numberOfRanges - 1
            guard lastRangeIndex >= 1 else { return results }
            
            for i in 1...lastRangeIndex {
                let capturedGroupIndex = match.range(at: i)
                let matchedString = (self as NSString).substring(with: capturedGroupIndex)
                innerresult.append(matchedString)
            }
            results.append(innerresult)
        }
        
        return results
    }
    
    func replace(pattern:String, withTemplate:String) -> String {
        var _text = self
        
        let regex = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        
        _text = regex.stringByReplacingMatches(in: _text, options: [], range: NSMakeRange(0, _text.count), withTemplate: withTemplate)
        
        return _text
    }
    
    var parseJSONString: Any? {
        let data = self.data(using: String.Encoding.utf8, allowLossyConversion: false)
        return try? JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.mutableContainers)
    }
}
