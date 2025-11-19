//
//  WSEventDeduplicator.swift
//  SendbirdChat
//
//  Created by Celine Moon on 4/25/25.
//

import Foundation

/// A manager that manages WS event deduplication.
/// - Since: 4.27.0
actor WSEventDeduplicator {
    /// Deduplication rules that are used to decide whether to ignore a WS event or not.
    /// Add a dedup rule via `register(deduplicationRules:)`.
    /// Once a dedup rule is used to ignore a WS event, it must be flushed via `unregister(uniqueId:)`.
    private var deduplicationRules: [WSEventDeduplicationRule] = []
    
    func register(deduplicationRules: [WSEventDeduplicationRule]) {
        Logger.main.debug("Register WSEventDeduplicationRules: \(deduplicationRules)")
        self.deduplicationRules.append(contentsOf: deduplicationRules)
    }
    
    func unregister(dedupRule: WSEventDeduplicationRule) {
        Logger.client.verbose("Unregister WSEventDeduplicationRule \(dedupRule)")// with uniqueId=\(uniqueId)")
        
        self.deduplicationRules.removeAll { rule in
            return rule.managerType == dedupRule.managerType
            && rule.eventType == dedupRule.eventType
            && rule.uniqueId == dedupRule.uniqueId
        }
    }
    
    /// Determines whether to ignore a WS event for target EventDelegate or not, and then unregisters the rule.
    /// Returns `true` if the following conditionars are all true for any one of the `deduplicationRules`:
    /// - delegate type == deduplicationRule.managerType
    /// - event type  == deduplicationRule.eventType
    /// - event.uniqueId == deduplicationRule.uniqueId
    func shouldIgnore(event: Command, for delegate: EventDelegate) -> Bool {
        guard let sbCommand = event as? SBCommand else {
            return false
        }
        
        guard let commandUniqueId = sbCommand.uniqueId else {
            return false
        }
        
        let matchedRule = self.deduplicationRules.first { rule in
            let matched = rule.managerType == type(of: delegate)
                            && rule.eventType == sbCommand.cmd
                            && rule.uniqueId == commandUniqueId
            if matched {
                Logger.client.verbose("Ignoring \(sbCommand) (uniqueId=\(commandUniqueId))")
            }
            return matched
        }
        
        if let matchedRule {
            self.unregister(dedupRule: matchedRule)
            return true
        }
        
        return false
    }
}
