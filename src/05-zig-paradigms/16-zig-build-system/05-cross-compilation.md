# Recipe 16.5: Cross-Compilation

## Problem

You need to build your Zig application for different operating systems and architectures without setting up multiple development environments.

## Solution

Zig makes cross-compilation trivial with built-in support for multiple targets. Configure your build.zig to support various platforms:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_5/build.zig:cross_compilation}}
```

## Discussion

One of Zig's standout features is zero-friction cross-compilation. Zig ships with cross-compilation toolchains for all supported targets, making it easy to build for any platform from any platform.

### Target Information

Targets are defined by architecture, OS, and ABI:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_5.zig:target_info}}
```

Common target combinations:
- `x86_64-linux-gnu` - 64-bit Linux with GNU libc
- `x86_64-linux-musl` - 64-bit Linux with musl libc
- `x86_64-windows-gnu` - 64-bit Windows with MinGW
- `aarch64-macos-none` - ARM64 macOS (Apple Silicon)
- `aarch64-linux-gnu` - ARM64 Linux
- `wasm32-freestanding-musl` - WebAssembly

### Cross-Compilation Configuration

Configure cross-compilation builds:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_5.zig:cross_compile_config}}
```

Each cross-compilation target can have its own optimization level, strip settings, and other build options.

### Target Queries

Filter and select targets programmatically:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_5.zig:target_query}}
```

Target queries help when building for multiple platforms. You might want to:
- Build only for specific architectures (e.g., all ARM targets)
- Build only for specific operating systems (e.g., all Linux variants)
- Exclude certain combinations (e.g., skip 32-bit targets)

### Platform Features

Different platforms support different CPU features:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_5.zig:platform_features}}
```

CPU features affect performance and compatibility:
- **x86_64**: SSE, SSE2, SSE4, AVX, AVX2, AVX512
- **ARM**: NEON, SVE, crypto extensions
- **WebAssembly**: SIMD, threads, atomics

Zig lets you specify baseline CPU features and target specific CPU models.

### Parsing Target Triples

Work with target triple strings:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_5.zig:target_triple_parsing}}
```

Target triples follow the format: `<arch>-<os>-<abi>`. Some examples:
- `x86_64-linux-gnu`
- `aarch64-macos-none`
- `riscv64-linux-musl`
- `wasm32-wasi-musl`

### Build Matrix

Build for multiple targets and optimization levels:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_5.zig:build_matrix}}
```

Build matrices are common in CI/CD pipelines. You might want to test all combinations of:
- Targets (Linux, Windows, macOS)
- Architectures (x86_64, aarch64)
- Optimization levels (Debug, ReleaseFast, ReleaseSmall)

### Native Platform Detection

Detect the current platform at compile time:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_5.zig:native_detection}}
```

Use `builtin` to access compile-time platform information:
- `builtin.cpu.arch` - CPU architecture
- `builtin.os.tag` - Operating system
- `builtin.abi` - ABI/calling convention
- `builtin.mode` - Optimization mode

## Command Line Usage

Cross-compile from the command line using `-Dtarget`:

```bash
# Linux x86_64
zig build -Dtarget=x86_64-linux-gnu

# Windows x86_64
zig build -Dtarget=x86_64-windows-gnu

# macOS ARM64 (Apple Silicon)
zig build -Dtarget=aarch64-macos

# Linux ARM64
zig build -Dtarget=aarch64-linux-gnu

# WebAssembly
zig build -Dtarget=wasm32-wasi

# With optimization
zig build -Dtarget=x86_64-windows-gnu -Doptimize=ReleaseFast

# Using custom steps from our build.zig
zig build linux-x64
zig build windows-x64
zig build macos-arm
zig build all-targets
```

## Listing Available Targets

See all supported targets:

```bash
# List all available targets
zig targets

# List supported architectures
zig targets | jq '.cpus'

# List supported operating systems
zig targets | jq '.os'
```

The output is JSON with complete information about:
- Supported CPUs and architectures
- Available operating systems
- ABI options
- CPU features per architecture

## Best Practices

**Test on Real Hardware**: Cross-compilation makes it easy to build for other platforms, but always test on real hardware before deploying. Emulators like QEMU help but don't catch everything.

**Match Your ABI**: Use `gnu` ABI for compatibility with most Linux systems. Use `musl` for static binaries. On Windows, `gnu` (MinGW) is usually the right choice.

**Consider Static Linking**: When cross-compiling for Linux, consider musl libc for true static binaries that run anywhere. Use `-Dtarget=x86_64-linux-musl`.

**CPU Feature Baseline**: Be conservative with CPU features. If targeting broad compatibility, don't enable advanced features like AVX512 that aren't universally available.

**Strip Debug Symbols**: For release builds, strip debug symbols to reduce binary size: `-Doptimize=ReleaseFast` already does this.

**WebAssembly Specifics**: When targeting WASM, use `wasm32-wasi` for command-line tools or `wasm32-freestanding` for embedded/browser use.

## Common Target Combinations

**Linux Server (portable)**:
```bash
zig build -Dtarget=x86_64-linux-musl -Doptimize=ReleaseFast
```

**Windows Desktop**:
```bash
zig build -Dtarget=x86_64-windows-gnu -Doptimize=ReleaseFast
```

**macOS Universal (Intel + ARM)**:
```bash
# Build both and use lipo to combine
zig build -Dtarget=x86_64-macos
zig build -Dtarget=aarch64-macos
lipo -create -output myapp zig-out/bin/myapp-x86_64 zig-out/bin/myapp-aarch64
```

**Embedded Linux (Raspberry Pi)**:
```bash
zig build -Dtarget=aarch64-linux-gnu -Doptimize=ReleaseSmall
```

**Static Binary (any Linux)**:
```bash
zig build -Dtarget=x86_64-linux-musl -Doptimize=ReleaseFast
```

## Troubleshooting

**"unable to find dynamic system library"**: You need platform-specific headers. Install cross-compilation toolchain or use static linking.

**Different behavior on cross-compiled binary**: Check endianness, pointer size, and platform-specific system calls. Use `@compileError` to catch unsupported features.

**Large binary sizes**: Use `-Doptimize=ReleaseSmall` and consider stripping symbols. WebAssembly binaries especially benefit from this.

## See Also

- Recipe 16.1: Basic build.zig setup
- Recipe 16.2: Multiple executables and libraries
- Recipe 16.6: Build options and configurations

Full compilable example: `code/05-zig-paradigms/16-zig-build-system/recipe_16_5.zig`
