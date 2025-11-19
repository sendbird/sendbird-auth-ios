//
//  CommonSharedData.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/13/25.
//

import Foundation

package class CommonSharedData {
    package private(set) var eKey: String?

    package init(eKey: String?) {
        self.eKey = eKey
    }
    
    package func update(eKey: String?) {
        self.eKey = eKey
    }
}
