# Zig EFI

A simple library for creating EFI applications/operating systems in Zig.

## Installation
NOTE: Only Zig version 0.13.0 is supported.
1. In your project containing your `build.zig` file:
```sh
zig fetch --save git+https://github.com/LandStander27/zig-efi-lib
```
2. Copy these files into your project:
- [Dockerfile](Dockerfile)
- [Makefile](Makefile)
- [build.zig template](build.zig.template) (Rename to `build.zig`)
3. Done!

## Building an EFI Application
1. Install Docker
2. Run:
```sh
make docker
```

## Highlighted features
* Never have to call EFI functions manually
* Heap management
* Optional panic handler that enables partial debugging (depending on how far along the OS setup is)
* Graphics
	* Text rendering
	* 2D graphics (can make games)
* EFI Filesystem
	* Read-only filesystem
	* Files and directories
* Input/Output
	* Experimental mouse input
* Hardware RNG
	* Fallbacks to software RNG if hardware RNG fails

## API Reference

Automatically generated API Reference for the project can be found at https://landstander27.github.io/zig-efi-lib.
Note that Zig autodoc is in beta; the website may be broken or incomplete.

## Examples (Ordered by least-most difficult)
* [Hello World](examples/hello): Quick "Hello World" example.
* [Heap](examples/heap): Simple heap example.
* [Panic](examples/panic): Showcases how to use the optional panic handler.
* [Graphics](examples/graphics): Text and 2D graphics.
* [Advanced](examples/advanced): Skeleton for an "advanced" project.
* [Snake](examples/snake): A snake game. Showcases how to draw to screen with a framebuffer.
* **[AeroOS](https://github.com/LandStander27/AeroOS)**: Simple OS I created that originally gave me the idea for this project. Most of the code of this library is taken from here.

## FAQ
* When building with docker, why are the error messages not pretty?:
	* Instead of running `make docker`, run `make docker dockerflags="-it"`.