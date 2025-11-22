# Recipe 16.3: Managing Dependencies

## Problem

You need to use external libraries in your project and want to manage dependencies properly with Zig's package manager.

## Solution

Zig uses `build.zig.zon` files to declare dependencies. Create a manifest file in your project root:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_3/build.zig.zon:dependencies_manifest}}
```

Then reference the dependency in your `build.zig`:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_3/build.zig:using_dependencies}}
```

## Discussion

Zig's dependency management system is built directly into the build system. Dependencies are declared in `build.zig.zon` files using a structured format.

### Dependency Information

Each dependency needs basic metadata:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_3.zig:dependency_info}}
```

The hash field is critical - it's a SHA256 hash with a "1220" prefix (multihash format) that ensures dependency integrity. If the downloaded package doesn't match the hash, the build will fail.

### Version Constraints

You can specify version requirements:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_3.zig:version_constraint}}
```

Version constraints help ensure compatibility. You can specify a minimum version, or both minimum and maximum for more control.

### Module Imports

Dependencies expose modules that you import into your code:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_3.zig:module_import}}
```

The module name in your code can differ from the dependency name in `build.zig.zon`, giving you flexibility in how you organize imports.

### Dependency Graphs

Projects often have complex dependency relationships:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_3.zig:dependency_graph}}
```

Understanding the dependency graph helps avoid circular dependencies and minimize build times.

### Local Dependencies

For development or monorepo setups, use path-based dependencies:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_3.zig:local_dependency}}
```

Local dependencies are useful during development or when working with unpublished packages. They can be relative or absolute paths.

### Dependency Options

Pass build options to dependencies:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_3.zig:dependency_options}}
```

This allows dependencies to be built with the same optimization level and target as your main project, or with different settings if needed.

### Hash Verification

Zig verifies package integrity using cryptographic hashes:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_3.zig:hash_verification}}
```

The hash format uses multihash encoding:
- "12" = SHA256 algorithm
- "20" = 32 bytes (hex-encoded as 64 characters)
- Total: 68 characters including prefix

If you need to get the hash for a new dependency, Zig will tell you the correct hash when you first try to fetch it with the wrong hash.

### Transitive Dependencies

Dependencies can have their own dependencies:

```zig
{{#include ../../../code/05-zig-paradigms/16-zig-build-system/recipe_16_3.zig:transitive_dependencies}}
```

Zig handles transitive dependencies automatically. Your `build.zig.zon` only needs to list direct dependencies; their dependencies are resolved recursively.

## Best Practices

**Pin Exact Versions**: Use specific version tags or commit hashes instead of branches like `main` to ensure reproducible builds.

**Verify Hashes**: Always check that the hash in your `build.zig.zon` matches what you expect. Zig will error if hashes don't match, protecting against tampering.

**Use Local Paths During Development**: When actively developing a dependency, use a local path instead of fetching from a URL. Switch to URL-based dependencies before publishing.

**Minimize Dependencies**: Each dependency adds build time and maintenance burden. Only add dependencies when they provide clear value.

**Document Dependency Purposes**: Add comments in `build.zig.zon` explaining why each dependency is needed.

## Common Commands

```bash
# Zig will fetch dependencies automatically during build
zig build

# To update dependencies, remove the cache and rebuild
rm -rf ~/.cache/zig
zig build

# Get hash for a new dependency (intentionally use wrong hash first)
# Zig will show the correct hash in the error message
```

## See Also

- Recipe 16.1: Basic build.zig setup
- Recipe 16.2: Multiple executables and libraries
- Recipe 16.4: Custom build steps
- Recipe 16.6: Build options and configurations

Full compilable example: `code/05-zig-paradigms/16-zig-build-system/recipe_16_3.zig`
