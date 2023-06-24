import CoreVideo
import Everything
import Foundation
import Metal
import MetalSupport
import ModelIO
import RenderKit
import RenderKitSupport
import SwiftUI

struct MetalInfoView: View {
    var body: some View {
        ScrollView {
            Form {
                #if os(macOS)
                    Section("Screens") {
                        ForEach(NSScreen.screens, id: \.self) { screen in
                            ScreenInfoView(screen: screen)
                        }
                    }
                    Section("CV Host Clock") {
                        LabeledContent("CVGetHostClockFrequency", value: CVGetHostClockFrequency(), format: .number)
                        LabeledContent("CVGetHostClockMinimumTimeDelta", value: CVGetHostClockMinimumTimeDelta(), format: .number)
                    }
                #endif
                Section("Devices") {
                    MTLDeviceInfoView()
                }
            }
        }
    }
}

struct MTLDeviceInfoView: View {
    @Environment(\.metalDevice)
    var device

    var body: some View {
        Section("MTLDevice") {
            Group {
                LabeledContent("name", value: device.name)
            }
            Group {
                ForEach(MTLGPUFamily.allCases, id: \.self) { family in
                    LabeledContent("supportsFamily(\(family))", value: device.supportsFamily(family), format: .bool)
                }
            }
            Group {
                LabeledContent("registryID", value: device.registryID, format: .radix)
                #if os(macOS)
                    LabeledContent("isLowPower", value: device.isLowPower, format: .bool)
                    LabeledContent("isHeadless", value: device.isHeadless, format: .bool)
                    LabeledContent("isRemovable", value: device.isRemovable, format: .bool)
                    LabeledContent("hasUnifiedMemory", value: device.hasUnifiedMemory, format: .bool)
                    LabeledContent("location", value: desc(device.location))
                    LabeledContent("locationNumber", value: device.locationNumber, format: .number)
                    LabeledContent("maxTransferRate", value: device.maxTransferRate, format: .byteCount)
                    LabeledContent("recommendedMaxWorkingSetSize", value: device.recommendedMaxWorkingSetSize, format: .byteCount)
                    LabeledContent("isDepth24Stencil8PixelFormatSupported", value: device.isDepth24Stencil8PixelFormatSupported, format: .bool)
                #endif
            }
            Group {
                LabeledContent("readWriteTextureSupport", value: desc(device.readWriteTextureSupport))
                LabeledContent("argumentBuffersSupport", value: desc(device.argumentBuffersSupport))
            }
            Group {
                LabeledContent("readWriteTextureSupport", value: desc(device.readWriteTextureSupport))
                LabeledContent("argumentBuffersSupport", value: desc(device.argumentBuffersSupport))
                LabeledContent("areRasterOrderGroupsSupported", value: device.areRasterOrderGroupsSupported, format: .bool)
                LabeledContent("supports32BitFloatFiltering", value: device.supports32BitFloatFiltering, format: .bool)
                LabeledContent("supports32BitMSAA", value: device.supports32BitMSAA, format: .bool)
                LabeledContent("supportsQueryTextureLOD", value: device.supportsQueryTextureLOD, format: .bool)
                LabeledContent("supports32BitFloatFiltering", value: device.supports32BitFloatFiltering, format: .bool)
                #if os(macOS)
                    LabeledContent("supportsBCTextureCompression", value: device.supportsBCTextureCompression, format: .bool)
                #endif
                LabeledContent("supportsPullModelInterpolation", value: device.supportsPullModelInterpolation, format: .bool)
                LabeledContent("supportsShaderBarycentricCoordinates", value: device.supportsShaderBarycentricCoordinates, format: .bool)
            }
            Group {
                LabeledContent("currentAllocatedSize", value: device.currentAllocatedSize, format: .byteCount)
                LabeledContent("supportsTextureSampleCount(1)", value: device.supportsTextureSampleCount(1), format: .bool)
                LabeledContent("supportsTextureSampleCount(2)", value: device.supportsTextureSampleCount(2), format: .bool)
                LabeledContent("supportsTextureSampleCount(3)", value: device.supportsTextureSampleCount(3), format: .bool)
                LabeledContent("supportsTextureSampleCount(4)", value: device.supportsTextureSampleCount(4), format: .bool)
                LabeledContent("maxThreadgroupMemoryLength", value: device.maxThreadgroupMemoryLength, format: .byteCount)
                LabeledContent("maxArgumentBufferSamplerCount", value: device.maxArgumentBufferSamplerCount, format: .byteCount)
                LabeledContent("areProgrammableSamplePositionsSupported", value: device.areProgrammableSamplePositionsSupported, format: .bool)
                #if os(macOS)
                    LabeledContent("peerGroupID", value: desc(device.peerGroupID))
                    LabeledContent("peerIndex", value: device.peerIndex, format: .number)
                #endif
            }
            Group {
                #if os(macOS)
                    LabeledContent("peerCount", value: device.peerCount, format: .number)
                #endif
                LabeledContent("sparseTileSizeInBytes", value: device.sparseTileSizeInBytes, format: .byteCount)
                LabeledContent("maxBufferLength", value: device.maxBufferLength, format: .byteCount)
                LabeledContent("supportsDynamicLibraries", value: device.supportsDynamicLibraries, format: .bool)
                LabeledContent("supportsRenderDynamicLibraries", value: device.supportsRenderDynamicLibraries, format: .bool)
                LabeledContent("supportsRaytracing", value: device.supportsRaytracing, format: .bool)
                LabeledContent("supportsFunctionPointers", value: device.supportsFunctionPointers, format: .bool)
                LabeledContent("supportsFunctionPointersFromRender", value: device.supportsFunctionPointersFromRender, format: .bool)
                LabeledContent("supportsRaytracingFromRender", value: device.supportsRaytracingFromRender, format: .bool)
                LabeledContent("supportsPrimitiveMotionBlur", value: device.supportsPrimitiveMotionBlur, format: .bool)
            }
        }
    }
}

