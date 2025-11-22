## Problem

You need to understand when and how Zig's safety features protect your code, and when to disable them for performance. You want to catch bugs during development without paying for safety checks in production, and you need to handle edge cases like integer overflow, division by zero, and null pointers safely.

## Solution

Zig provides four build modes that balance safety and performance:

- **Debug**: Full safety checks, no optimizations (development)
- **ReleaseSafe**: Full safety checks, optimized code (production default)
- **ReleaseFast**: No safety checks, maximum speed (performance-critical)
- **ReleaseSmall**: No safety checks, minimum binary size (embedded systems)

Use compile-time detection to adapt behavior, and leverage explicit operators for overflow handling.

### Detecting Build Mode

Check the current build mode at compile time:

```zig
{{#include ../../code/01-foundation/recipe_1_5.zig:build_mode_detection}}
```

The `builtin.mode` constant is available at compile time, allowing code to adapt to the build configuration.

### Integer Overflow Detection

In Debug and ReleaseSafe modes, integer overflow causes a panic:

```zig
{{#include ../../code/01-foundation/recipe_1_5.zig:integer_overflow_safety}}
```

In Debug and ReleaseSafe, operations like `x + 1` on a maxed-out integer will panic. In ReleaseFast and ReleaseSmall, the value wraps around (undefined behavior).

## Discussion

### Intentional Wrapping with Special Operators

When overflow is intentional, use wrapping operators:

```zig
{{#include ../../code/01-foundation/recipe_1_5.zig:wrapping_arithmetic}}
```

Wrapping operators (`+%`, `-%`, `*%`, `+%=`) wrap in all build modes, making the behavior explicit and predictable.

### Saturating Arithmetic

Saturating operators clamp to minimum or maximum values instead of wrapping:

```zig
{{#include ../../code/01-foundation/recipe_1_5.zig:saturating_arithmetic}}
```

Use saturating operators (`+|`, `-|`) when you want to prevent overflow without wrapping or panicking.

### Array Bounds Checking

Array access is bounds-checked in Debug and ReleaseSafe:

```zig
{{#include ../../code/01-foundation/recipe_1_5.zig:bounds_checking}}
```

Accessing an array out of bounds panics in safe modes. Return an error instead for explicit handling.

### Null Pointer Safety

Optionals prevent null pointer dereference:

```zig
{{#include ../../code/01-foundation/recipe_1_5.zig:null_pointer_safety}}
```

The `?*T` type represents an optional pointer. Use `orelse` to handle the null case explicitly.

### Unreachable Code Paths

Mark code paths that should never execute:

```zig
{{#include ../../code/01-foundation/recipe_1_5.zig:unreachable_marker}}
```

The `unreachable` keyword tells the compiler a code path is impossible. In Debug and ReleaseSafe, hitting `unreachable` panics. In release modes, it's undefined behavior (but enables optimizations).

### Fine-Grained Runtime Safety Control

Use `@setRuntimeSafety` for scoped control:

```zig
{{#include ../../code/01-foundation/recipe_1_5.zig:runtime_safety_control}}
```

Use `@setRuntimeSafety(false)` in performance-critical hot loops after validation. Use `@setRuntimeSafety(true)` to enforce checks even in release builds.

### Debug Assertions

Use `std.debug.assert` for development-only checks:

```zig
{{#include ../../code/01-foundation/recipe_1_5.zig:assertion_checks}}
```

Debug assertions are completely removed from release builds, making them zero-cost for invariant checking during development.

### Explicit Overflow Detection

Use `@addWithOverflow` and `@mulWithOverflow` for explicit handling:

```zig
{{#include ../../code/01-foundation/recipe_1_5.zig:checked_arithmetic}}
```

These builtins return a tuple `[2]T` where `[0]` is the result and `[1]` is 1 if overflow occurred, 0 otherwise.

### Division by Zero

Division by zero is caught in Debug and ReleaseSafe:

```zig
{{#include ../../code/01-foundation/recipe_1_5.zig:division_by_zero}}
```

Always check for division by zero explicitly. In ReleaseFast and ReleaseSmall, dividing by zero is undefined behavior.

### Build Mode Characteristics

Each build mode optimizes for different goals:

