import Foundation

public extension Bundle {
    static var renderKitShadersModule: Bundle {
        let url = Bundle.main.resourceURL!.appending(path: "RenderKit_Shaders.bundle")
        return Bundle(url: url)!
    }
}
