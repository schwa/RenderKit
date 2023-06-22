<meta charset="utf-8">

# Home

* [NOTES](NOTES.markdown)
* [PLAN](PLAN.markdown)
* [TODO](TODO.markdown)

## Introduction

In my spare time, I am building a Metal rendering engine. This doc is its README.

I intend this README to act as a combination of traditional README, TODO/Bug list, plan file, design document and scratchpad. I'm doing this mainly as a tool to "keep me honest" and provide some insight into what I'm writing.

## "View on GitHub"

RenderKit is a private project on GitHub with only the documentation available publicly; this is due to my employer being who my employer is.

## Project Description

This project is my second attempt at a Metal rendering engine (so perhaps it really should be called "RenderKit 2"?). My goals with this project are centred around implementing a data-driven render graph: where data (currently a .yaml file) defines the individual passes and stages of the Metal rendering pipeline.

RenderKit is data drive - both the scene graph definition and the render graph definition are defined as data. Examples of the YAML based file formats are here. These files are likely to be out of date incredibly quickly as iteratoins to the file format happen frequently.

* [Example RenderGraph File](Examples/RenderGraph.yaml)
* [Example SceneGraph File](Examples/SceneGraph.yaml)


<!-- ## Current State

Forthcoming. -->

