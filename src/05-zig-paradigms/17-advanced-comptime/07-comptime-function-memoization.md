# Recipe 17.7: Comptime Function Memoization and Optimization

## Problem

You have expensive computations that are called repeatedly with the same inputs, or you need to optimize code paths based on compile-time information. You want to cache results, generate lookup tables, and create optimization hints without any runtime overhead.

## Solution

Zig's comptime system enables you to perform computations once at compile time and embed the results directly into your binary as lookup tables or pre-computed constants.

### Basic Memoization

Cache expensive recursive computations at compile time:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_7.zig:basic_memoization}}
```

### Precomputed Lookup Tables

Generate complete lookup tables for O(1) runtime access:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_7.zig:precompute_table}}
```

### Cached Prime Numbers

Compute and cache prime numbers at build time:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_7.zig:prime_cache}}
```

### Factorial Table

Precompute factorials for instant lookup:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_7.zig:factorial_table}}
```

### String Hash Table

Precompute hashes for fast string comparisons:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_7.zig:string_hash_table}}
```

### Powers of Two

Cache powers of 2 for bit manipulation:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_7.zig:power_of_two}}
```

### Trigonometric Tables

Precompute sine values for fast approximations:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_7.zig:sin_table}}
```

### Generic Memoization Wrapper

Create reusable memoization helpers:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_7.zig:memoized_generic}}
```

### Build-Time Optimization Selection

Choose implementations based on compile-time analysis:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_7.zig:build_time_optimization}}
```

## Discussion

Comptime memoization transforms expensive computations into instant lookups, moving work from runtime to compile time for dramatic performance improvements.

### How Comptime Caching Works

When you compute values at compile time, Zig:

1. Executes the computation during compilation
2. Stores the result in the binary's data section
3. Replaces function calls with direct array lookups or constants
4. Eliminates the computation logic from the final binary

The result is runtime code that's as fast as if you'd manually typed in the pre-computed values.

### Lookup Table Strategy

**Small Input Domain**: Generate complete tables for all possible inputs (powers of 2, small factorials, trigonometric functions).

**Sparse Tables**: For functions with selective interesting inputs (primes, Fibonacci numbers), cache only the values you need.

**Approximation Tables**: Use finite precision for continuous functions (sin/cos), trading accuracy for speed.

### Memory vs Speed Tradeoff

Lookup tables trade memory for speed:

**Benefits**:
- O(1) runtime lookup instead of O(n) or O(log n) computation
- No branches or function call overhead
- Cache-friendly linear memory access
- Predictable performance

**Costs**:
- Increased binary size
- Memory used even for unused values
- Less flexible than computed results

Choose tables when:
- The input domain is small
- The computation is expensive
- Speed is more important than memory
- The values are frequently accessed

### The @setEvalBranchQuota Directive

Zig limits compile-time computation to prevent infinite loops:

```zig
@setEvalBranchQuota(100000);
```

This increases the branch evaluation limit. Use it for:
- Large table generation
- Complex compile-time algorithms
- Iterative processing of embedded data

Set it as high as needed but be aware that very high values can slow compilation.

### Optimization Patterns

**Direct Memoization**: Fibonacci example shows basic caching with intermediate results.

**Full Table Generation**: Powers of 2, factorials—generate every possible value upfront.

**Filtered Generation**: Primes—only store values matching a criteria.

**Approximation**: Sine table—finite precision for continuous functions.

**Compile-Time Selection**: Choose algorithm based on problem size or type characteristics.

### Generic Memoization

The `Memoized` wrapper demonstrates creating reusable caching helpers:

```zig
const Cached = Memoized(@TypeOf(expensiveFunc), expensiveFunc, max_n);
```

This pattern:
- Works with any function signature
- Generates specialized caches per function
- Provides type-safe lookups
- Eliminates boilerplate

### Practical Applications

**Game Development**: Precompute damage tables, XP curves, or procedural generation parameters.

**Graphics**: Sine/cosine tables for rotations, gamma correction lookup tables.

**Cryptography**: S-boxes, permutation tables, modular arithmetic tables.

**Compression**: Huffman code tables, dictionary entries.

**String Processing**: Hash tables for keywords, character classification tables.

**Math Libraries**: Logarithms, square roots, or other transcendental functions with limited precision.

### Compilation Impact

**Build Time**: Table generation happens during compilation, increasing build time proportional to table size and complexity.

**Build Cache**: Tables are cached between builds, so only the first compilation or changes to input data trigger regeneration.

**Incremental Builds**: Tables in unchanged files don't need recomputation.

### Performance Characteristics

**Compile Time**:
- Linear in table size for simple functions
- Exponential for recursive algorithms without memoization
- Memory-bound for very large tables

**Runtime**:
- O(1) lookup for all cached values
- No computation overhead
- No stack frames or function calls
- Ideal cache locality

**Binary Size**:
- Proportional to table size
- Aligned and padded per platform ABI
- Shared across all uses

### Debugging Comptime Code

When compile-time computation fails:

1. Use `@compileLog` to print intermediate values
2. Reduce table sizes for faster iteration
3. Check `@setEvalBranchQuota` is sufficient
4. Verify no runtime dependencies in comptime code
5. Test the logic with runtime functions first

### Best Practices

**Start Small**: Begin with small table sizes, verify correctness, then scale up.

**Document Tables**: Explain what each table contains, its range, and precision.

**Validate Inputs**: For functions taking indices, check bounds and provide clear errors.

**Consider Compression**: For sparse tables, use maps instead of arrays.

**Profile First**: Measure whether the overhead justifies the memory cost.

**Version Carefully**: Document table format if persisting across versions.

### Limitations

**Static Input**: Can only compute for values known at compile time.

**Memory Constraints**: Very large tables can exhaust compilation memory or create huge binaries.

**Precision Loss**: Approximation tables sacrifice accuracy for speed.

**Cold Start**: Table access may miss cache on first use.

### When Not to Use

**Dynamic Inputs**: Runtime values can't benefit from compile-time tables.

**Rarely Used**: If a value is only accessed once, computing it on-demand is cheaper.

**Large Domains**: Tables for 64-bit integers would be terabytes.

**Frequently Changing**: If the computation logic changes often, runtime flexibility may be better.

## See Also

- Recipe 17.2: Compile-Time String Processing and Code Generation
- Recipe 17.4: Generic Data Structure Generation
- Recipe 17.6: Build-Time Resource Embedding
- Recipe 16.6: Build options and configurations

Full compilable example: `code/05-zig-paradigms/17-advanced-comptime/recipe_17_7.zig`
