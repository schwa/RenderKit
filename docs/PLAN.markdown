## Plan

### 2022-06-4

* Wow no real updates in 3-month. Shame!

### 2022-03-01

* RenderGraph is now fully definable in code as well as in YAML. This uses a relatively lightweight definition structure.

### 2022-02-15

* Added a super basic particle system for fun - with instancing.
* Biggest problem right now is the "select" loop - making sure the right submitters and submitter data (scene graph nodes) are being used by the right render pass.


### 2022-02-08

* Encoder index bindings are done - mostly. All bindings are named and #s are assigned. Can still improve design later.
* `prepare` is confusing. There are `prepare`s that are called upon renderer setup. Then there are `prepares` called every frame before encoding. We need to differentiate between the two and also provide a way to have dirty state to skip things that can re-use prepared state from last frame.

Solution:

    Setup - called upon frame setup (just before rendering first frame)
    Prepare - called before rendering
    Render/Submit
    
### 2022-02-02

* Started on GLTF import which means starting on PBR shaders.

There are two big issues right now

1) Encoder index bindings. At the moment these are hardcoded integers in the shaders themselves and in the RenderGraph. We define a simple "uri" style format for them, e.g. "texture#0", "buffer#0". That way we can differentiate between two indices that are used for two different resource types. We really need some master set of bindings. We can have a Bindings.h that exposes an enum we can use in Metal and Swift. However we can't refer to enum names from .yaml and we'll need to manually add a string. Our uri format will be come "texture#diffuse_material" etc. One problem with a global enum is that it makes it harder to extend later. We can also use compilation time constants to allow for a level of indirection of index #s - useful if we ever optimise bindings to reduce number of set calls.

2) Each entity can have materials from different lighting/shading models (unlit, blinn-phong, pbr). Each entity can have different geometry represenations, e.g. mesh based, voxel based etc. How do we efficiently iterate through all the entities and render them using the same model (shaders)? How do we handle different kinds of geometries with different needs? Can we make a single "uber shader" that can handle both voxel geometries (with per vertex colors) and simple texture based geometries? Can we use the VertexDescriptor to turn off and on fields of the vertex efficiently?

I assume we'll need to have a way of each pass selecting what entities it can render. Combined with some kind of uber shader for each lighting type.

Before adding PBR or finishing GLTF it would be best to finish the unlit shader and maybe add a toon shader too. This will exercise the selection model (it's beginning to look a light sql)

`vertexDescriptor` is set on `MTLRenderPipelineDescriptor`/`MTLRenderPipelineState`. so not sure i can control the vertex descriptor on a per entity basis.

MDLVertexDescriptor is better documented and more flexible.

### 2022-02-01

* RenderGraph can now be encoded again.
* Build 1st pass at RenderGraph Editor - needs more work
* "Data Flow" view
* Indexes are now ShaderBindings
* Cleaned up a lot of warnings

### 2022-01-29/2022-01-30

* Voxels. Brought back MagicaVoxel imports.

### "Sprint" Goals

* Refactor callback mechanism and Render Environment
* Investigate Actors.

### 2022-01-28

Clean up the multiple binding issue
Add ResourceBinding object to Environment
Environment is now 1:1 with CommandEncoder
Each pass render creates a new command encoder and a new envionment with associated binding
Submitters bind resources through environment not commend encoder - gives us a chance to not double bind same resource
Environment on a renderer ("global") "level is just a dictionary - per pass environment pre-loaded with "global" dictionary

### 2022-01-27

Cleanup of main render logic/flow

#### Current Render Logic


```
DisplayLink.<tick>
    MetalView.draw
        RenderView.<draw closure>
            Renderer.render
                Renderer.prepareFrame
                    <cache pass data>
                <For Each Pass>
                    configure(commandEncoder:forPass:)
                    <for each submitter>
                        <set lighting>
                        <set transforms>
                        <for each entity>
                            <set transforms>
                            <set environment>
                            draw
                commit
```

RenderModel needs to be renamed to "SceneRenderer" - or rather responsibility of setting up renderer & handling renderer callbacks need to be teased apart
There could be multiple "SceneRenderers" (Subrenderers?), one for scene graphs, one for HUD, one for (say) post processing, one for debug geometry. These do the drawing.



### 2022-01-27

* Large refactoring of code. Created concept of "Submitters" protocol for things that submit geometry.
* State is all self contained.
* Turned on actors and boom - worked perfectly.

### 2022-01-26

* Not "sprint" related
* Actors.
* Oh boy that was fun.
* We're passing too much stuff around that is accessed from all over the place. This needs to be cleaned up before actors are used in good faith. The issue is mainly with how we triggr the callback, anything can access Renderer.Environment at any time. This is bad obviously. Also we need to poke into MTLFunctions to get argument encoders - this needs to be isolated. Make more of renderer readonly to outside world.
* Actors may not be such a bad idea.
* Next goals:

1) Improve the encoder callback so that it passes everything that is needed - environment and argument encoder lookup functions mainly. (Maybe replace callback with protocol)
2) Replace Renderer.render with a struct that is passed _everything_ needed as inputs, the struct can be reused around if state isn't changed. This could mitigate potential actor perf issues and is just better design anyways.
3) Make Renderer an Actor