// MARK: -

#if os(macOS)
    struct ScreenInfoView: View {
        let screen: NSScreen

        var body: some View {
            Section("Screen \(NSScreen.screens.firstIndex(of: screen)!, format: .number)") {
                Group {
                    LabeledContent("Name", value: screen.localizedName)
                    LabeledContent("Depth", value: screen.depth.rawValue, format: .number)
                    LabeledContent("Frame", value: screen.frame, format: CGRectFormat())
                    LabeledContent("Visible Frame", value: screen.visibleFrame, format: CGRectFormat())
                    LabeledContent("Device Description", value: String(describing: screen.deviceDescription))
                    screen.colorSpace.map { colorspace in
                        LabeledContent("Color Space") {
                            ColorspaceView(colorspace)
                        }
                    }
                    LabeledContent("backingScaleFactor", value: screen.backingScaleFactor, format: .number)
                    LabeledContent("maximumExtendedDynamicRangeColorComponentValue", value: screen.maximumExtendedDynamicRangeColorComponentValue, format: .number)
                    LabeledContent("maximumExtendedDynamicRangeColorComponentValue", value: screen.maximumExtendedDynamicRangeColorComponentValue, format: .number)
                    LabeledContent("maximumPotentialExtendedDynamicRangeColorComponentValue", value: screen.maximumPotentialExtendedDynamicRangeColorComponentValue, format: .number)
                }
                Group {
                    LabeledContent("maximumReferenceExtendedDynamicRangeColorComponentValue", value: screen.maximumReferenceExtendedDynamicRangeColorComponentValue, format: .number)
                    LabeledContent("maximumFramesPerSecond", value: screen.maximumFramesPerSecond, format: .number)
                    LabeledContent("minimumRefreshInterval", value: screen.minimumRefreshInterval, format: .number)
                    LabeledContent("maximumRefreshInterval", value: screen.maximumRefreshInterval, format: .number)
                    LabeledContent("displayUpdateGranularity", value: screen.displayUpdateGranularity, format: .number)
                    TimelineView(.periodic(from: .now, by: 0.1)) { _ in
                        LabeledContent("lastDisplayUpdateTimestamp", value: screen.lastDisplayUpdateTimestamp, format: .number)
                    }
                }
            }
        }
    }
#endif

// MARK: -

struct ColorspaceView: View {
    let colorspace: CGColorSpace

    init(_ colorspace: CGColorSpace) {
        self.colorspace = colorspace
    }

    #if os(macOS)
        init(_ colorspace: NSColorSpace) {
            self.colorspace = colorspace.cgColorSpace!
        }
    #endif

    var body: some View {
        Text(verbatim: "\(colorspace)")
    }
}

extension String.StringInterpolation {
    mutating func appendInterpolation<F>(_ value: F.FormatInput, format: F) where F: FormatStyle, F.FormatInput: Equatable, F.FormatOutput == String {
        appendLiteral(format.format(value))
    }
}

struct CGPointFormat: FormatStyle {
    func format(_ value: CGPoint) -> String {
//        let x: [String] = [value.x, value.y].map { $0.formatted(.number.grouping(.never)) }
//
//        return x.formatted(.list(type: .and, width: .narrow))
        "\(value.x, format: .number.grouping(.never)), \(value.y, format: .number.grouping(.never))"
    }
}

struct CGSizeFormat: FormatStyle {
    func format(_ value: CGSize) -> String {
        "\(value.width, format: .number.grouping(.never)), \(value.height, format: .number.grouping(.never))"
    }
}

struct CGRectFormat: FormatStyle {
    func format(_ value: CGRect) -> String {
        "\(value.origin, format: CGPointFormat()), \(value.size, format: CGSizeFormat())"
    }
}

// MARK: -

struct DescriptionFormat<T>: FormatStyle {
    func format(_ value: T) -> String {
        String(describing: value)
    }
}

extension FormatStyle where Self == DescriptionFormat<CustomStringConvertible> {
    static var description: DescriptionFormat<CustomStringConvertible> {
        DescriptionFormat()
    }
}

// MARK: -

struct RadixFormat<T>: FormatStyle where T: BinaryInteger {
    var radix: Int = 16
    var prefix: String = "0x"
    func format(_ value: T) -> String {
        prefix + String(value, radix: radix)
    }
}

extension FormatStyle where Self == RadixFormat<Int> {
    static var radix: RadixFormat<Int> { RadixFormat() }
}

extension FormatStyle where Self == RadixFormat<UInt64> {
    static var radix: RadixFormat<UInt64> { RadixFormat() }
}

// MARK: -

struct BoolFormat: FormatStyle {
    func format(_ value: Bool) -> String {
        value ? "YES" : "NO"
    }
}

extension FormatStyle where Self == BoolFormat {
    static var bool: BoolFormat {
        BoolFormat()
    }
}

// MARK: -

// TODO: .byteCount(style: .memory)

struct ByteCountFormat<T>: FormatStyle {
    func format(_ value: T) -> String {
        ByteCountFormatter().string(for: value)!
    }
}

extension FormatStyle where Self == ByteCountFormat<Int> {
    static var byteCount: ByteCountFormat<Int> { ByteCountFormat() }
}

extension FormatStyle where Self == ByteCountFormat<UInt64> {
    static var byteCount: ByteCountFormat<UInt64> { ByteCountFormat() }
}

func desc(_ v: Any) -> String {
    String(describing: v)
}
