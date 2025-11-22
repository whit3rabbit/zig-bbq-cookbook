# Recipe 17.6: Build-Time Resource Embedding

## Problem

You need to embed files, configuration data, or other resources directly into your binary. You want to process these resources at compile time, generate lookup tables, and eliminate runtime file I/O for bundled assets.

## Solution

Zig's `@embedFile` builtin reads files at compile time and embeds their contents as string literals in your binary. Combined with comptime processing, you can parse, transform, and optimize resources during compilation.

### Basic File Embedding

Embed text files directly into your program:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_6.zig:basic_embed}}
```

### Parse Configuration at Compile Time

Process embedded configuration files during compilation:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_6.zig:parse_at_comptime}}
```

### Generate Lookup Tables

Create lookup tables from embedded data:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_6.zig:lookup_table}}
```

### Hash at Compile Time

Compute checksums and hashes during compilation:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_6.zig:hash_at_comptime}}
```

### Resource Maps

Build resource managers at compile time:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_6.zig:resource_map}}
```

### Version Information

Embed version and build metadata:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_6.zig:version_info}}
```

### String Interning

Create compile-time string pools with efficient lookup:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_6.zig:string_interner}}
```

### Asset Compression

Compress embedded resources at compile time:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_6.zig:asset_compression}}
```

### Build Metadata

Capture build-time information:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_6.zig:build_metadata}}
```

## Discussion

Build-time resource embedding eliminates runtime file I/O, simplifies deployment, and enables powerful compile-time optimizations.

### How @embedFile Works

The `@embedFile` builtin:

1. Reads a file relative to the source file at compile time
2. Returns the contents as a `[]const u8` string literal
3. Embeds the data directly into the binary's read-only data section
4. Performs the read only once, even if called multiple times with the same path

The embedded data is available at runtime as a normal string slice, with zero I/O overhead.

### Path Resolution

File paths are resolved relative to the source file containing `@embedFile`:

```zig
// If in src/main.zig:
@embedFile("data.txt")        // Looks for src/data.txt
@embedFile("../assets/img.png") // Looks for assets/img.png
```

Use relative paths to keep builds reproducible and portable across different development environments.

### Compile-Time Processing

Once data is embedded, you can process it at compile time:

**Parsing**: Convert configuration formats (INI, JSON, custom formats) into native Zig types.

**Validation**: Check for errors, enforce schemas, and reject invalid data at compile time.

**Transformation**: Compress, encrypt, or encode data before embedding.

**Generation**: Create lookup tables, hash maps, or search trees from embedded data.

All processing happens once during compilation. The final binary contains only the processed result.

### The @setEvalBranchQuota Directive

Complex compile-time processing may exceed Zig's default evaluation limits:

```zig
@setEvalBranchQuota(10000);
```

This increases the number of branches the compiler will evaluate in comptime code. Use it when processing large files or complex transformations.

### Resource Management Patterns

**Direct Embedding**: Simple cases where you just need the raw data.

**Resource Maps**: Multiple resources accessed by name, using comptime-generated lookup.

**String Interning**: Deduplicate strings and use integer IDs for comparisons.

**Lazy Processing**: Embed raw data, process at runtime if transformation is too complex for comptime.

### Performance Characteristics

**Compile Time**:
- File I/O happens during compilation
- Processing time added to build time
- Large files or complex transformations increase compilation time

**Runtime**:
- Zero file I/O (data already in binary)
- No parsing overhead (pre-processed at compile time)
- Data lives in read-only memory (shared across processes)
- Fast access (just memory reads)

**Binary Size**:
- Embedded data increases binary size proportionally
- Compression can reduce size
- All embedded files are included even if unused (no tree-shaking)

### Use Cases

**Configuration**: Embed default configurations, removing runtime file dependencies.

**Templates**: HTML templates, SQL queries, or code generation templates.

**Assets**: Icons, small images, or other resources for GUIs.

**Localization**: Translation strings and language resources.

**Test Data**: Fixtures and expected outputs for testing.

**Version Info**: Git commit hashes, build timestamps, and version numbers.

### Limitations and Workarounds

**Large Files**: Very large embedded files slow compilation and increase binary size. Consider:
- Compressing at compile time
- Splitting into chunks
- Loading at runtime for truly large assets

**Dynamic Content**: `@embedFile` only works with files present at compile time. For user-provided files, use runtime I/O.

**Cross-Platform Paths**: Use forward slashes even on Windows. Zig normalizes paths automatically.

**Build Cache**: Zig's build cache doesn't track embedded file changes well. Clean rebuild if embedded files change unexpectedly.

### Best Practices

**Small Resources Only**: Embed configuration, templates, and small assets. Load large files at runtime.

**Version Control Assets**: Check embedded files into source control so builds are reproducible.

**Validate at Compile Time**: Catch errors early by parsing and validating during compilation.

**Document Embedded Files**: Comment what files are embedded and why.

**Use Compression**: For text-heavy resources, consider compile-time compression to reduce binary size.

**Cache Processed Results**: If processing is expensive, cache the result as a comptime constant.

### Integration with Build System

Combine `@embedFile` with build.zig to:

- Generate version information from git
- Embed timestamps and build metadata
- Process assets during the build
- Create different embeddings for different build configurations

### Security Considerations

**Sensitive Data**: Don't embed passwords, API keys, or secrets. They'll be visible in the binary.

**Input Validation**: Validate embedded files at compile time to prevent malformed data.

**Size Limits**: Set reasonable limits on embedded file sizes to prevent binary bloat.

**Read-Only**: Embedded data is in read-only memory. Don't try to modify it.

### Comparison to Other Approaches

**Runtime File I/O**:
- Pro: Smaller binaries, easier updates
- Con: File I/O overhead, deployment complexity

**Code Generation**:
- Pro: More flexible, can integrate with external tools
- Con: Additional build complexity, separate preprocessing step

**@embedFile**:
- Pro: Simple, integrated, zero runtime overhead
- Con: Increases binary size, compile-time processing only

## See Also

- Recipe 17.2: Compile-Time String Processing and Code Generation
- Recipe 17.3: Compile-Time Assertion and Contract Validation
- Recipe 16.4: Custom build steps
- Recipe 16.6: Build options and configurations

Full compilable example: `code/05-zig-paradigms/17-advanced-comptime/recipe_17_6.zig`
