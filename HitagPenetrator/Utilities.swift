//
//  Utilities.swift
//  HitagPenetrator
//
//  Created by Buğra Ekuklu on 3.08.2017.
//  Copyright © 2017 The Digital Warehouse. All rights reserved.
//

import Foundation
import Foundation
import UIKit
import SystemConfiguration



class Utilities{
    
    class func dataFrom(hex: String) -> Data {
        var hex = hex
        var data = Data()
        while(hex.characters.count > 0) {
            let c: String = hex.substring(to: hex.index(hex.startIndex, offsetBy: 2))
            hex = hex.substring(from: hex.index(hex.startIndex, offsetBy: 2))
            var ch: UInt32 = 0
            Scanner(string: c).scanHexInt32(&ch)
            var char = UInt8(ch)
            data.append(&char, count: 1)
        }
        return data
    }
    
    private static let hexRegex = try! NSRegularExpression(pattern: "(?:[0-9a-fA-F]{2}){2,}", options: [] )
    
    private static let CHexLookup : [Character] = [ "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F" ]
    
    public static func checkStringIsHex(hex: String) -> Bool {
        var matches = hexRegex.matches(in: hex, options: [], range: NSRange(location: 0, length: hex.characters.count))
        
        matches = matches.filter { (result) -> Bool in
            return result.range.length == hex.characters.count
        }
        
        return !matches.isEmpty
    }
    
    // Mark: - Public methods
    
    /// Method to convert a byte array into a string containing hex characters, without any
    /// additional formatting.
    public static func byteArrayToHexString(_ byteArray : [UInt8]) -> String {
        
        var stringToReturn = ""
        
        for oneByte in byteArray {
            let asInt = Int(oneByte)
            stringToReturn.append(self.CHexLookup[asInt >> 4])
            stringToReturn.append(self.CHexLookup[asInt & 0x0f])
        }
        return stringToReturn
    }
}
