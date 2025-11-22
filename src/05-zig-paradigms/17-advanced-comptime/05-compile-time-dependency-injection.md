# Recipe 17.5: Compile-Time Dependency Injection

## Problem

You need to manage dependencies between components without runtime overhead, reflection, or complex frameworks. You want the flexibility of dependency injection with the performance and safety guarantees of compile-time resolution.

## Solution

Zig's comptime system enables dependency injection that's resolved entirely at compilation. Pass types as parameters to create components that work with different implementations, all without runtime cost.

### Basic Interface Injection

Inject dependencies through type parameters:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_5.zig:basic_interface}}
```

### Configuration Injection

Inject configuration values at compile time:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_5.zig:configuration_injection}}
```

### Multiple Dependencies

Compose components from multiple injected types:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_5.zig:multi_dependency}}
```

### Trait-Based Injection

Verify dependencies meet interface requirements at compile time:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_5.zig:trait_based_injection}}
```

### Factory Pattern

Use factories to create components with injected dependencies:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_5.zig:factory_injection}}
```

### Context Objects

Bundle dependencies into context objects:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_5.zig:context_injection}}
```

### Strategy Pattern

Inject behavior through strategy objects:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_5.zig:strategy_injection}}
```

### Module Injection

Inject entire modules as dependencies:

```zig
{{#include ../../../code/05-zig-paradigms/17-advanced-comptime/recipe_17_5.zig:module_injection}}
```

## Discussion

Compile-time dependency injection in Zig provides the flexibility of traditional DI frameworks without any runtime overhead or complex machinery.

### How Compile-Time DI Works

Traditional dependency injection uses runtime reflection or containers to wire components together. Zig does this at compile time:

1. **Type Parameters**: Functions return types parameterized by dependency types
2. **Compile-Time Verification**: `@hasDecl` and type introspection ensure interfaces match
3. **Zero Runtime Cost**: All resolution happens during compilation
4. **Static Dispatch**: No vtables or function pointer indirection

The result is code that's as fast as hand-written, tightly-coupled code but with the flexibility of loosely-coupled architecture.

### Inversion of Control

Components depend on abstractions (type parameters) rather than concrete implementations:

```zig
fn Component(comptime Logger: type) type
```

This `Component` doesn't care what `Logger` is, just that it has the methods it needs. Swap implementations by changing the type parameter.

### Duck Typing with Safety

Zig uses structural typing for interfaces:

```zig
fn requiresLogger(comptime T: type) void {
    if (!@hasDecl(T, "log")) {
        @compileError("Type must implement log method");
    }
}
```

Types don't need to explicitly declare they implement an interface. If they have the required methods, they work. But unlike dynamic duck typing, this is verified at compile time.

### Configuration as Code

The configuration injection pattern embeds settings directly into types:

```zig
const App = ConfigurableApp(.{
    .debug_mode = true,
    .max_connections = 100,
});
```

These values are compile-time constants, allowing:
- Dead code elimination (debug code removed in release builds)
- Constant folding (comparisons optimized away)
- Type-level configuration (different types for different configs)

### Testing and Mocking

Compile-time DI makes testing straightforward:

1. Create mock implementations with the same interface
2. Inject mocks instead of real dependencies
3. No test framework magic needed
4. Test exactly the same code paths as production

Each test can use different mock types, creating completely separate test cases without runtime switches.

### Composition Patterns

**Single Dependency**: Simple type parameter for one dependency.

**Multiple Dependencies**: Multiple type parameters for complex components.

**Context Objects**: Bundle related dependencies together, pass one context instead of many individual types.

**Factory Pattern**: Hide construction logic, create complex dependency graphs.

**Strategy Pattern**: Inject algorithmic behavior, swap strategies by type.

### When to Use Each Pattern

**Basic Injection**: Simple cases with 1-2 dependencies. Clear and direct.

**Configuration**: When behavior changes based on build settings or environment.

**Context Objects**: Many dependencies (more than 3-4). Reduces parameter count.

**Factories**: Complex initialization logic or multi-step construction.

**Traits/Validation**: When you need to document or enforce interface contracts.

### Limitations

**No Runtime Polymorphism**: Each type parameter creates a distinct concrete type. Can't store different implementations in the same collection without wrapping.

**Compilation Time**: More type combinations mean more code generation and longer builds.

**Binary Size**: Each instantiation generates new code. Many instantiations can increase binary size.

**No Dynamic Loading**: All dependencies must be known at compile time. Can't load plugins at runtime without additional infrastructure.

### Workarounds for Limitations

**Runtime Polymorphism**: Use tagged unions or function pointers when you need it.

**Compilation Time**: Use aggressive caching, split into modules, or reduce instantiation diversity.

**Binary Size**: Share implementations through common base types or use inline functions.

**Dynamic Loading**: Combine comptime DI for known components with runtime DI for plugins.

### Best Practices

**Keep Interfaces Minimal**: Only require methods you actually use. Smaller interfaces mean more flexibility.

**Validate Early**: Use `@hasDecl` and assertions to catch interface mismatches at the injection point.

**Document Contracts**: Use comments or compile-time checks to document what dependencies must provide.

**Prefer Composition**: Build complex systems from simple, single-responsibility components.

**Test Boundaries**: Use DI at system boundaries (I/O, external services) rather than everywhere.

### Comparison to Other Languages

**Java/C# DI**: Runtime reflection, container-managed lifecycles, complex configuration. Zig: compile-time, no containers, simple and fast.

**C++ Templates**: Similar mechanics but Zig's comptime is more flexible and generates clearer errors.

**Go Interfaces**: Runtime type checking, vtable dispatch. Zig: compile-time checking, static dispatch.

### Performance Characteristics

Compile-time DI is zero-cost:

- No runtime type checks
- No vtable indirection
- No container overhead
- No reflection penalty
- Fully inlined and optimized

The generated code is indistinguishable from hand-written code that directly uses concrete types.

## See Also

- Recipe 17.1: Type-Level Pattern Matching
- Recipe 17.3: Compile-Time Assertion and Contract Validation
- Recipe 17.4: Generic Data Structure Generation
- Recipe 9.7: Defining decorators as structs

Full compilable example: `code/05-zig-paradigms/17-advanced-comptime/recipe_17_5.zig`
