import Everything
import RenderKit
import simd
import SIMDSupport
import SwiftUI
import RenderKitSupport

struct ScalarEditorView: View {
    let label: String

    @Binding
    var value: Float

    @Environment(\.scalarFormat)
    var format

    @Environment(\.readOnlyEditorKey)
    var readOnly

    init(_ label: String, value: Binding<Float>) {
        _value = value
        self.label = label
    }

    var body: some View {
        let format = format ?? .init()
        if readOnly ?? false {
            Text(value, format: format)
                .monospacedDigit()
                .lineLimit(1)
        }
        else {
            TextField(label, value: $value, format: format)
                .monospacedDigit()
        }
    }
}

struct AngleEditorView: View {
    let label: String

    @Binding
    var angle: SIMDSupport.Angle<Float>

    init(_ label: String, value: Binding<SIMDSupport.Angle<Float>>) {
        self.label = label
        _angle = value
    }

    var body: some View {
        ScalarEditorView(label, value: $angle.degrees)
    }
}

// MARK: -

struct TransformEditorView: View {
    @Binding
    var value: Transform

    enum Mode {
        case matrix
        case srt
    }

    @State
    var mode: Mode

    init(_ value: Binding<Transform>) {
        _value = value
        switch value.wrappedValue.storage {
        case .matrix:
            mode = .matrix
        case .srt:
            mode = .srt
        }
    }

    init(_ value: Transform) {
        _value = .constant(value)
        switch value.storage {
        case .matrix:
            mode = .matrix
        case .srt:
            mode = .srt
        }
    }

    var body: some View {
        switch mode {
        case .matrix:
            MatrixEditorView($value.converting(converter: TransformMatrixFormConverter()))
        case .srt:
            SRTEditorView(value: $value.srt).controlSize(.small)
        }
        Picker("Mode", selection: $mode) {
            Text("Matrix").tag(Mode.matrix)
            Text("SRT").tag(Mode.srt)
        }
        .controlSize(.mini)
        .fixedSize()
    }
}

// MARK: -

struct TransformMatrixFormConverter: Converter {
    let convert = { (value: Transform) in
        value.matrix
    }

    let reverse = { (value: simd_float4x4) in
        Transform(value)
    }
}

// MARK: -

struct MatrixEditorView: View {
    @Binding
    private var value: simd_float4x4

    init(_ value: Binding<simd_float4x4>) {
        _value = value
    }

    init(_ value: simd_float4x4) {
        _value = .constant(value)
    }

    var body: some View {
        let items = Array(repeating: GridItem(.flexible(minimum: 0, maximum: 100), alignment: .trailing), count: 4)
        LazyVGrid(columns: items) {
            ForEach(0 ..< 4) { row in
                ForEach(0 ..< 4) { col in
                    ScalarEditorView("", value: $value[col, row])
                }
            }
        }
    }
}

// MARK: -

struct SRTEditorView: View {
    @Binding
    var value: SRT

    var body: some View {
        GroupBox("Translation") {
            VectorEditorView($value.translation)
        }
        GroupBox("Rotation") {
            RotationEditorView(value: $value.rotation)
        }
        GroupBox("Scale") {
            VectorEditorView($value.scale)
        }
    }
}

// MARK: -

struct RotationEditorView: View {
    enum Mode {
        case quaternion
        case axisAngle
        //        case eulerXYZ
        //        case eulerXZY
        //        case eulerYXZ
        //        case eulerYZX
        //        case eulerZXY
        //        case eulerZYX
    }

    @Binding
    var value: simd_quatf

    @State
    var mode = Mode.quaternion

    var body: some View {
        switch mode {
        case .quaternion:
            QuaternionEditorView(value: $value)
        case .axisAngle:
            let axis = Binding {
                value.axis
            } set: {
                value = simd_quatf(angle: value.angle, axis: $0)
            }
            let angle = Binding {
                SIMDSupport.Angle<Float>(radians: value.angle)
            } set: {
                value = simd_quatf(angle: $0.radians, axis: value.axis)
            }
            AxisAngleEditorView(axis: axis, angle: angle)
        }
        Picker("Mode", selection: $mode) {
            Text("quaternion").tag(Mode.quaternion)
            Text("axisAngle").tag(Mode.axisAngle)
        }
        .controlSize(.mini)
        .fixedSize()
    }
}

// MARK: -

struct QuaternionEditorView: View {
    @Binding
    var value: simd_quatf

    var body: some View {
        let items = Array(repeating: GridItem(.flexible(minimum: 0, maximum: 100)), count: 4)
        LazyVGrid(columns: items, alignment: .leading) {
            ScalarEditorView("ix", value: $value.vector.x)
            ScalarEditorView("iy", value: $value.vector.y)
            ScalarEditorView("iz", value: $value.vector.z)
            ScalarEditorView("r", value: $value.vector.w)
        }
    }
}

