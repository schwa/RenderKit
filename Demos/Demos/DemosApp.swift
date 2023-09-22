import SwiftUI
#if os(visionOS)
import CompositorServices
import RenderKitImmersive
#endif

@main
struct DemosApp: App {
    var body: some Scene {
        #if !os(visionOS)
        WindowGroup {
            ContentView()
        }
        #else
        WindowGroup {
            ContentView()
        }.windowStyle(.volumetric)
        ImmersiveSpace(id: "ImmersiveSpace") {
                    CompositorLayer(configuration: ContentStageConfiguration()) { layerRenderer in
                        let renderer = Renderer(layerRenderer)
                        renderer.startRenderLoop()
                    }
                }.immersionStyle(selection: .constant(.full), in: .full)
        #endif
        
        #if os(macOS)
        Settings {
            Form {
                ForEach(FileManager.SearchPathDirectory.allCases, id: \.self) { searchPathDirectory in
                    if let url = try? FileManager().url(for: searchPathDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
                        Button("\(searchPathDirectory.description)") {
                            NSWorkspace.shared.open(url)
                        }
                        .buttonStyle(.link)
                        .help("Opens \(url.absoluteString)")
                    }
                    else {
                        Text("No url for \(searchPathDirectory.description)")
                    }
                }
            }
            .frame(minWidth: 640, minHeight: 480)
        }
        #endif
    }
}

#if os(macOS)
extension FileManager.SearchPathDirectory: CaseIterable {
    public static var allCases: [FileManager.SearchPathDirectory] {
        return [
            .applicationDirectory,
            .demoApplicationDirectory,
            .developerApplicationDirectory,
            .adminApplicationDirectory,
            .libraryDirectory,
            .developerDirectory,
            .userDirectory,
            .documentationDirectory,
            .documentDirectory,
            .coreServiceDirectory,
            .autosavedInformationDirectory,
            .desktopDirectory,
            .cachesDirectory,
            .applicationSupportDirectory,
            .downloadsDirectory,
            .inputMethodsDirectory,
            .moviesDirectory,
            .musicDirectory,
            .picturesDirectory,
            .printerDescriptionDirectory,
            .sharedPublicDirectory,
            .preferencePanesDirectory,
            .applicationScriptsDirectory,
            .itemReplacementDirectory,
            .allApplicationsDirectory,
            .allLibrariesDirectory,
            .trashDirectory,
        ]
    }
}

extension FileManager.SearchPathDirectory: CustomStringConvertible {
    public var description: String {
        switch self {
        case .applicationDirectory: return "applicationDirectory"
        case .demoApplicationDirectory: return "demoApplicationDirectory"
        case .developerApplicationDirectory: return "developerApplicationDirectory"
        case .adminApplicationDirectory: return "adminApplicationDirectory"
        case .libraryDirectory: return "libraryDirectory"
        case .developerDirectory: return "developerDirectory"
        case .userDirectory: return "userDirectory"
        case .documentationDirectory: return "documentationDirectory"
        case .documentDirectory: return "documentDirectory"
        case .coreServiceDirectory: return "coreServiceDirectory"
        case .autosavedInformationDirectory: return "autosavedInformationDirectory"
        case .desktopDirectory: return "desktopDirectory"
        case .cachesDirectory: return "cachesDirectory"
        case .applicationSupportDirectory: return "applicationSupportDirectory"
        case .downloadsDirectory: return "downloadsDirectory"
        case .inputMethodsDirectory: return "inputMethodsDirectory"
        case .moviesDirectory: return "moviesDirectory"
        case .musicDirectory: return "musicDirectory"
        case .picturesDirectory: return "picturesDirectory"
        case .printerDescriptionDirectory: return "printerDescriptionDirectory"
        case .sharedPublicDirectory: return "sharedPublicDirectory"
        case .preferencePanesDirectory: return "preferencePanesDirectory"
        case .applicationScriptsDirectory: return "applicationScriptsDirectory"
        case .itemReplacementDirectory: return "itemReplacementDirectory"
        case .allApplicationsDirectory: return "allApplicationsDirectory"
        case .allLibrariesDirectory: return "allLibrariesDirectory"
        case .trashDirectory: return "trashDirectory"
        @unknown default:
            fatalError()
        }
    }
}
#endif

#if os(visionOS)
struct ContentStageConfiguration: CompositorLayerConfiguration {
    func makeConfiguration(capabilities: LayerRenderer.Capabilities, configuration: inout LayerRenderer.Configuration) {
        configuration.depthFormat = .depth32Float
        configuration.colorFormat = .bgra8Unorm_srgb
    
        let foveationEnabled = capabilities.supportsFoveation
        configuration.isFoveationEnabled = foveationEnabled
        
        let options: LayerRenderer.Capabilities.SupportedLayoutsOptions = foveationEnabled ? [.foveationEnabled] : []
        let supportedLayouts = capabilities.supportedLayouts(options: options)
        
        configuration.layout = supportedLayouts.contains(.layered) ? .layered : .dedicated
    }
}
#endif
