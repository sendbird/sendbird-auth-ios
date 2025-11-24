//
//  Cacheable.swift
//  SendbirdChat
//
//  Created by Minhyuk Kim on 2021/07/09.
//

import Foundation

public protocol Cacheable {
    func update(with newValue: Self?)
}
