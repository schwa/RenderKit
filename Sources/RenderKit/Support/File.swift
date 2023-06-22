import Everything
import Foundation

extension Bundle {
    static let renderKitShaders: Bundle = {
        let url = Bundle.main.resourceURL!.appendingPathComponent("RenderKitClassic_RenderKitShaders.bundle")
        return Bundle(url: url)!
    }()
}

