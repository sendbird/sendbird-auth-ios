//
//  Injectable.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/16/25.
//

@_spi(SendbirdInternal) public protocol Injectable {
    func resolve(with dependency: Dependency?)
}
