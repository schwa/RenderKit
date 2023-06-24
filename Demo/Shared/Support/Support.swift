import SwiftUI

extension Binding {
    init<Other>(other: Binding<Other>) where Value: BinaryFloatingPoint, Other: BinaryFloatingPoint {
        self = .init(get: {
            return Value(other.wrappedValue)
        }, set: { newValue in
            other.wrappedValue = Other(newValue)
        })
    }
}


