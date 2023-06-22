import CryptoKit
#if os(macOS)
    import Everything
    import MetalKit
    import os
    import RenderKit
    import Shaders
    import simd
    import SwiftUI
    #if canImport(SyntaxHighlighter)
        import SyntaxHighlighter
    #endif
    import UniformTypeIdentifiers
    import RenderKitSupport

    private let logger: Logger? = Logger(subsystem: "MetalDocument", category: "MetalDocument")

    struct MetalDocument: FileDocument {
        static var readableContentTypes: [UTType] = [UTType("com.apple.metal")!]

        var source: String
        var vertexFunctionName: String = "ShaderToy_VertexShader"
        var fragmentFunctionName: String = "ShaderToy_FragmentShader"

        init() {
            let url = Bundle.main.url(forResource: "ShaderEditorSample", withExtension: "txt")!
            source = try! String(contentsOf: url)
        }

        init(configuration: ReadConfiguration) throws {
            guard let data = configuration.file.regularFileContents else {
                fatalError("TODO")
            }
            guard let source = String(data: data, encoding: .utf8) else {
                fatalError("TODO")
            }
            self.source = source
        }

        func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
            guard let data = source.data(using: .utf8) else {
                fatalError("TODO")
            }
            return .init(regularFileWithContents: data)
        }
    }

    // MARK: -

    struct MetalDocumentView: View {
        @Environment(\.metalDevice)
        var device

        enum Mode {
            case undefined
            case rendering(Renderer<ShaderEditorRenderGraph>)
            case error(Error)
        }

        @State
        var mode: Mode = .undefined

        struct Event: Identifiable {
            let id = UUID()
            let date = Date()
            let sourceID: String
            enum Payload {
                case error(Error)
                case build
            }

            let payload: Payload
        }

        @State
        var events: [Event] = []

        @Binding
        var document: MetalDocument

        var body: some View {
            HSplitView {
                #if canImport(SyntaxHighlighter)
                    SyntaxEditorView(text: $document.source)
                #else
                    TextEditor(text: $document.source)
                #endif
                VStack {
                    Group {
                        switch mode {
                        case .undefined:
                            EmptyView()
                        case .error(let error):
                            PlaceholderShape().stroke()
                                .overlay(alignment: .center) {
                                    ErrorView(error)
                                }
                        case .rendering(let renderer):
                            RenderView(device: device, renderer: renderer)
                                .id(ObjectIdentifier(renderer))
                                .overlay(alignment: .bottom) {
                                    Text("\(sourceID)")
                                        .padding()
                                        .background(Color.white.opacity(0.5))
                                        .padding()

                                        .font(.caption.monospaced())
                                }
                        }
                    }
                    .aspectRatio(1.333, contentMode: .fit)
                    Form {
                        TextField(text: $document.vertexFunctionName, prompt: Text("Vertex Function")) { Text("Vertex Function").font(.caption) }.font(.caption.monospaced())
                        TextField(text: $document.fragmentFunctionName, prompt: Text("Fragment Function")) { Text("Fragment Function").font(.caption) }.font(.caption.monospaced())
                    }
                    .controlSize(.small)
                    List {
                        ForEach(events) { event in
                            HStack {
                                Text(event.date, format: .dateTime)
                                Text(event.sourceID)
                                DescriptionView(event.payload)
                            }
                        }
                    }
                    Spacer()
                }
                .padding([.leading, .trailing])
            }
            .onAppear {
                compile()
            }
            .onChange(of: document.source) {
                compile()
            }
        }

        @MainActor
        var sourceID: String {
            let hash = SHA256.hash(data: document.source.data(using: .utf8)!).map { ("0" + String($0, radix: 16)).suffix(2) }.joined()
            return String(hash.suffix(8))
        }

        @MainActor
        func compile() {
            do {
                logger?.log("### Compile: \(sourceID)")
                let source = document.source
                let vertexFunctionName = document.vertexFunctionName
                let fragmentFunctionName = document.fragmentFunctionName
                let submitter = ShaderEditorSubmitter(device: device)
                var shaderEditorPass = ShaderEditorPass(id: sourceID)
                let library = try device.makeLibrary(source: source, options: nil)
                library.label = "SourceEditorLibrary-\(sourceID)"
                let libraryProvider = LibraryProvider.manual(library)

                shaderEditorPass.vertexStage.function = FunctionProvider(functionName: vertexFunctionName, library: libraryProvider, label: "\(vertexFunctionName)-\(sourceID)")
                shaderEditorPass.fragmentStage.function = FunctionProvider(functionName: fragmentFunctionName, library: libraryProvider, label: "\(fragmentFunctionName)-\(sourceID)")
                let renderGraph = ShaderEditorRenderGraph(passes: [shaderEditorPass])
                let renderer = Renderer(device: device, graph: renderGraph, environment: RenderEnvironment())
                renderer.label = "Renderer-\(sourceID)"
                renderer.add(submitter: submitter)
                mode = .rendering(renderer)
                events.append(.init(sourceID: sourceID, payload: .build))
            }
            catch {
                mode = .error(error)
                events.append(.init(sourceID: sourceID, payload: .error(error)))
            }
        }

        func load() {
            /*
             LoadButton("Load GLSL…", allowedContentTypes: [UTType(filenameExtension: "glsl")!]) { result in
             guard case .success(let url) = result else {
             return
             }
             do {
             print(try Process.call(launchPath: "/opt/homebrew/bin/glslangValidator", arguments: [url.path, "-S", "frag", "-V", "-o", "/tmp/converted.frag.spv"]))
             print(try Process.call(launchPath: "/opt/homebrew/bin/spirv-cross", arguments: ["--msl", "/tmp/converted.frag.spv", "--output", "/tmp/converted.metal"]))

             source = try String(contentsOf: URL(fileURLWithPath: "/tmp/converted.metal"))
             }
             catch {
             error.log()
             }

             //                glslangValidator psrdnoise2.glsl -S vert -V -o psrdnoise2.vert.spv
             //                spirv-cross --msl psrdnoise2.vert.spv --output psrdnoise2.metal --msl-version 20100 --msl-argument-buffers
             }
             }
             .controlSize(.small)
             */
        }
    }

    struct ShaderEditorRenderGraph: RenderGraphProtocol {
        let passes: [any PassProtocol]
    }

    struct ShaderEditorPass: RenderPassProtocol {
        struct VertexStage: VertexStageProtocol {
            let id: String
            var function = FunctionProvider(functionName: "TODO", library: .default)
            let parameters = [
                Parameter(binding: ShaderBinding(kind: .buffer, index: 0), value: .variable(key: "$VERTICES")),
                Parameter(binding: ShaderBinding(kind: .buffer, index: 1), value: .variable(key: "$TRANSFORMS")),
            ]
        }

        struct FragmentStage: FragmentStageProtocol {
            let id: String
            var function = FunctionProvider(functionName: "TODO", library: .default)
        }

        let id: String
        var vertexStage: VertexStage
        var fragmentStage: FragmentStage

        init(id: String) {
            self.id = id
            vertexStage = VertexStage(id: "VertexStage-\(id)")
            fragmentStage = FragmentStage(id: "FragmentStage-\(id)")
        }
    }

    class ShaderEditorSubmitter: RenderSubmitter {
        let indexBuffer: MTLBuffer
        let vertexBuffer: MTLBuffer
        let transforms: Transforms

        init(device: MTLDevice) {
            var transforms = Transforms()
            transforms.modelView = .identity
            transforms.modelNormal = .identity
            transforms.projection = .identity
            self.transforms = transforms

            // swiftlint:disable collection_alignment
            let vertices: [Float] = [
                -1, -1, 0, 0, 0, 1, 0, 0,
                1, -1, 0, 0, 0, 1, 1, 0,
                1, 1, 0, 0, 0, 1, 1, 1,
                -1, 1, 0, 0, 0, 1, 0, 1,
            ]
            let indices: [UInt16] = [
                0, 1, 2,
                0, 2, 3,
            ]
            // swiftlint:enable collection_alignment

            let vertexBuffer = vertices.withUnsafeBytes {
                device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared)!
            }
            vertexBuffer.label = "Fullscreen Vertex Buffer"
            self.vertexBuffer = vertexBuffer

            let indexBuffer = indices.withUnsafeBytes {
                device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared)!
            }
            indexBuffer.label = "Fullscreen Index Buffer"
            self.indexBuffer = indexBuffer
        }

        func setup(state: inout RenderState) throws {
        }

        func shouldSubmit(pass: some RenderPassProtocol, environment: RenderEnvironment) -> Bool {
            true
        }

        func prepareRender(pass: some RenderPassProtocol, state: inout RenderState, environment: inout RenderEnvironment) throws {
        }

        func submit(pass: some RenderPassProtocol, state: RenderState, environment: inout RenderEnvironment, commandEncoder: MTLRenderCommandEncoder) throws {
            environment.update([
                "$VERTICES": .buffer(vertexBuffer, offset: 0),
                "$TRANSFORMS": .accessor(UnsafeBytesAccessor(transforms)),
            ])
            try commandEncoder.set(environment: environment, forPass: pass)
            commandEncoder.drawIndexedPrimitives(type: .triangle, indexCount: 6, indexType: .uint16, indexBuffer: indexBuffer, indexBufferOffset: 0)
        }
    }

    struct ErrorView: View {
        let error: Error

        init(_ error: Error) {
            self.error = error
        }

        var body: some View {
            Text(verbatim: error.localizedDescription).background(Color.orange)
        }
    }

    struct LoadButton: View {
        @State
        var presented = false

        let label: String
        let allowedContentTypes: [UTType]
        let onCompletion: (Result<URL, Error>) -> Void

        init(_ label: String, allowedContentTypes: [UTType], onCompletion: @escaping (Result<URL, Error>) -> Void) {
            self.label = label
            self.allowedContentTypes = allowedContentTypes
            self.onCompletion = onCompletion
        }

        var body: some View {
            Button(label) {
                presented = true
            }
            .fileImporter(isPresented: $presented, allowedContentTypes: allowedContentTypes, onCompletion: onCompletion)
        }
    }
#endif
