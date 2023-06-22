# RenderGraphKit

## TODO

- [ ] Improve RenderGraph mode
    - [ ] Every pass processes all entities - this is wrong. Passes need to specify what inputs they take:
      - [ ] "Scene" as input - how do we opt scenes into what passes? (** TOP ISSUE **)
      - [ ] Hard coded geometry as input - e.g. a skybox
    - [ ] Result of previous render/compute/tile pass as input
      - [ ] Deferred / forward+ shader [XL]
    - [X] Render Stack
      - [X] `RenderStackPushable` - things you can push on a render stack to provide uniforms and other objects to shaders
          - [X] World transform
          - [X] Phong lighting
          - [X] Entities
      - [ ] Optimisation - stop using dicts of strings
         - [ ] Strings -> Ints -> Arrays
    - [ ] Replace IDs with named values across yaml, shaders and swift (XS)
    - [X] Fix uniform/material/texture handling
    - [ ] Optimize uniforms so they're not redundant (M)
    - [ ] Add compute shaders (M)
      - [ ] Game of life in a texture!
      - [ ] Book of Shaders demos
    - [ ] Add ability to pass previous frame to shaders (M)
    - [X] Get multipass working
    - [ ] Put uniforms into labeled Buffers (S)
        - [ ] Can't really put per entity uniforms into a buffer - need to allocate per entity (?)
        - [ ] break uniforms up into world uniforms / entity uniforms - camera is part of world state (S)
- [X] Get rid of RenderKit dependency (M)
  - [X] VertexBuilder (S)
- [ ] Clean up Everything shaders - put into demo project (L)
  - [X] Most of RenderKit is deprecated as part of this rename to "ClassicRenderKit" (L)
  - [ ] Deprecate SIMD & Command Encoder stuff in Everything/RenderKit (S)
    - [ ] Might have to move deprecated functions directly to RenderKitClassic (S)
- [ ] Use a place holder for MTLDevice so we can clean up later. (S)
  - [ ] Need some kind of "late binding" concept (L)
- [ ] WASD controller (M)
- [ ] GLTF support (XXL)
- [ ] Make a MetalView that moves some responsibility out of RenderGraphView - has setup and per frame closures (S)
- [ ] Stop using MLKView and use CAMetalLayer - fixes the memoryless issue on Apple Silicon (M)
- [ ] Debug Geometry (M)
- [ ] BUG: Specular highlight is getting affected by camera location (M)
- [ ] BUG: look(at:…) still seems to looking straight ahead (can't look behind the camera?) (M)
- [ ] Matrix decomposition (M)
- [ ] Look into function stitching (?)
- [ ] Fix/More UI dials (M)
- [ ] Simple animation (S)
- [ ] Post processing with Tile Shaders (M)
- [ ] PBR rendering (XXL)
- [ ] Shadows (XL)
- [X] Use textures for material parameters
  - [X] Solid colour materials are 1x1 pixel textures with relevant sampling
- [X] Get rid of non-mesh geometry
- [X] Fix depth buffer issues
- [X] Finish map view and make it draggable
- [X] Basic texture support
- [ ] Skybox (M)
- [ ] Multithreading graph (XXXL)
- [ ] FPS box (S)
- [ ] Configure DepthStencilState from a pass (S)
- [ ] Rename RenderPass.Stage.Inputs (S) - these are parameters?
- [ ] RenderPass.State.Constants - constants should be able to be set at runtime not just in the graph file.
    - [X] Proof of concept
    - [ ] More types:
        - [ ] Scalars
        - [ ] Transforms
        - [ ] Colors
        - [ ] More vector types
- [ ] RenderPass should not create a PipelineDescriptor, but merely configure one created by renderer/
- [X] Stop using drawable size did change
- [X] Passes are all identical - get rid of protocol and use concrete type

## Links

### SIMD

It uses a column major naming convention; for example, a simd_double4x2 is a matrix containing four columns and two rows.

- https://developer.apple.com/documentation/accelerate/simd/working_with_matrices
- https://stackoverflow.com/questions/17717600/confusion-between-c-and-opengl-matrix-order-row-major-vs-column-major

### Metal

"Normalized device coordinates use a left-handed coordinate system and map to positions in the viewport. Primitives are clipped to a box in this coordinate system and then rasterized. The lower-left corner of the clipping box is at an (x,y) coordinate of (-1.0,-1.0) and the upper-right corner is at (1.0,1.0). Positive-z values point away from the camera (into the screen.) The visible portion of the z coordinate is between 0.0 (the near clipping plane) and 1.0 (the far clipping plane)."

- https://developer.apple.com/documentation/metal/using_a_render_pipeline_to_render_primitives
- https://metalbyexample.com
- https://metalbyexample.com/modern-metal-1/
- https://developer.apple.com/metal/
- https://developer.apple.com/metal/Metal-Shading-Language-Specification.pdf

### ModelIO

Use MDLCamera

### Function Stitching

- https://developer.apple.com/videos/play/wwdc2021/10229/

### More

// If building with the 'metal' command line tool, include the options '-gline-tables-only' and '-frecord-sources'.

- https://github.com/acdemiralp/fg
- https://docs.unrealengine.com/en-US/Programming/Rendering/RenderDependencyGraph/index.html
- https://ourmachinery.com/post/high-level-rendering-using-render-graphs/
- https://themaister.net/blog/2017/08/15/render-graphs-and-vulkan-a-deep-dive/
- https://www.ea.com/frostbite/news/framegraph-extensible-rendering-architecture-in-frostbite
- https://en.wikipedia.org/wiki/Field_of_view_in_video_games
- https://jsantell.com/model-view-projection/
- https://jsantell.com/3d-projection/
- https://swiftuirecipes.com/blog/swift-5-5-async-await-cheatsheet
- https://en.wikipedia.org/wiki/Blinn–Phong_reflection_model

### Matrix decomposition

- https://caff.de/posts/4X4-matrix-decomposition/
- https://callumhay.blogspot.com/2010/10/decomposing-affine-transforms.html

### Syntax Highlight

- https://tree-sitter.github.io/tree-sitter/#talks-on-tree-sitter

### GLSL/SPIRV

GLSL -> SPIRV

- glslValidator

SPIRV -> Metal

- https://github.com/KhronosGroup/SPIRV-Cross

Homebrew:

spirv-cross
spirv-tools
glslang -> glslValidator
