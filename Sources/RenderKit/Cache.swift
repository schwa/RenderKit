import Foundation
import os

#if os(iOS)
import UIKit
#endif

public class Cache <Key, Value> where Key: Hashable & Sendable {

    public let label: String?

    internal var storage = OSAllocatedUnfairLock(initialState: Dictionary<Key, Value>())
//    var task: Task<(), Never>?    
    internal var logger: Logger?
    
    public init(label: String? = nil) {
        self.label = label
//        let q = DispatchQueue.init(label: "test")
//        q.async {
//            let source = DispatchSource.makeMemoryPressureSource(eventMask: .all, queue: nil)
//            source.setEventHandler {
//                let event:DispatchSource.MemoryPressureEvent  = source.mask
//                switch event {
//                case DispatchSource.MemoryPressureEvent.normal:
//                    print("normal")
//                case DispatchSource.MemoryPressureEvent.warning:
//                    print("warning")
//                case DispatchSource.MemoryPressureEvent.critical:
//                    print("critical")
//                default:
//                    break
//                }
//                
//            }
//            source.resume()
//        }
//        
//        #if os(iOS)
//        task = Task { [weak self] in
//            for await _ in await NotificationCenter.default.notifications(named: UIApplication.didReceiveMemoryWarningNotification) {
//                self?.storage.removeAll()
//            }
//        }
//        #endif
    }
    
    public func get(key: Key) -> Value? {
        storage.withLock { storage in
            storage[key]
        }
    }
    
    public func get(key: Key, default: () throws -> Value) rethrows -> Value {
        try storage.withLock { storage in
            if let value = storage[key] {
                return value
            }
            else {
                logger?.info("Cache miss: \(String(describing: key)).")
                let value = try `default`()
                storage[key] = value
                return value
            }
        }
    }
    
    @discardableResult
    public func insert(key: Key, value: Value) -> Value? {
        storage.withLock { storage in
            let old = storage[key]
            storage[key] = value
            return old
        }
    }
    
    @discardableResult
    public func remove(key: Key) -> Value? {
        storage.withLock { storage in
            let old = storage[key]
            storage[key] = nil
            return old
        }
    }
        
    public func contains(key: Key) -> Bool {
        storage.withLock { storage in
            storage[key] != nil
        }
    }
    
    public var allKeys: [Key] {
        storage.withLock { storage in
            Array(storage.keys)
        }
    }
}

// MARK: -

public extension Cache {
    func get(key: Key, default: () async throws -> Value) async rethrows -> Value {
        let value = storage.withLock { storage in
            return storage[key]
        }
        if let value {
            return value
        }
        else {
            // TODO: Potential race condition here if storage[key] chanes while `default` is in flight.
            logger?.info("Cache miss: \(String(describing: key)).")
            let value = try await `default`()
            storage.withLock { storage in
                storage[key] = value
            }
            return value
        }
    }
}

// MARK: -

public extension Cache where Key == String {
    func remove(matching pattern: Regex<String>) throws {
        try storage.withLock { storage in
            for key in storage.keys {
                if try pattern.wholeMatch(in: key) != nil {
                    storage[key] = nil
                }
            }
        }
    }
}

public extension Cache where Value == Any {
    public func get<T>(key: Key, of: T.Type, default: () throws -> T) rethrows -> T {
        try get(key: key, default: `default`) as! T
    }
    
}
