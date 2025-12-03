import Foundation

@propertyWrapper
@_spi(SendbirdInternal) public struct UserDefault<Value> {
    
    private let key: String
    @_spi(SendbirdInternal) public var userDefaults: UserDefaults
    private let queue = DispatchQueue(label: "UserDefault_\(UUID().uuidString)")
    
    @_spi(SendbirdInternal) public init(_ key: String, userDefaults: UserDefaults) {
        self.key = key
        self.userDefaults = userDefaults
    }
    
    @_spi(SendbirdInternal) public var wrappedValue: Value? {
        get {
            queue.sync {
                userDefaults.object(forKey: key) as? Value
            }
        }
        set {
            let keyCopy = key
            let userDefaultsCopy = userDefaults
            
            queue.sync {
                if let newValue = newValue {
                    userDefaultsCopy.setValue(newValue, forKey: keyCopy)
                } else {
                    userDefaultsCopy.removeObject(forKey: keyCopy)
                }
            }
        }
    }
}
