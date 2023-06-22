# RenderKit

A Metal rendering framework for Swift.

The main goal of RenderKit is to provide an experimental test bed for Metal rendering techniques. It is not intended to be a general-purpose rendering framework.

The primary research feature is the ability to define a rendering graph. Where render passes can be easily constructed and chained together. Render passes share data with an ``Environment`` for example a compute pass can "put" a texture into the environment and a render pass can "get" that texture from the environment.

There is a branch of RenderKit called 'RenderKitClassic' which contains the original RenderKit code. This is still used by a few projects of mine I haven't updated yet.

![Screen Shot](<Documentation/Screenshot 2023-06-22 at 08.10.28.png>)
