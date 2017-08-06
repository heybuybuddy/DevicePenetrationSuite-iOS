//
//  BleFinder.swift
//  HitagPenetrator
//
//  Created by Buğra Ekuklu on 3.08.2017.
//  Copyright © 2017 The Digital Warehouse. All rights reserved.
//

import Foundation
import Foundation
import CoreBluetooth
import UIKit


internal protocol BluetoothConnectionDelegate{
    func connectionComplete(hitagId:String,validateId:Int)
    //func devicePasswordSent(dataSent:Bool,hitagId:String,responseCode:Int)
    //func connectionTimeOut(hitagId:String)
    func disconnectionComplete(hitagId:String)
}

class BleFinder: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, BuyBuddyBLEPeripheralDelegate{
    
    var connectionMode                     : ConnectionMode = ConnectionMode.uart
    var uartConnect                        : BuyBuddyBLEPeripheral?
    var viewDelegate                       : BluetoothConnectionDelegate?
    var centralManager                     : CBCentralManager!
    var currentDevice                      : CBPeripheral!
    var connected                          : Bool = false
    var timeOutCheck                       : Bool = false
    var pending                            : Bool = false
    var hitagsPasswords                    : [String : String] = [:]
    var hitagsTried                        : [String : Int] = [:]
    var currentHitag                       : String!
    var devicesToOpen                      : [String] = []
    var openedDevices                      : [String] = []
    var deviceWithError                    : [String] = []
    var initHitagId                        : String?
    var validationCode                     : Int = 0
    var peripheralConnecting = [CBPeripheral]()
    var counter = 0
    var updateCharDelegate: CharacteristicUpdateDelegate?
    
    override init() {
        
    }
    
    func sendPassword(password: String) -> Bool{
        if connected {
            self.uartConnect?.writeHexString(password)
            return true
        }
        return false
    }
    
    func disconnectFromHitag() -> Bool{
        if connected {
            if currentDevice != nil {
                self.centralManager.cancelPeripheralConnection(self.currentDevice)
                return true
            }
        }
        return false
    }
    
    init(hitagId: String,viewController:BluetoothConnectionDelegate, _ updateCharDelegate: CharacteristicUpdateDelegate? = nil) {
        super.init()
        viewDelegate = viewController
        devicesToOpen.append(hitagId)
        initHitagId = hitagId
        self.updateCharDelegate = updateCharDelegate
    }
    
    func startSearch(connectionMode: ConnectionMode) {
        self.connectionMode = connectionMode
        centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
    }
    
    deinit  {
    }
    
    func connectionFinalized() {
        //print("Servisleri discover ettim, initi invalidate ediyorum ve connection timeout başlatıyorum")
        viewDelegate?.connectionComplete(hitagId: currentHitag, validateId: validationCode)
    }
    
    func uartDidEncounterError(_ error: NSString) {
        
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        
        if #available(iOS 10.0, *) {
            if central.state ==  CBManagerState.poweredOn {
                let options : [String : AnyObject] = NSDictionary(object: NSNumber(value: true as Bool), forKey: CBCentralManagerScanOptionAllowDuplicatesKey as NSCopying) as! [String : AnyObject]
                central.scanForPeripherals(withServices: nil, options: options)
            }
            else {
                //print("Bluetooth switched off or not initialized")
            }
        } else {
            if central.state.rawValue == CBCentralManagerState.poweredOn.rawValue {
                let options : [String : AnyObject] = NSDictionary(object: NSNumber(value: true as Bool), forKey: CBCentralManagerScanOptionAllowDuplicatesKey as NSCopying) as! [String : AnyObject]
                central.scanForPeripherals(withServices: nil, options: options)
            }
            else {
                //print("Bluetooth switched off or not initialized")
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        //viewDelegate?.connectionTimeOut(hitagId: initHitagId!)
        print("Connection fail yedim")
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        //print("Disconnecte düşüyorum")
        viewDelegate?.disconnectionComplete(hitagId: currentHitag)
    }
    
    func didReceiveData(_ newData: Data) {
        print(Utilities.byteArrayToHexString([UInt8](newData)))
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        if let serviceUUIds = advertisementData["kCBAdvDataServiceUUIDs"] as? [AnyObject],
            (serviceUUIds.contains { ($0 as? CBUUID)!.uuidString.contains("0000BABA-6275-7962-7564-647966656565")} && advertisementData["kCBAdvDataManufacturerData"] != nil) {
        
            let manufactererData = advertisementData["kCBAdvDataManufacturerData"] as? Data
            let hitagDataByte = [UInt8](manufactererData!)
            var hitagIdArray: [UInt8] = [UInt8]()
            
            if hitagDataByte.count < 10{
                return
            }
            
            for index in 0..<13 {
                hitagIdArray.append(hitagDataByte[index])
            }
            
            let foundhitag = String(NSString(format:"%02X", Int(hitagIdArray[2]))) +
                String(NSString(format:"%02X", Int(hitagIdArray[3]))) +
                String(NSString(format:"%02X", Int(hitagIdArray[4]))) +
                String(NSString(format:"%02X", Int(hitagIdArray[5]))) +
                String(NSString(format:"%02X", Int(hitagIdArray[6])))
            
            var validationArray: [UInt8] = []
            validationArray.append(hitagDataByte[7])
            validationArray.append(hitagDataByte[8])
            
            if devicesToOpen.contains(foundhitag as String) {
                currentHitag = foundhitag as String
                centralManager.stopScan()
                if let value = UInt16(Utilities.byteArrayToHexString(validationArray), radix: 16) {
                    validationCode = Int(value)
                }else{
                    validationCode = 0
                }
                connectDevice(peripheral)
            }

        }
        
    }
    
    func connectDevice(_ peripheral: CBPeripheral){
        
        if centralManager.isScanning {
            self.centralManager.stopScan()
        }
        self.currentDevice = peripheral
        self.currentDevice.delegate = self
        self.peripheralConnecting.append(peripheral)
        //print("Bağlanacağım")
        pending = true
        self.centralManager.connect(peripheral, options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        //print("Bağlandım")
        connected = true
        pending = false
        uartConnect = BuyBuddyBLEPeripheral(peripheral: self.currentDevice, delegate: self, updateCharDelegate)
        uartConnect?.didConnect(connectionMode)
    }
}
