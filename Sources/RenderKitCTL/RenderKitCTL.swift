import RenderKit
import RenderKitDemo
import RenderKitSceneGraph
import RenderKitSupport

@main
struct Main {
    static func main() async throws {

        let device = MTLCreateYoloDevice()
        let model = try RenderModel(device: device)
        print(model)

    }
}
