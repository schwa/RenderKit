## Notes/Links

Indirect Command Buffers

Look into command buffer completion handlers.
CVDisplayLinkGetActualOutputVideoRefreshPeriod
CVDisplayLinkGetOutputVideoLatency
CVDisplayLinkTranslateTime


### Metal

The primary reference.

* https://developer.apple.com/library/archive/documentation/Miscellaneous/Conceptual/MetalProgrammingGuide/Introduction/Introduction.html#//apple_ref/doc/uid/TP40014221-CH1-SW1

Frame Capture:

* MTLCaptureManager

Capture GPU Traces Without Xcode
Sometimes, you might want to capture a GPU trace when Xcode isn’t running. For example, you might want testers to be able to save a GPU trace when they discover a problem. To add this capability to your app, first add the MetalCaptureEnabled key to your Info.plist file, with a value of YES. In Xcode’s property list editor, this key appears as Metal Capture Enabled. After enabling this key, add code to your app to programmatically capture trace information and save it to a file for later analysis. For more information, see Capture GPU Command Data to a File.


* https://developer.apple.com/documentation/metal/using_a_render_pipeline_to_render_primitives
* https://metalbyexample.com
* https://metalbyexample.com/modern-metal-1/
* https://developer.apple.com/metal/
* https://developer.apple.com/metal/Metal-Shading-Language-Specification.pdf
* https://developer.apple.com/documentation/metal/reducing_the_memory_footprint_of_metal_apps

### SIMD is Column Major

https://developer.apple.com/documentation/accelerate/simd/working_with_matrices
https://developer.apple.com/documentation/accelerate/working_with_vectors
https://developer.apple.com/documentation/accelerate/working_with_quaternions

Metal is Column Major. The translation is in the right column. Column major right or post-multiplication.

"simd_double4x2 is a matrix containing four columns and two rows."

(Therefore a `SIMD4<Float>` is equivalent to `simd_float1x4`)


v` = m * v

```
01 05 09 13
02 06 10 14
03 07 11 15
04 08 12 16 

1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16

1 0 0 x
0 1 0 y
0 0 1 z
0 0 0 1 <- translation

1 0 0 0 0 1 0 0 0 0 1 0 x y z 1
```


### Column Major vs Row Major

https://www.scratchapixel.com/lessons/mathematics-physics-for-computer-graphics/geometry/row-major-vs-column-major-vector



### Transformation Matrixes

* https://stackoverflow.com/questions/349050/calculating-a-lookat-matrix

### "Rules"

#### Left Hand Rule

* https://www.ultraengine.com/community/blogs/entry/1567-the-left-hand-rule/
* https://www.scratchapixel.com/lessons/mathematics-physics-for-computer-graphics/geometry/row-major-vs-column-major-vector

```text
         ┌────┐   ┌────┐     
         │ +Y │   │ +Z │     
         └────┘   └────┘     
            *     *          
            *    *           
            *   *            
            *  *             
            * *              
            **         ┌────┐
            ***********│ +X │
           *           └────┘
          *                  
         *                   
        *                    
       *                     
