//
//  CommonSharedData.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/13/25.
//

import Foundation

public class CommonSharedData {
    public private(set) var eKey: String?

    public init(eKey: String?) {
        self.eKey = eKey
    }
    
    public func update(eKey: String?) {
        self.eKey = eKey
    }
}