| Mode | Safety Checks | Optimized | Size Optimized | Use Case |
|------|--------------|-----------|----------------|----------|
| **Debug** | Yes | No | No | Development, debugging |
| **ReleaseSafe** | Yes | Yes | No | Production default |
| **ReleaseFast** | No | Yes | No | Performance-critical |
| **ReleaseSmall** | No | Yes | Yes | Embedded systems |

**Debug**: Maximum safety, slow execution, large binaries
**ReleaseSafe**: Best default for production (safety + speed)
**ReleaseFast**: Maximum speed, no safety guarantees
**ReleaseSmall**: Minimum size, no safety guarantees

### When to Use Each Mode

**Development and Testing:**
- Use **Debug** for development and initial testing
- Catches bugs early with full safety checks
- Slower execution helps identify performance issues

**Production:**
- Use **ReleaseSafe** as the default for production
- Maintains safety checks with optimized code
- Best balance for most applications

**Performance-Critical:**
- Use **ReleaseFast** for hot paths after thorough testing
- Games, scientific computing, high-frequency trading
- Only after profiling shows safety checks are bottlenecks

**Resource-Constrained:**
- Use **ReleaseSmall** for embedded systems
- Microcontrollers, bootloaders, minimal environments
- When binary size matters more than speed

### Optimization Impact

Different modes produce different code:

```zig
{{#include ../../code/01-foundation/recipe_1_5.zig:optimization_levels}}
```

In Debug, the loop executes as written. In release modes, the compiler may unroll the loop, inline functions, or compute the factorial at compile time.

### Safety Recommendations

Follow these guidelines for safe code:

1. **Default to ReleaseSafe** for production builds
2. **Use explicit operators** for wrapping (`+%`) and saturating (`+|`) arithmetic
3. **Check for errors** instead of relying on panics (division by zero, bounds)
4. **Use debug assertions** for development-time invariants
5. **Profile before disabling safety** - only use ReleaseFast when proven necessary
6. **Use @setRuntimeSafety sparingly** - only in validated hot paths
7. **Mark impossible paths** with `unreachable` for optimization hints

### Testing Across Build Modes

Test your code in multiple build modes:

```bash
# Debug mode (default for zig test)
zig test recipe_1_5.zig

# ReleaseSafe mode
zig test recipe_1_5.zig -Doptimize=ReleaseSafe

# ReleaseFast mode
zig test recipe_1_5.zig -Doptimize=ReleaseFast

# ReleaseSmall mode
zig test recipe_1_5.zig -Doptimize=ReleaseSmall
```

Run tests in both Debug and ReleaseSafe to catch bugs that only appear with optimizations.

### Common Pitfalls

**Relying on panics in production:**
```zig
// Don't do this in production code:
fn badDivide(a: i32, b: i32) i32 {
    return a / b;  // Panics on b == 0 in safe modes
}

// Do this instead:
fn goodDivide(a: i32, b: i32) !i32 {
    if (b == 0) return error.DivisionByZero;
    return @divTrunc(a, b);
}
```

**Disabling safety prematurely:**
```zig
// Don't disable safety without profiling:
@setRuntimeSafety(false);  // Did you measure this?

// Profile first, then optimize hot paths only
```

**Assuming overflow wraps:**
```zig
// Wrong: assumes wrapping behavior
var x: u8 = 255;
x += 1;  // Panics in Debug/ReleaseSafe

// Right: explicit wrapping
var x: u8 = 255;
x +%= 1;  // Always wraps to 0
```

### Memory Safety

Zig's safety features extend beyond arithmetic:

- **No use-after-free**: Compile-time lifetime analysis
- **No double-free**: Single ownership or explicit reference counting
- **No null dereferences**: Optional types enforce handling
- **No buffer overflows**: Bounds checking in safe modes
- **No uninitialized reads**: Compiler enforces initialization

These guarantees make Zig suitable for systems programming without sacrificing safety.

## See Also

- Recipe 0.11: Optionals, Errors, and Resource Cleanup
- Recipe 1.1: Writing Idiomatic Zig Code
- Recipe 14.2: Using different build modes

Full compilable example: `code/01-foundation/recipe_1_5.zig`
