# Chapter 19: WebAssembly and Freestanding Targets

WebAssembly (WASM) is a binary instruction format that runs in web browsers and other environments at near-native speed. Zig excels at targeting WebAssembly because it requires no runtime, has explicit memory management, and produces small, efficient binaries.

This chapter covers building WebAssembly modules with Zig, bridging between Zig and JavaScript, and handling the constraints of freestanding environments.

## What You'll Learn

- Compiling Zig to WebAssembly modules
- Exporting Zig functions for JavaScript to call
- Importing JavaScript functions into Zig
- Passing data between Zig and JavaScript via linear memory
- Managing memory in freestanding environments
- Implementing custom panic handlers for WASM

## Freestanding Targets

The `wasm32-freestanding` target means your code runs without an operating system. This has important implications:

- No standard I/O (no `std.io.getStdOut()`)
- No filesystem access
- No system allocator
- You must implement your own panic handler
- Limited standard library functionality

These constraints require explicit handling, which this chapter demonstrates through practical recipes.

## Target Audience

This chapter assumes you're comfortable with:
- Basic Zig programming (see Phase 0: Zig Bootcamp)
- Memory management and allocators (Recipe 0.12)
- Basic JavaScript and web development
- Understanding of how WebAssembly fits in web applications

## Getting Started

All recipes in this chapter use the `wasm32-freestanding` target and can be built with:

```bash
zig build-lib -O ReleaseSmall -target wasm32-freestanding -dynamic -rdynamic src/main.zig
```

The `-rdynamic` flag ensures exported symbols remain visible to JavaScript, and `-O ReleaseSmall` optimizes for small binary size, critical for web distribution.
