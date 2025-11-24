//
//  Injectable.swift
//  SendbirdChat
//
//  Created by Kai Lee on 6/16/25.
//

public protocol Injectable {
    func resolve(with dependency: Dependency?)
}
