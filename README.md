# RenderKit3

Yet another Metal Rendering engine experiment…

## Assumptions

Post-multiplication, Column-Major, Right-handed, Y up

## Goals

* Learn from RenderKit & RenderKitClassic
* More type safe
* Async
* Outputs
    * Built in offscreen renderer
    * Built in support for MTKView and CAMetalLayer
    * VisionKit 'CPSceneSessionRoleImmersiveSpaceApplication' output
    * (The more outputs the less fragile the api will be)
* Simpler API for just getting shit on screen
    * Create a simple render API that takes a single pipeline
* RenderEnvironment variables modeled after SwiftUI.Environment for safety
* Use Function builder for pipelines/stages etc
* Cleaner render model that more closely matches Metal.
* Built in support for RenderGraph editor (use NodeEditor)
* Work with multisample, ray tracing
* Figure out how to #include metal headers across packages (likely not possible).
* Get more helper code of RenderKit and into MetalSupport etc
* Use Spatial framework
* Take advantage of Swift macros
* Sort out the various projection apis

