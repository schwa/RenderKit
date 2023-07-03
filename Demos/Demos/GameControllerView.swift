//
//  GameControllerView.swift
//  Demos
//
//  Created by Jonathan Wight on 7/2/23.
//

import SwiftUI
import GameController
import SwiftFormats

struct GameControllerView: View {
    
    @Observable
    class Model {
        var currentController: GCController? = nil
        var controllers: [GCController] = []
        
        var virtualController: GCVirtualController? = nil
        
        func scan() async {
            Task {
                print("LISTEN")
                for await _ in NotificationCenter.default.notifications(named: .GCControllerDidConnect) {
                    print("A")
                    currentController = GCController.current
                    controllers = GCController.controllers()
                }
                for await _ in NotificationCenter.default.notifications(named: .GCControllerDidBecomeCurrent) {
                    print("B")
                    currentController = GCController.current
                    controllers = GCController.controllers()
                }
            }
            Task {
                defer {
                    print("stopWirelessControllerDiscovery")
                    GCController.stopWirelessControllerDiscovery()
                }
                print("Not connected. Scanning for wireless…")
                await GCController.startWirelessControllerDiscovery()
            }
        }
    }
    
    @State
    var model = Model()
    
    var body: some View {
        NavigationStack {
            List(model.controllers, id: \.self) { controller in
                NavigationLink("\(controller.vendorName ?? "?")") {
                    Form {
                        Section {
                            Text("vendorName: \(controller.vendorName ?? "?")")
                            Text("productCategory: \(controller.productCategory)")
                            Text("isCurrent: \(GCController.current === controller, format: .bool)")
                            Text("isAttachedToDevice: \(controller.isAttachedToDevice, format: .bool)")
                            Text("isSnapshot: \(controller.isSnapshot, format: .bool)")
                            Text("playerIndex: \(controller.playerIndex.rawValue, format: .number)")
                            Text("playerIndex: \(controller.playerIndex.rawValue, format: .number)")
                            //                controller.physicalInputProfile.hasRemappedElements
                            
                            PhysicalInputProfileView(physicalInputProfile: controller.physicalInputProfile)
                        }
                    }
                    .navigationTitle("\(controller.vendorName ?? "?")")
                }
            }
        }
        .task {
            await model.scan()
        }
#if os(iOS)
        .toolbar {
            Button("Virtual") {
                Task {
                    let configuration = GCVirtualController.Configuration()
                    configuration.elements = [
                        GCInputButtonA,
                        GCInputButtonB,
                        GCInputButtonX,
                        GCInputButtonY,
                        //GCInputDirectionPad,
                        GCInputLeftThumbstick,
                        GCInputRightThumbstick,
                        GCInputLeftShoulder,
                        GCInputRightShoulder,
                        GCInputLeftTrigger,
                        GCInputRightTrigger
                    ]
                    let virtualController = GCVirtualController(configuration: configuration)
                    try! await virtualController.connect()
                    model.virtualController = virtualController
                }
            }
        }
#endif
    }
    
    struct PhysicalInputProfileView: View {
        let physicalInputProfile: GCPhysicalInputProfile

        var body: some View {
            List {
                ForEach(Array(physicalInputProfile.allElements.filter { $0.collection == nil }), id: \.self) { element in
                    VStack {
                        Label(element.localizedName ?? "?", systemImage: element.sfSymbolsName ?? "?")
                        Text(describing: NSStringFromClass(type(of: element)))
                        Text(verbatim: element.aliases.joined(separator: ", "))
                        if let pad = element as? GCControllerDirectionPad {
                            Text("PAD")
                        }
                    }

                }
            }

        }
    }

}


