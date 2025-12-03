//
//  Bucketable.swift
//  SendbirdChat
//
//  Created by Kai Lee on 4/7/25.
//

/// A protocol that defines a type that can be held in a bucket
@_spi(SendbirdInternal) public protocol Bucketable: SBCommand {
    func copy(newId: String) -> Self?
}
