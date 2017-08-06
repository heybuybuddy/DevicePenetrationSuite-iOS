//
//  BleHandler.swift
//  HitagPenetrator
//
//  Created by Buğra Ekuklu on 3.08.2017.
//  Copyright © 2017 The Digital Warehouse. All rights reserved.
//

//
//  BuyBuddyBlePeripheral.swift
//  BuyBuddyKit
//
//  Created by Emir Çiftçioğlu on 11/05/2017.
//
//
import Foundation
import CoreBluetooth


enum ConnectionMode:Int {
    case none
    case pinIO
    case uart
    case info
    case controller
    case dfu
}

protocol BuyBuddyBLEPeripheralDelegate: Any {
    var connectionMode:ConnectionMode { get }
    func didReceiveData(_ newData:Data)
    func connectionFinalized()
    func uartDidEncounterError(_ error:NSString)
}

internal class BuyBuddyBLEPeripheral: NSObject, CBPeripheralDelegate {
    
    var currentPeripheral :CBPeripheral!
    var updateCharDelegate : CharacteristicUpdateDelegate?
    var delegate          :BuyBuddyBLEPeripheralDelegate!
    var uartService       :CBService?
    var rxCharacteristic  :CBCharacteristic?
    var txCharacteristic  :CBCharacteristic?
    var knownServices     :[CBService] = []
    
    //MARK: Utility methods
    
    init(peripheral:CBPeripheral, delegate:BuyBuddyBLEPeripheralDelegate, _ updateCharDelegate: CharacteristicUpdateDelegate? = nil){
        super.init()
        
        self.currentPeripheral = peripheral
        self.currentPeripheral.delegate = self
        self.delegate = delegate
        self.updateCharDelegate = updateCharDelegate
    }
    
    func didConnect(_ withMode:ConnectionMode) {
        //Respond to peripheral connection
        
        if currentPeripheral.services != nil{
            peripheral(currentPeripheral, didDiscoverServices: nil)  //already discovered services, DO NOT re-discover. Just pass along the peripheral.
            return
        }
        
        switch withMode.rawValue {
            
        case ConnectionMode.uart.rawValue,
             ConnectionMode.pinIO.rawValue,
             ConnectionMode.controller.rawValue,
             ConnectionMode.dfu.rawValue:
            currentPeripheral.discoverServices([HitagInfo.serviceBaseUUID()])
            
        case ConnectionMode.info.rawValue:
            currentPeripheral.discoverServices(nil)
            break
        default:
            break
        }
    }
    
    func writeHexString(_ hexString: String) {
        //writeRawData(Utilities.dataFrom(hex: hexString))
    }
    
    func writeString(_ string:NSString){
        
        let data = Data(bytes: UnsafeRawPointer(string.utf8String!), count: string.length)
        
        writeRawData(data)
    }
    
    func writeRawData(_ data:Data) {
        
        //Send data to peripheral
        
        if (txCharacteristic == nil){
            return
        }
        
        var writeType:CBCharacteristicWriteType
        
        if (txCharacteristic!.properties.rawValue & CBCharacteristicProperties.writeWithoutResponse.rawValue) != 0 {
            
            writeType = CBCharacteristicWriteType.withoutResponse
            
        }
            
        else if ((txCharacteristic!.properties.rawValue & CBCharacteristicProperties.write.rawValue) != 0){
            
            writeType = CBCharacteristicWriteType.withResponse
        }
            
        else{
            return
        }
        
        //send data in lengths of <= 20 bytes
        let dataLength = data.count
        let limit = 36
        
        if dataLength <= limit {
            currentPeripheral.writeValue(data, for: txCharacteristic!, type: writeType)
        }
            
        else {
            
            var len = limit
            var loc = 0
            var idx = 0 //for debug
            
            while loc < dataLength {
                
                let rmdr = dataLength - loc
                if rmdr <= len {
                    len = rmdr
                }
                
                let range = NSMakeRange(loc, len)
                var newBytes = [UInt8](repeating: 0, count: len)
                (data as NSData).getBytes(&newBytes, range: range)
                let newData = Data(bytes: UnsafePointer<UInt8>(newBytes), count: len)
                self.currentPeripheral.writeValue(newData, for: self.txCharacteristic!, type: writeType)
                
                loc += len
                idx += 1
            }
        }
    }
    
