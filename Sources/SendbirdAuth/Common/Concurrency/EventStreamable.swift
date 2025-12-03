//
//  EventStreamable.swift
//  SendbirdChat
//
//  Created by Kai Lee on 9/16/25.
//

import Foundation

@_spi(SendbirdInternal) public protocol EventStreamable<T>: Actor {
    associatedtype T

    /// Provides an `AsyncStream` of events of type `T`.
    ///
    /// - Note: This replaces the old delegate-based `addDelegate`.
    ///
    /// - Warning: Always create a new stream for each subscription.
    ///     Sharing a single stream across multiple consumers will cause
    ///     the awaited events to be divided among them, rather than delivered
    ///     to all consumers.
    func makeStream() async -> AsyncStream<T>
}