### 2022-01-25

* Matrix code was not broken. LookAt was broken. had order of transform multiplication reversed.
* Still moved all 4x4 matrix code into RenderKit - will have to move it back at some point
* Working on "DragLook" view
* Breaking camera into Camera and CameraController.
* Want to get mouselook working next.

### 2022-01-23

* Spent a lot of time cleaning up the UI, adding a consistent editor view hierarchy.
* Cleaned up matrix code
* "Fixed" reversed look-at
* Coming rapidly to conclusion that my matrix code is broken 

### 2022-01-17

* Clean up render yaml
* CLean up rendering and render pass attachments - no longer cache it with each pass. Only functions are cached now
* Can define attachments in render graph

The role of "renderPassBody" is badly defined.

```
[Renderer] for each pass
[Renderer]     set up render pass descriptor # Can be coelesced across passes
[Renderer]     create renderCommandEncoder   # Can be coelesced across passes
[Renderer]     setupRenderPipelineState
[Scene]        for each entity
[Scene]            set up environment
[Scene]            set environment on renderCommandEncoder
[Scene]            draw geometry 
[Renderer]     end encoding                  # Can be coelesced across passes
```

Instead of renderPassBody it should be a instance of a protocol

bindStageParameters is really an extension on MTLRenderCommandEncoder

### 2022-01-16

* Break for a few days.
* Use own Metal Layer to get full control over rendering

### 2022-01-12

* Rendering broken so that only one geometry can be rendered per pass. Fixing this made the renderer code pretty ugly and too much responsibility is spread between the renderer and the callbacks (in these case the SceneGraph "Renderer")
* Needed to flesh out the shapes api a little more so parameters can actually be passed into ModelIO
* Texture loading from bundle/url now working
* Clean up of providers, geometry and materials.
* Attempted to get sky-dome working but making the dome too large and it vanishes, does not seem to be inverted normals issue.
* Added a "add light" to see how many lights we can render. A LOT. https://twitter.com/schwa/status/1481529978164449282
* Moved the light array into a real LightingModel object that owns a MTLBuffer full of lights. Increased the lught limit from around 80 to effectively unlimited.

### 2022-01-11

* Primary RenderGraph types are now classes not structs with (weak) parent variables from stage -> pass. This will allow more graph traversal.
* Parameter keys are now tagged objects strings of strings
* Cleaned up looking up of passes and parameters. Made fetching argument buffer encoders by parameter name rather easy. 

### 2022-01-10

* Cleaned up the shader source code, broke out code into helper functions.
* Implemented Argument Buffers for BlinnPhong - ~~causes images in the metal debugger to be corrupt though~~. (Update was not calling useResource on encoder)
* Implemented getting argument buffer encoders from the shader function itself - currently very verbose, hacky and inefficient.
* We now get vertex descriptors directly from the shader.

### 2022-01-09

Flesh out TODO with info on argument buffers. Get docs ready for publishing.

### 2022-01-06

My goal for today is to update the README, get the README->GIST action working and put the README online.

### Sprint Goals

* ~~Publish docs.~~
* ~~Argument buffers~~.
* ~~Fix camera and lookAt issues.~~
* ~~Finish WASD controller~~
* Finish more basic UI widgets - toggle render passes, ~~angle of camera etc~~.


### Old Plan

I started this project on Christmas day, 2021. Between 2021-12-25 through 2022-01-06, there have been 361 commits in this repository alone. I made zero dot plan updates during that time and just worked from a TODO list instead.
