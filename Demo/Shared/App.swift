import RenderKit
import SwiftUI

@main
struct RenderKitDemoApp: App {
    #if os(macOS)
        @Environment(\.openWindow)
        var openWindow

        @Environment(\.dismissWindow)
        var dismissWindow

        @Environment(\.openDocument)
        var openDocument

        var body: some Scene {
            Window("Welcome", id: "Welcome") {
                VStack {
                    Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                    Text(verbatim: Bundle.main.infoDictionary!["CFBundleName"]! as! String)
                    Text("Version \(Bundle.main.infoDictionary!["CFBundleShortVersionString"]! as! String)")
                    List {
                        openMenu
                        Button(title: "New Metal Shader…", systemImage: "doc") {
                        }
                        Button(title: "Open Metal Document…", systemImage: "folder", action: {
                        })
                    }
                    .buttonStyle { configuration in
                        configuration.label
                            .font(.body.bold())
                            .frame(maxWidth: .infinity)
                            .padding([.leading, .trailing], 10)
                            .padding([.top, .bottom], 5)

                            .background {
                                ButtonBorderShape.buttonBorder.fill(Color(red: 0.92, green: 0.92, blue: 0.92)).brightness(configuration.isPressed ? -0.2 : 0)
                            }
                            .accentColor(.primary)
                    }
                }
                .inspector(isPresented: .constant(true)) {
                    RecentDocuments() { url in
                        dismissWindow(id: "Welcome")
                        Task {
                            try! await openDocument(at: url)
                        }
                    }
                    .ignoresSafeArea()
                    .inspectorColumnWidth(320)
                }
            }
            .windowStyle(.hiddenTitleBar)
            Window("Demo", id: "DemoView") {
                DemosView()
            }
            Window("SpriteSheet", id: "SpriteSheet") {
                SpriteSheetView()
            }
            .commands {
                CommandMenu("Action") {
                    Button("Welcome") {
                        openWindow(id: "Welcome")
                    }
                    .keyboardShortcut("1", modifiers: [.command, .shift])
                    openMenu
                }
            }
            DocumentGroup(newDocument: MetalDocument()) { file in
                MetalDocumentView(document: file.$document)
            }
        }
    #endif

    #if os(iOS)
        var body: some Scene {
            WindowGroup {
                DemosView()
            }
        }
    #endif

#if os(macOS)
    @ViewBuilder
    var openMenu: some View {
        Button(title: "All Demos…", systemImage: "cube.transparent") {
            openWindow(id: "DemoView")
            dismissWindow(id: "Welcome")
        }
        .keyboardShortcut("2", modifiers: [.command, .shift])

        Button(title: "Minecraft Clone…", systemImage: "cube.transparent") {
            openWindow(id: "Minecraft")
            dismissWindow(id: "Welcome")
        }
        .keyboardShortcut("3", modifiers: [.command, .shift])

        Button(title: "SpriteSheet Editor…", systemImage: "cube.transparent") {
            openWindow(id: "SpriteSheet")
            dismissWindow(id: "Welcome")
        }
        .keyboardShortcut("4", modifiers: [.command, .shift])
    }
#endif
}

#if os(macOS)
struct RecentDocuments: View {
    @State
    var recentDocumentURLs: [URL] = []

    @State
    var selection: URL?

    let onPick: (URL) -> Void

    var body: some View {
        List(selection: $selection) {
            ForEach(recentDocumentURLs, id: \.self) { url in
                HStack {
                    Image(nsImage: NSWorkspace().icon(forFile: url.path))
                    VStack(alignment: .leading) {
                        Text(url.lastPathComponent).font(.body.bold()).lineLimit(1)
                        Text(url.path).font(.caption).lineLimit(1).truncationMode(.head)
                    }
                }
            }
        }
        .onAppear {
            recentDocumentURLs = NSDocumentController().recentDocumentURLs
        }
        .onChange(of: selection) {
            guard let selection else {
                return
            }
            onPick(selection)
        }
    }
}
#endif