// MARK: -

struct AxisAngleEditorView: View {
    @Binding
    var axis: SIMD3<Float>

    @Binding
    var angle: SIMDSupport.Angle<Float>

    var body: some View {
        let items = Array(repeating: GridItem(.flexible(minimum: 0, maximum: 100)), count: 4)
        LazyVGrid(columns: items, alignment: .leading) {
            ScalarEditorView("x", value: $axis.x)
            ScalarEditorView("y", value: $axis.x)
            ScalarEditorView("z", value: $axis.x)
            AngleEditorView("angle", value: $angle)
        }
    }
}

// MARK: -

struct VectorEditorView: View {
    struct Options {
        var count: Int
        var labels: [String]
        // swiftlint:disable:next discouraged_optional_boolean
        var readOnly: Bool?
        var embed: Bool
        var emitLabels: Bool

        // swiftlint:disable:next discouraged_optional_boolean
        init(count: Int = 4, labels: [String] = ["X", "Y", "Z", "W"], readOnly: Bool? = false, embed: Bool = true, emitLabels: Bool = false) {
            self.count = count
            self.labels = labels
            self.readOnly = readOnly
            self.embed = embed
            self.emitLabels = emitLabels
        }
    }

    @Binding
    private var value: SIMD4<Float>

    private var options: Options

    init(_ value: Binding<SIMD4<Float>>, options: Options = Options()) {
        assert(options.count <= value.wrappedValue.scalarCount)
        _value = value
        self.options = options
    }

    var body: some View {
        if options.embed {
            let items = Array(repeating: GridItem(.flexible(minimum: 0, maximum: 100), alignment: .trailing), count: options.count)
            LazyVGrid(columns: items, alignment: .leading) {
                ForEach(0 ..< options.count, id: \.self) { index in
                    editor(label: options.labels[index], value: $value[index])
                }
            }
        }
        else {
            ForEach(0 ..< options.count, id: \.self) { index in
                editor(label: options.labels[index], value: $value[index])
            }
        }
    }

    @ViewBuilder
    private func editor(label: String, value: Binding<Float>) -> some View {
        if options.emitLabels {
            Text(label)
        }
        if let readOnly = options.readOnly {
            ScalarEditorView(label, value: value).readOnlyEditor(readOnly)
        }
        else {
            ScalarEditorView(label, value: value)
        }
    }
}

extension VectorEditorView {
    init(_ value: SIMD4<Float>, options: Options = Options()) {
        self = VectorEditorView(.constant(value), options: options)
    }

    init(_ value: Binding<SIMD3<Float>>, options: Options = Options()) {
        let binding = Binding<SIMD4<Float>> {
            SIMD4<Float>(value.wrappedValue, 0)
        } set: {
            value.wrappedValue = $0.xyz
        }
        var options = options
        options.count = 3
        self = VectorEditorView(binding, options: options)
    }

    init(_ value: SIMD3<Float>, options: Options = Options()) {
        var options = options
        options.count = 3
        self = VectorEditorView(.constant(value), options: options)
    }
}

// MARK: -

// NOTE: Rename editable?

struct ReadOnlyEditorKey: EnvironmentKey {
    // swiftlint:disable:next discouraged_optional_boolean
    static var defaultValue: Bool?
}

extension EnvironmentValues {
    // swiftlint:disable:next discouraged_optional_boolean
    var readOnlyEditorKey: Bool? {
        get {
            self[ReadOnlyEditorKey.self]
        }
        set {
            self[ReadOnlyEditorKey.self] = newValue
        }
    }
}

struct ReadOnlyEditorModifier: ViewModifier {
    // swiftlint:disable:next discouraged_optional_boolean
    let value: Bool?
    func body(content: Content) -> some View {
        content.environment(\.readOnlyEditorKey, value)
    }
}

extension View {
    // swiftlint:disable:next discouraged_optional_boolean
    func readOnlyEditor(_ value: Bool?) -> some View {
        modifier(ReadOnlyEditorModifier(value: value))
    }
}

// MARK: -

struct ScalarFormatKey: EnvironmentKey {
    static var defaultValue: FloatingPointFormatStyle<Float>?
}

extension EnvironmentValues {
    var scalarFormat: FloatingPointFormatStyle<Float>? {
        get {
            self[ScalarFormatKey.self]
        }
        set {
            self[ScalarFormatKey.self] = newValue
        }
    }
}

struct ScalarFormatModifier: ViewModifier {
    let value: FloatingPointFormatStyle<Float>?
    func body(content: Content) -> some View {
        content.environment(\.scalarFormat, value)
    }
}

extension View {
    func scalarFormat(_ value: FloatingPointFormatStyle<Float>) -> some View {
        modifier(ScalarFormatModifier(value: value))
    }
}
