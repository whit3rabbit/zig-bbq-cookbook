# Recipe 15.4: Managing Opaque Types in C Extensions

## Problem

You want to hide implementation details from C code while providing a clean API, preventing C callers from depending on internal structure layout.

## Solution

Use Zig's `opaque` type to create handles that hide implementation details. This provides encapsulation and ABI stability.

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_4.zig:basic_opaque}}
```

## Discussion

### Why Opaque Types?

Opaque types provide several benefits:
- **Encapsulation**: Hide implementation details from C callers
- **ABI Stability**: Change internal structure without breaking C code
- **Type Safety**: Handles are type-checked, preventing misuse
- **Memory Safety**: Control all allocation and deallocation

### Basic Pattern

The standard pattern for opaque handles:

1. Declare an opaque type for C
2. Define an internal implementation struct
3. Cast between the types in exported functions
4. Provide create/destroy functions for lifecycle management

### File Handle Example

A more complete example with state management:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_4.zig:opaque_with_state}}
```

### Iterator Pattern

Opaque types work well for iterators:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_4.zig:opaque_iterator}}
```

This pattern provides:
- Clean iteration API for C
- Hidden state management
- Safe cleanup

### Collection Types

Build collection data structures with opaque handles:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_4.zig:opaque_collection}}
```

### Resource Management

Manage pools of resources using opaque types:

```zig
{{#include ../../../code/04-specialized/15-c-interoperability/recipe_15_4.zig:opaque_resource_manager}}
```

### Design Patterns

**Factory Pattern:**
```zig
export fn thing_create(params...) ?*Thing {
    // Allocate and initialize
    return @ptrCast(impl);
}
```

**Destructor Pattern:**
```zig
export fn thing_destroy(thing: ?*Thing) void {
    if (thing) |t| {
        // Cleanup and deallocate
    }
}
```

**Accessor Pattern:**
```zig
export fn thing_get_value(thing: ?*const Thing) ReturnType {
    const impl: *const ThingImpl = @ptrCast(@alignCast(thing orelse return default));
    return impl.value;
}
```

**Mutator Pattern:**
```zig
export fn thing_set_value(thing: ?*Thing, value: ValueType) bool {
    const impl: *ThingImpl = @ptrCast(@alignCast(thing orelse return false));
    impl.value = value;
    return true;
}
```

### Memory Management

Always use `std.heap.c_allocator` for opaque types:

```zig
const allocator = std.heap.c_allocator;
const impl = allocator.create(ThingImpl) catch return null;
// ...later...
allocator.destroy(impl);
```

This ensures memory allocated in Zig can be safely freed, and matches C's expectations.

### NULL Safety

Always check for NULL before dereferencing:

```zig
export fn thing_process(thing: ?*Thing) bool {
    const impl: *ThingImpl = @ptrCast(@alignCast(thing orelse return false));
    // Safe to use impl here
}
```

### Type Casting

The standard casting pattern:

```zig
// Mutable access
const impl: *ThingImpl = @ptrCast(@alignCast(opaque_ptr));

// Const access
const impl: *const ThingImpl = @ptrCast(@alignCast(opaque_ptr));
```

### Error Handling

Since opaque types are used with C, follow C conventions:

```zig
// Return NULL on creation failure
export fn thing_create() ?*Thing {
    const impl = allocator.create(ThingImpl) catch return null;
    // ...
}

// Return bool for success/failure
export fn thing_operation(thing: ?*Thing) bool {
    const impl: *ThingImpl = @ptrCast(@alignCast(thing orelse return false));
    // ... operation ...
    return true;  // or false on error
}

// Return error codes
export fn thing_process(thing: ?*Thing) c_int {
    if (thing == null) return -1;
    // ...
    return 0;  // Success
}
```

### Best Practices

1. **Always Validate**: Check for NULL before casting
2. **Clear Ownership**: Document who creates and destroys handles
3. **Consistent Naming**: Use `create`/`destroy` naming convention
4. **Return NULL on Failure**: Creation functions should return NULL when they fail
5. **Use Const**: Mark read-only operations with `const` pointers
6. **Document Lifecycle**: Clearly specify object lifetime expectations
7. **Thread Safety**: Document if handles are thread-safe
8. **Resource Cleanup**: Always provide a destroy function

### Common Pitfalls

**Double Free:**
```zig
// BAD: Don't let C code free memory directly
// GOOD: Provide a destroy function
export fn thing_destroy(thing: ?*Thing) void {
    // Handle cleanup properly
}
```

**Dangling Pointers:**
```zig
// BAD: Returning pointers to stack memory
// GOOD: Allocate on heap, return handle
```

**Missing NULL Checks:**
```zig
// BAD: Assuming pointer is valid
// GOOD: Always check for NULL
const impl: *ThingImpl = @ptrCast(@alignCast(thing orelse return false));
```

## See Also

- Recipe 15.2: Writing a Zig Library Callable from C
- Recipe 15.3: Passing Arrays Between C and Zig
- Recipe 15.7: Managing Memory Across the C/Zig Boundary

Full compilable example: `code/04-specialized/15-c-interoperability/recipe_15_4.zig`
