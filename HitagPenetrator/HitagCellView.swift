//
//  HitagCellView.swift
//  HitagPenetrator
//
//  Created by Buğra Ekuklu on 3.08.2017.
//  Copyright © 2017 The Digital Warehouse. All rights reserved.
//

import Foundation
import UIKit
import CoreBluetooth

protocol HitagCellViewClickButtonDelegate {
    func clickedNotify(_ uuid: CBUUID)
    func clickedGetValue(_ uuid: CBUUID)
}

class HitagCellView: UITableViewCell {
    
    var uuid: CBUUID!
    
    @IBOutlet weak var notifyButtonRightMargin: NSLayoutConstraint!
    @IBOutlet weak var notifyButtonWidth: NSLayoutConstraint!
   
    
    var delegate: HitagCellViewClickButtonDelegate?
    @IBOutlet weak var characteristicName: UILabel!
    @IBOutlet weak var characteristicUUID: UILabel!
    @IBOutlet weak var characteristicValue: UILabel!
    @IBOutlet weak var notifyButton: UIButton!
    @IBOutlet weak var getValueButton: UIButton!
    @IBOutlet weak var uploadValueButton: UIButton!
    
    override func awakeFromNib() {
        
    }
    
    @IBAction func didClickSetValue(_ sender: Any) {
        //delegate.clickedSetValue(uuid)
    }
    
    @IBAction func didClickNotify(_ sender: Any) {
        delegate?.clickedNotify(uuid)
    }
    
    @IBAction func didClickGetValue(_ sender: Any) {
        delegate?.clickedGetValue(uuid)
    }
}
