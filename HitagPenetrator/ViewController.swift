//
//  ViewController.swift
//  HitagPenetrator
//
//  Created by Buğra Ekuklu on 3.08.2017.
//  Copyright © 2017 The Digital Warehouse. All rights reserved.
//

import UIKit
import CoreBluetooth

class ViewController: UIViewController, BluetoothConnectionDelegate, UITableViewDelegate, UITableViewDataSource, CharacteristicUpdateDelegate, HitagCellViewClickButtonDelegate {

    var bleFinder: BleFinder!
    var characteristics: [CBUUID : CharacteristicWithInfo] = [:]
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var passwordTextField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        print(HitagInfo.getCharacteristic(characteristic: .DeviceId).uuidString)
        
        bleFinder = BleFinder(hitagId: "0100000001", viewController: self, self)
        bleFinder.startSearch(connectionMode: .info)
        
        self.tableView.rowHeight = UITableViewAutomaticDimension
        self.tableView.estimatedRowHeight = 150
        self.tableView.register(UINib(nibName: "HitagCellView", bundle: nil), forCellReuseIdentifier: "HitagCellView")
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func disconnectionComplete(hitagId: String) {
        print("Disconnected")
    }
    
    func connectionComplete(hitagId: String, validateId: Int) {
        print(hitagId)
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "HitagCellView") as! HitagCellView
        
        var keys: [CBUUID] = Array(self.characteristics.keys)
        let info = self.characteristics[keys[indexPath.row]]!
        
        var cellName = "Unknown Characteristic"
        switch info.characteristic.uuid {
        case HitagInfo.getCharacteristic(characteristic: .Battery):
            cellName = "Hitag Battery -"
        case HitagInfo.getCharacteristic(characteristic: .DeviceId):
            cellName = "Hitag Identifier -"
        case HitagInfo.getCharacteristic(characteristic: .DFU):
            cellName = "DFU Trigger >"
        case HitagInfo.getCharacteristic(characteristic: .Notify):
            cellName = "Notifier <"
        case HitagInfo.getCharacteristic(characteristic: .Password):
            cellName = "Password >"
        case HitagInfo.getCharacteristic(characteristic: .State):
            cellName = "State >"
        case HitagInfo.getCharacteristic(characteristic: .Validation):
            cellName = "Validation -"
        default:
            cellName = "Unknown Characteristic"
        }
        
        cell.characteristicName.text = cellName
        cell.characteristicUUID.text = "UUID : " + info.characteristic.uuid.uuidString
        
        cell.uuid = info.characteristic.uuid
        cell.delegate = self

        if info.characteristic.properties.contains(.notify) {
            bleFinder.currentDevice.setNotifyValue(true, for: info.characteristic)
            
            cell.notifyButton.isHidden = false
            cell.notifyButtonRightMargin.constant = 7
            cell.notifyButtonWidth.constant = 29
        }else {
            cell.notifyButtonRightMargin.constant = -5
            cell.notifyButtonWidth.constant = 0
            cell.notifyButton.isHidden = true
        }
        
        if info.characteristic.properties.contains(.read) {
            if !info.initialGet {
                self.characteristics[keys[indexPath.row]]!.initialGet = true
                self.bleFinder.currentDevice.readValue(for: info.characteristic)
            }
            
            cell.getValueButton.isHidden = false
        }else {
            cell.getValueButton.isHidden = true
        }
        
        if info.characteristic.properties.contains(.write) {
            cell.uploadValueButton.isHidden = false
        }else {
            cell.uploadValueButton.isHidden = true
        }
        
        if !info.currentValue.isEmpty {
            cell.characteristicValue.text = "Value : " + info.currentValue
        }else {
            cell.characteristicValue.text = "n/a"
        }
        
        return cell
    }
    
    func characteristicInfoDidReceived(uuid: CBUUID, data: Data) {
        if self.characteristics[uuid] != nil {
            self.characteristics[uuid]!.currentValue = Utilities.byteArrayToHexString([UInt8](data))
            //print(self.characteristics[uuid]!.currentValue)
            print([UInt8](data))
            
            print(Utilities.byteArrayToHexString([UInt8](data)))
        }
        
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    func characteristicsDidReceived(characteristics: [CBCharacteristic]) {
        for char in characteristics {
            self.characteristics.updateValue(CharacteristicWithInfo(char), forKey: char.uuid)
        }
        
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return characteristics.keys.count
    }
    
    func clickedNotify(_ uuid: CBUUID) {
        
    }
    
    func clickedGetValue(_ uuid: CBUUID) {
        self.bleFinder.currentDevice.readValue(for: self.characteristics[uuid]!.characteristic)
    }
    
    @IBAction func passButtonClicked(_ sender: Any) {
        sendPasswordToHitag(password: "049c60ec7845e614a4022325aa0b100b68049c60ec7845e614a4022325aa0b100b0b2a")
    }
    
    func sendPasswordToHitag(password: String) {
        
        if (password.characters.count != 70) || !Utilities.checkStringIsHex(hex: password){
            return
        }
            
        let indexFirstSection = password.index(password.startIndex, offsetBy: 38)
        let firstSection = password.substring(to: indexFirstSection)
        let indexSecondSection = password.index(password.startIndex, offsetBy: 38)
        let secondSection = password.substring(from: indexSecondSection)
        let data1 = Utilities.dataFrom(hex: "01" + firstSection)
        let data2 = Utilities.dataFrom(hex: "02" + secondSection)
        
        if self.bleFinder.currentDevice == nil {
            print("CURRENT HITAG IS NULL")
            return
        }
        
        self.bleFinder.currentDevice.writeValue(data1,
                                                for: self.characteristics[HitagInfo.getCharacteristic(characteristic: .Password)]!.characteristic,
                                                type: .withResponse)
        
        self.bleFinder.currentDevice.writeValue(data2,
                                                for: self.characteristics[HitagInfo.getCharacteristic(characteristic: .Password)]!.characteristic,
                                                type: .withResponse)
        
        
    }


}

