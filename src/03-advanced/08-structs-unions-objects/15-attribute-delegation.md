## Problem

You want to delegate method calls or attribute access from one object to another, implementing patterns like proxies, wrappers, or forwarding without inheritance.

## Solution

Use composition with explicit delegation methods to forward calls to embedded structs. Zig's composition-over-inheritance approach makes delegation explicit and type-safe.

### Basic Delegation

Delegate engine operations to a car:

```zig
{{#include ../../../code/03-advanced/08-structs-unions-objects/recipe_8_15.zig:basic_delegation}}
    }
};
```

The car delegates engine-related operations while adding its own functionality.

### Transparent Proxy

Add metrics tracking to an existing data store:

```zig
const CachedDataStore = struct {
    store: DataStore,
    cache_hits: u32,
    cache_misses: u32,

    pub fn get(self: *CachedDataStore, key: []const u8) ?[]const u8 {
        const result = self.store.get(key);
        if (result != null) {
            self.cache_hits += 1;
        } else {
            self.cache_misses += 1;
        }
        return result;
    }

    pub fn put(self: *CachedDataStore, key: []const u8, value: []const u8) !void {
        try self.store.put(key, value);
    }

    pub fn getCacheStats(self: *const CachedDataStore) struct { hits: u32, misses: u32 } {
        return .{ .hits = self.cache_hits, .misses = self.cache_misses };
    }
};
```

The proxy forwards all operations while collecting statistics.

### Property Forwarding

Forward dimensional properties from a box:

```zig
const Box = struct {
    dimensions: Dimensions,
    material: []const u8,

    pub fn getWidth(self: *const Box) f32 {
        return self.dimensions.width;
    }

    pub fn getHeight(self: *const Box) f32 {
        return self.dimensions.height;
    }

    pub fn getVolume(self: *const Box) f32 {
        return self.dimensions.getVolume();
    }
};
```

The box provides convenient access to embedded dimension data.

### Selective Delegation

Only expose safe operations:

```zig
const ReadOnlyFileSystem = struct {
    // Only expose read operation
    pub fn read(path: []const u8) ![]const u8 {
        return FileSystem.read(path);
    }

    // write and delete are not exposed
};
```

This creates a restricted interface by selectively delegating operations.

### Logging Wrapper

Wrap operations with logging:

```zig
const LoggedDatabase = struct {
    db: Database,
    query_log: std.ArrayList([]const u8),
    allocator: std.mem.Allocator,

    pub fn query(self: *LoggedDatabase, sql: []const u8) !void {
        try self.query_log.append(self.allocator, sql);
        try self.db.query(sql);
    }

    pub fn getQueryLog(self: *const LoggedDatabase) []const []const u8 {
        return self.query_log.items;
    }
};
```

Every operation is logged before being delegated.

### Chain Delegation

Create layers of delegation:

```zig
const CompressedEncryptedNetwork = struct {
    encrypted: EncryptedNetwork,

    pub fn send(self: *CompressedEncryptedNetwork, data: []const u8) void {
        // Compress data
        const compressed_size = data.len / 2;
        const compressed_data = data[0..compressed_size];

        // Delegate to encrypted layer
        self.encrypted.send(compressed_data);
    }
};
```

Each layer adds functionality and delegates to the next.

### Dynamic Delegation

Use interfaces for runtime delegation:

```zig
const Writer = struct {
    ptr: *anyopaque,
    writeFn: *const fn (ptr: *anyopaque, data: []const u8) anyerror!void,

    pub fn write(self: Writer, data: []const u8) !void {
        return self.writeFn(self.ptr, data);
    }
};

const DelegatingWriter = struct {
    writer: Writer,

    pub fn writeLine(self: *DelegatingWriter, line: []const u8) !void {
        try self.writer.write(line);
        try self.writer.write("\n");
    }
};
```

The delegation target can be determined at runtime.

### Mixin-Style Delegation

Add capabilities using generic wrappers:

