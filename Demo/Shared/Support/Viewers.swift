import simd
import SwiftUI

struct MatrixViewerView: View {
    let value: simd_float4x4

    var body: some View {
        let items = Array(repeating: GridItem(.flexible(minimum: 0, maximum: 100)), count: 4)
        LazyVGrid(columns: items) {
            ForEach(0 ..< 4) { col in
                ForEach(0 ..< 4) { row in
                    Text(value[col, row], format: FloatingPointFormatStyle()).fixedSize()
                }
            }
        }
        .monospacedDigit()
    }
}