┌────┐*                      
│ -Z │                       
└────┘                       
```


#### Right Hand Rule

#### In the field

- https://twitter.com/FreyaHolmer/status/644881436982575104

* Metal: Left-Hand -- https://developer.apple.com/library/archive/documentation/Miscellaneous/Conceptual/MetalProgrammingGuide/Introduction/Introduction.html#//apple_ref/doc/uid/TP40014221-CH1-SW1

"Normalized device coordinates use a left-handed coordinate system and map to positions in the viewport. Primitives are clipped to a box in this coordinate system and then rasterized. The lower-left corner of the clipping box is at an (x,y) coordinate of (-1.0,-1.0) and the upper-right corner is at (1.0,1.0). Positive-z values point away from the camera (into the screen.) The visible portion of the z coordinate is between 0.0 (the near clipping plane) and 1.0 (the far clipping plane)."

* OpenGL: Right-Hand
* DirectX: Left-Hand
* Unity: Left-hand -- https://graphics.pixar.com/usd/release/api/usd_geom_page_front.html
* USD: Right-hand
* POV-Ray: Left-Hand -- http://www.povray.org/documentation/view/3.6.0/15/
* GLTF: Right-hand -- https://github.com/KhronosGroup/glTF/issues/566

#### Converting

* https://towardsdatascience.com/change-of-basis-3909ef4bed43


#### LookAt

* https://docs.microsoft.com/en-us/windows/win32/direct3d9/d3dxmatrixlookatlh?redirectedfrom=MSDN
* https://www.scratchapixel.com/lessons/mathematics-physics-for-computer-graphics/lookat-function

### Engines

* https://github.com/google/filament

### PBR

* https://github.com/penumbra23/PBR-Shaders
* https://graphicscompendium.com/references/cook-torrance
* http://www.codinglabs.net/article_physically_based_rendering_cook_torrance.aspx

### SIMD

It uses a column-major naming convention; for example, a `simd_double4x2` is a matrix containing four columns and two rows.

* https://developer.apple.com/documentation/accelerate/simd/working_with_matrices
* https://stackoverflow.com/questions/17717600/confusion-between-c-and-opengl-matrix-order-row-major-vs-column-major


### ModelIO

* Use MDLCamera

### Function Stitching

* https://developer.apple.com/videos/play/wwdc2021/10229/

### More

// If building with the 'metal' command-line tool, include the options '-gline-tables-only' and '-frecord-sources'.

* https://metalkit.org
* https://github.com/acdemiralp/fg
* https://docs.unrealengine.com/en-US/Programming/Rendering/RenderDependencyGraph/index.html
* https://ourmachinery.com/post/high-level-rendering-using-render-graphs/
* https://themaister.net/blog/2017/08/15/render-graphs-and-vulkan-a-deep-dive/
* https://www.ea.com/frostbite/news/framegraph-extensible-rendering-architecture-in-frostbite
* https://en.wikipedia.org/wiki/Field_of_view_in_video_games
* https://jsantell.com/model-view-projection/
* https://jsantell.com/3d-projection/
* https://swiftuirecipes.com/blog/swift-5-5-async-await-cheatsheet
* https://en.wikipedia.org/wiki/Blinn–Phong_reflection_model

### Matrix decomposition

* https://caff.de/posts/4X4-matrix-decomposition/
* https://callumhay.blogspot.com/2010/10/decomposing-affine-transforms.html

### Syntax Highlight

* https://tree-sitter.github.io/tree-sitter/#talks-on-tree-sitter

### GLSL/SPIRV

GLSL -> SPIRV

* glslValidator

SPIRV -> Metal

* https://github.com/KhronosGroup/SPIRV-Cross

### Random Links

* https://developer.apple.com/documentation/metal/gpu_features/understanding_gpu_family_4
* https://developer.apple.com/documentation/metal/textures/understanding_color-renderable_pixel_format_sizes
* https://developer.apple.com/documentation/metal/mtlfunctionstitchinggraph
* https://developer.apple.com/documentation/metalperformanceshadersgraph
* https://developer.apple.com/documentation/metal/developing_metal_apps_that_run_in_simulator
* https://autodesk.github.io/standard-surface/
* https://en.wikipedia.org/wiki/Order-independent_transparency
* https://github.khronos.org/glTF-Sample-Viewer-Release/
* http://psgraphics.blogspot.com/2021/12/what-is-uber-shader.html
* https://en.wikipedia.org/wiki/Open_Shading_Language
* https://github.com/AcademySoftwareFoundation/OpenShadingLanguage
* https://github.com/Autodesk/standard-surface/blob/master/reference/standard_surface.osl
* http://www.cse.chalmers.se/~d00sint/StochasticTransparency_I3D2010.pdf
* https://github.com/penumbra23/PBR-Shaders
* http://www.codinglabs.net/article_physically_based_rendering_cook_torrance.aspx
* https://graphicscompendium.com/references/cook-torrance
* https://medium.com/@alexander.wester/ray-tracing-soft-shadows-in-real-time-a53b836d123b
* https://google.github.io/filament/Materials.html
* https://google.github.io/filament/Filament.md.html
* http://blog.wolfire.com/2009/07/linear-algebra-for-game-developers-part-2/
* https://mathinsight.org/dot_product
* https://www.youtube.com/watch?v=LyGKycYT2v0
* https://theodox.github.io/2014/bagels_and_coffee
* http://www.codinglabs.net/article_world_view_projection_matrix.aspx
* https://www.opengl-tutorial.org/beginners-tutorials/tutorial-3-matrices/
* https://www.3dgep.com/understanding-the-view-matrix/
* https://caff.de/posts/4X4-matrix-decomposition/decomposition.pdf
* https://caff.de/posts/4X4-matrix-decomposition/
* https://www.realtimerendering.com/blog/tag/froxel/
* https://mitsuba-renderer.org/index_old.html
* https://www.iquilezles.org/www/articles/warp/warp.htm
* https://www.scratchapixel.com
* https://thebookofshaders.com/12/
* https://metalbyexample.com/tessellation/
* https://thebookofshaders.com
* https://bgolus.medium.com/the-quest-for-very-wide-outlines-ba82ed442cd9
* https://blog.demofox.org/2016/02/29/fast-voronoi-diagrams-and-distance-dield-textures-on-the-gpu-with-the-jump-flooding-algorithm/
* https://www.shadertoy.com/view/Mdy3D3
* https://shaderbits.com/blog/various-distance-field-generation-techniques
* https://gamedev.stackexchange.com/questions/33590/how-to-generate-caves-that-resemble-those-of-minecraft
* https://www.lexaloffle.com/bbs/?pid=82362
* https://en.wikipedia.org/wiki/Connected-component_labeling
* https://code-examples.net/en/q/23e5467
* https://www.youtube.com/watch?v=A0pxY9QsgJE
* https://prideout.net/blog/distance_fields/
* https://theodox.github.io/2014/dots_all_folks.html
* https://github.com/google/shaderc
* https://sites.google.com/site/letsmakeavoxelengine/home?authuser=0
* https://www.whitman.edu/Documents/Academics/Mathematics/2017/Shi.pdf


Homebrew:

* spirv-cross
* spirv-tools
* glslang -> glslValidator

| bits per pixel     | bits per component    | alpha/endian                                                                           |
|--------------------|-----------------------|----------------------------------------------------------------------------------------|
| 16  bits per pixel | 5  bits per component | kCGImageAlphaNoneSkipFirst                                                             |
| 32  bits per pixel | 8  bits per component | kCGImageAlphaNoneSkipFirst                                                             |
| 32  bits per pixel | 8  bits per component | kCGImageAlphaNoneSkipLast                                                              |
| 32  bits per pixel | 8  bits per component | kCGImageAlphaPremultipliedFirst                                                        |
| 32  bits per pixel | 8  bits per component | kCGImageAlphaPremultipliedLast                                                         |
| 32  bits per pixel | 10 bits per component | kCGImageAlphaNone + kCGImagePixelFormatRGBCIF10                                        |
| 64  bits per pixel | 16 bits per component | kCGImageAlphaPremultipliedLast                                                         |
| 64  bits per pixel | 16 bits per component | kCGImageAlphaNoneSkipLast                                                              |
| 64  bits per pixel | 16 bits per component | kCGImageAlphaPremultipliedLast  + kCGBitmapFloatComponents + kCGImageByteOrder16Little |
| 64  bits per pixel | 16 bits per component | kCGImageAlphaNoneSkipLast + kCGBitmapFloatComponents + kCGImageByteOrder16Little       |
| 128 bits per pixel | 32 bits per component | kCGImageAlphaPremultipliedLast + kCGBitmapFloatComponents                              |
| 128 bits per pixel | 32 bits per component | kCGImageAlphaNoneSkipLast + kCGBitmapFloatComponents                                   |
 See Quartz 2D Programming Guide (available online) for more information.