    //MARK: CBPeripheral Delegate methods
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        if error != nil {
            return
        }
        
        let services = peripheral.services as [CBService]!
        
        for s in services! {
            
            // Service characteristics already discovered
            if (s.characteristics != nil){
                self.peripheral(peripheral, didDiscoverCharacteristicsFor: s, error: nil)    // If characteristics have already been discovered, do not check again
            }
                
                //UART, Pin I/O, or Controller mode
            else if delegate.connectionMode == ConnectionMode.uart ||
                delegate.connectionMode == ConnectionMode.pinIO ||
                delegate.connectionMode == ConnectionMode.controller ||
                delegate.connectionMode == ConnectionMode.dfu {
                if UUIDsAreEqual(s.uuid, secondID: hitagServiceUUID()) {
                    uartService = s
                    peripheral.discoverCharacteristics([passCharacteristicUUID(), rxCharacteristicUUID()], for: uartService!)
                }
            }
                
                // Info mode
            else if delegate.connectionMode == ConnectionMode.info {
                knownServices.append(s)
                peripheral.discoverCharacteristics(nil, for: s)
            }
                
                //DFU / Firmware Updater mode
            else if delegate.connectionMode == ConnectionMode.dfu {
                knownServices.append(s)
                peripheral.discoverCharacteristics(nil, for: s)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        //Respond to finding a new characteristic on service
        
        if error != nil {
            return
        }
        
        // UART mode
        if  delegate.connectionMode == ConnectionMode.uart ||
            delegate.connectionMode == ConnectionMode.pinIO ||
            delegate.connectionMode == ConnectionMode.controller ||
            delegate.connectionMode == ConnectionMode.dfu {
            
            for c in (service.characteristics as [CBCharacteristic]!) {
                
                switch c.uuid {
                case rxCharacteristicUUID():
                    rxCharacteristic = c
                    currentPeripheral.setNotifyValue(true, for: rxCharacteristic!)
                    break
                case passCharacteristicUUID():
                    txCharacteristic = c
                    break
                default:
                    break
                }
            }
            
            if rxCharacteristic != nil && txCharacteristic != nil {
                DispatchQueue.main.async(execute: { () -> Void in
                    self.delegate.connectionFinalized()
                })
            }
        }
            // Info mode
        else if delegate.connectionMode == ConnectionMode.info {
            
            for c in (service.characteristics as [CBCharacteristic]!) {
                
                //Read readable characteristic values
                if (c.properties.rawValue & CBCharacteristicProperties.read.rawValue) != 0 {
                    peripheral.readValue(for: c)
                }
                
                peripheral.discoverDescriptors(for: c)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverDescriptorsFor characteristic: CBCharacteristic, error: Error?) {
        
        if error != nil {
            //            handleError("Error discovering descriptors \(error.debugDescription)")
            //printLog(self, funcName: "didDiscoverDescriptorsForCharacteristic", logString: "\(error.debugDescription)")
            //            return
        }
            
        else {
            if characteristic.descriptors?.count != 0 {
                for d in characteristic.descriptors! {
                    _ = d as CBDescriptor!
                    
                }
            }
        }
        //Check if all characteristics were discovered
        var allCharacteristics:[CBCharacteristic] = []
        for s in knownServices {
            for c in s.characteristics! {
                allCharacteristics.append(c as CBCharacteristic!)
            }
        }
        for idx in 0...(allCharacteristics.count-1) {
            if allCharacteristics[idx] === characteristic {
                //                println("found characteristic index \(idx)")
                //print(allCharacteristics[idx].uuid.uuidString)
                
                if allCharacteristics[idx].properties.contains(.notify) {
                    print(allCharacteristics[idx].uuid.uuidString, " notifyble")
                }else{
                    print(allCharacteristics[idx].uuid.uuidString)
                }
                
                if (idx + 1) == allCharacteristics.count {
                                        //                    println("found last characteristic")
                    if delegate.connectionMode == ConnectionMode.info {
                        delegate.connectionFinalized()
                        updateCharDelegate?.characteristicsDidReceived(characteristics: allCharacteristics)
                    }
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        
        //Respond to value change on peripheral
        
        if error != nil {
            return
        }
        
        if delegate.connectionMode == ConnectionMode.info {
            updateCharDelegate?.characteristicInfoDidReceived(uuid: characteristic.uuid, data: characteristic.value!)
            return
        }
        
        //UART mode
        if delegate.connectionMode == ConnectionMode.uart || delegate.connectionMode == ConnectionMode.pinIO || delegate.connectionMode == ConnectionMode.controller {
            
            if (characteristic == self.rxCharacteristic){
                
                DispatchQueue.main.async(execute: { () -> Void in
                    self.delegate.didReceiveData(characteristic.value!)
                })
                
            }
                //TODO: Finalize for info mode
            else if UUIDsAreEqual(characteristic.uuid, secondID: softwareRevisionStringUUID()) {
                
                DispatchQueue.main.async(execute: { () -> Void in
                    self.delegate.connectionFinalized()
                })
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverIncludedServicesFor service: CBService, error: Error?) {
        
        //Respond to finding a new characteristic on service
        
        if error != nil {
            return
        }
        
        for _ in (service.includedServices as [CBService]!) {
            
        }
    }
    
    func handleError(_ errorString:String) {
        
        DispatchQueue.main.async(execute: { () -> Void in
            self.delegate.uartDidEncounterError(errorString as NSString)
        })
    }
    
    func hitagServiceUUID()->CBUUID{
        
        return CBUUID(string: "0000beef-6275-7962-7564-647966656565")
    }
    
    func passCharacteristicUUID()->CBUUID{
        
        return CBUUID(string: "00007373-6275-7962-7564-647966656565")
    }
    
    func rxCharacteristicUUID()->CBUUID{
        
        return CBUUID(string: "00007478-6275-7962-7564-647966656565")
    }
    
    func UUIDsAreEqual(_ firstID:CBUUID, secondID:CBUUID)->Bool {
        
        if firstID.representativeString() == secondID.representativeString() {
            return true
        }
            
        else {
            return false
        }
    }
    
    func softwareRevisionStringUUID()->CBUUID{
        
        return CBUUID(string: "2A28")
    }
    
    func dfuServiceUUID()->CBUUID{
        
        return CBUUID(string: "00001530-1212-efde-1523-785feabcd123")
    }
    
    func deviceInformationServiceUUID()->CBUUID{
        
        return CBUUID(string: "180A")
    }
}

extension CBUUID {
    
    func representativeString() ->NSString{
        
        let data = self.data
        var byteArray = [UInt8](repeating: 0x0, count: data.count)
        (data as NSData).getBytes(&byteArray, length:data.count)
        let outputString = NSMutableString(capacity: 16)
        
        for value in byteArray {
            
            switch (value){
            case 9:
                outputString.appendFormat("%02x-", value)
                break
            default:
                outputString.appendFormat("%02x", value)
            }
        }
        return outputString
    }
    
    func equalsString(_ toString:String, caseSensitive:Bool, omitDashes:Bool)->Bool {
        
        var aString = toString
        var verdict = false
        var options = NSString.CompareOptions.caseInsensitive
        
        if omitDashes == true {
            aString = toString.replacingOccurrences(of: "-", with: "", options: NSString.CompareOptions.literal, range: nil)
        }
        
        if caseSensitive == true {
            options = NSString.CompareOptions.literal
        }
        
        verdict = aString.compare(self.representativeString() as String, options: options, range: nil, locale: Locale.current) == ComparisonResult.orderedSame
        
        return verdict
    }
}

extension UnicodeScalar {
    var hexNibble:UInt8 {
        let value = self.value
        if 48 <= value && value <= 57 {
            return UInt8(value - 48)
        }
        else if 65 <= value && value <= 70 {
            return UInt8(value - 55)
        }
        else if 97 <= value && value <= 102 {
            return UInt8(value - 87)
        }
        fatalError("\(self) not a legal hex nibble")
    }
}

extension Data {
    init(hex:String) {
        let scalars = hex.unicodeScalars
        var bytes = Array<UInt8>(repeating: 0, count: (scalars.count + 1) >> 1)
        for (index, scalar) in scalars.enumerated() {
            var nibble = scalar.hexNibble
            if index & 1 == 0 {
                nibble <<= 4
            }
            bytes[index >> 1] |= nibble
        }
        self = Data(bytes: bytes)
    }
}
