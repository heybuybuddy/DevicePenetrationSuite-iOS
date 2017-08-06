//
//  HitagCharacteristics.swift
//  HitagPenetrator
//
//  Created by Buğra Ekuklu on 3.08.2017.
//  Copyright © 2017 The Digital Warehouse. All rights reserved.
//

import Foundation
import CoreBluetooth

enum HitagInfoCharacteristic: String {
    case Password = "0001"
    case Notify = "0002"
    case Battery = "0003"
    case Validation = "0004"
    case DeviceId = "0005"
    case State = "0006"
    case DFU = "0007"
}

class HitagInfo {
    
    static let serviceBaseUUIDstr: String = "0000baba-6275-7962-7564-647966656565"
    
    class func serviceBaseUUID() -> CBUUID {
        return CBUUID(string: serviceBaseUUIDstr)
    }
    
    class func getCharacteristic(characteristic: HitagInfoCharacteristic) -> CBUUID {
        let startIndex = serviceBaseUUIDstr.index(serviceBaseUUIDstr.startIndex, offsetBy: 4);
        let endIndex = serviceBaseUUIDstr.index(serviceBaseUUIDstr.startIndex, offsetBy: 8);
        return CBUUID(string: serviceBaseUUIDstr.replacingCharacters(in: startIndex..<endIndex, with: characteristic.rawValue))
    }
}

protocol CharacteristicUpdateDelegate {
    func characteristicInfoDidReceived(uuid: CBUUID, data: Data)
    func characteristicsDidReceived(characteristics: [CBCharacteristic])
}

class CharacteristicWithInfo {
    var characteristic: CBCharacteristic!
    var currentValue: String = ""
    var initialGet = false
    
    init(_ characteristic: CBCharacteristic) {
        self.characteristic = characteristic
    }
}