```zig
fn WithLogging(comptime T: type) type {
    return struct {
        inner: T,
        log_count: u32,

        pub fn call(self: *Self) void {
            self.log_count += 1;
            if (@hasDecl(T, "call")) {
                self.inner.call();
            }
        }

        pub fn getLogCount(self: *const Self) u32 {
            return self.log_count;
        }
    };
}

const service = SimpleService.init();
var logged = WithLogging(SimpleService).init(service);
logged.call();  // Logged and delegated
```

Mixins wrap any type that supports the required interface.

### Conditional Delegation

Only delegate if certain conditions are met:

```zig
const SafeCalculator = struct {
    calculator: Calculator,
    overflow_occurred: bool,

    pub fn add(self: *SafeCalculator, value: f64) void {
        const new_result = self.calculator.result + value;
        if (std.math.isInf(new_result) or std.math.isNan(new_result)) {
            self.overflow_occurred = true;
        } else {
            self.calculator.add(value);
        }
    }

    pub fn getResult(self: *const SafeCalculator) ?f64 {
        if (self.overflow_occurred) return null;
        return self.calculator.getResult();
    }
};
```

Delegation happens only when the operation is safe.

### Lazy Delegation

Create the delegate only when needed:

```zig
const LazyProxy = struct {
    resource: ?HeavyResource,
    initialization_count: u32,

    pub fn getData(self: *LazyProxy) []const u8 {
        if (self.resource == null) {
            self.resource = HeavyResource.init();
            self.initialization_count += 1;
        }
        return self.resource.?.getData();
    }
};
```

Expensive resources are created on first access.

## Discussion

Delegation in Zig is explicit and compile-time verified, unlike dynamic languages where delegation can happen implicitly.

### Delegation Patterns

**Composition**: Embed the delegate as a field
- Most common pattern
- Type-safe and explicit
- Zero runtime overhead

**Forwarding**: Write methods that call delegate methods
- Full control over interface
- Can modify arguments or results
- Can add validation or logging

**Selective exposure**: Only delegate some methods
- Create restricted interfaces
- Enforce access control
- Hide dangerous operations

**Chain of responsibility**: Multiple delegation layers
- Each layer adds functionality
- Order matters
- Common in middleware patterns

### Delegation vs Inheritance

Zig doesn't have inheritance, so delegation is the primary code reuse mechanism:

**Advantages**:
- More flexible—can change delegates at runtime
- Explicit—always clear what's happening
- Composable—combine multiple delegates
- No fragile base class problem

**Trade-offs**:
- More verbose—must write forwarding methods
- No automatic method forwarding
- Cannot override delegate methods

### Performance

All static delegation patterns have zero overhead:

```zig
pub fn start(self: *Car) void {
    self.engine.start();  // Inlined to direct call
}
```

The compiler optimizes away the forwarding entirely.

Dynamic delegation through interfaces has one pointer indirection:

```zig
pub fn write(self: Writer, data: []const u8) !void {
    return self.writeFn(self.ptr, data);  // One function pointer call
}
```

### Design Guidelines

**Use delegation when**:
- You want to reuse behavior
- You need to wrap or extend functionality
- You want to control access to another object
- You need runtime polymorphism

**Use composition directly when**:
- You only access a few fields
- No method forwarding needed
- The relationship is "has-a" not "is-a"

**Use interfaces when**:
- Delegate type unknown at compile time
- Need runtime polymorphism
- Plugin or extensibility systems

### Common Use Cases

**Proxy pattern**: Control access to objects
- Security, caching, lazy loading
- Add metrics or logging
- Network or IPC proxies

**Decorator pattern**: Add responsibilities
- Logging, encryption, compression
- Validation, authorization
- Performance tracking

**Adapter pattern**: Convert interfaces
- Wrap legacy code
- Match incompatible interfaces
- Provide simplified facades

## See Also

- Recipe 8.7: Calling a Method on a Parent Class
- Recipe 8.12: Defining an Interface or Abstract Base Class
- Recipe 8.13: Implementing a Data Model or Type System
- Recipe 9.11: Using comptime to Control Instance Creation

Full compilable example: `code/03-advanced/08-structs-unions-objects/recipe_8_15.zig`
