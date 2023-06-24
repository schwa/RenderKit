import SwiftUI

struct NumberFieldOptions {
    enum Container {
        // swiftlint:disable:next discouraged_none_name
        case none
        case verticalGrid
        case horizontalGrid
    }

    var container: Container?
    // swiftlint:disable:next discouraged_optional_boolean
    var emitLabels: Bool?

//    var format: ParseableFormatStyle
}

struct NumberFieldOptionsKey: EnvironmentKey {
    static var defaultValue = NumberFieldOptions()
}

extension EnvironmentValues {
    var numberFieldOptions: NumberFieldOptions {
        get {
            self[NumberFieldOptionsKey.self]
        }
        set {
            self[NumberFieldOptionsKey.self] = newValue
        }
    }
}

struct NumberFieldOptionsModifier: ViewModifier {
    let value: NumberFieldOptions
    func body(content: Content) -> some View {
        content.environment(\.numberFieldOptions, value)
    }
}

extension View {
    func numberFieldOptions(value: NumberFieldOptions) -> some View {
        modifier(NumberFieldOptionsModifier(value: value))
    }
}
