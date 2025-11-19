//
//  BinaryData.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/19.
//

import Foundation

package class BinaryData: NSObject {
    package init(name: String, filename: String, type: String, data: Data) {
        self.name = name
        self.filename = filename
        self.type = type
        self.data = data
    }
    
    var name: String
    var filename: String
    var type: String
    var data: Data
    
    package var isValid: Bool { data.count > 0 }
}
