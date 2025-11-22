## Problem

You want to hide internal implementation details and expose only a clean public interface for your struct.

## Solution

Use the `pub` keyword to make fields and functions public, and omit it to keep them private:

```zig
{{#include ../../../code/03-advanced/08-structs-unions-objects/recipe_8_5.zig:basic_encapsulation}}
```

## Discussion

### Public vs Private Fields

Fields without `pub` are private to the defining file:

```zig
const BankAccount = struct {
    balance: f64,        // Private - cannot access from other files
    account_number: []const u8,  // Private

    pub const Currency = enum { USD, EUR, GBP };  // Public constant

    pub fn init(account_number: []const u8) BankAccount {
        return BankAccount{
            .balance = 0.0,
            .account_number = account_number,
        };
    }

    pub fn deposit(self: *BankAccount, amount: f64) !void {
        if (amount <= 0) return error.InvalidAmount;
        self.balance += amount;
    }

    pub fn getBalance(self: *const BankAccount) f64 {
        return self.balance;
    }

    fn validateBalance(self: *const BankAccount) bool {
        return self.balance >= 0;
    }
};

test "bank account encapsulation" {
    var account = BankAccount.init("ACC-12345");

    try account.deposit(100.50);
    try std.testing.expectEqual(@as(f64, 100.50), account.getBalance());

    // Private fields accessible within same file
    try std.testing.expect(account.validateBalance());
}
```

### Struct-Level Privacy

Control visibility at different levels:

```zig
// Private struct - only visible in this file
const InternalCache = struct {
    data: [100]u8,
    size: usize,
};

// Public struct
pub const DataStore = struct {
    // Private field
    cache: InternalCache,

    // Public field (accessible since struct is pub)
    name: []const u8,

    // Private initialization
    fn initCache() InternalCache {
        return InternalCache{
            .data = undefined,
            .size = 0,
        };
    }

    // Public initialization
    pub fn init(name: []const u8) DataStore {
        return DataStore{
            .cache = initCache(),
            .name = name,
        };
    }
};

test "struct-level privacy" {
    const store = DataStore.init("MyStore");
    try std.testing.expectEqualStrings("MyStore", store.name);
}
```

### Read-Only Properties Pattern

Provide read access but prevent direct modification:

```zig
const Timer = struct {
    start_time: i64,
    elapsed: i64,

    pub fn init(start_time: i64) Timer {
        return Timer{
            .start_time = start_time,
            .elapsed = 0,
        };
    }

    pub fn getStartTime(self: *const Timer) i64 {
        return self.start_time;
    }

    pub fn getElapsed(self: *const Timer) i64 {
        return self.elapsed;
    }

    pub fn update(self: *Timer, current_time: i64) void {
        self.elapsed = current_time - self.start_time;
    }
};

test "read-only properties" {
    var timer = Timer.init(1000);
    timer.update(1500);

    try std.testing.expectEqual(@as(i64, 1000), timer.getStartTime());
    try std.testing.expectEqual(@as(i64, 500), timer.getElapsed());
}
```

### Builder Pattern with Validation

Hide internal state during construction:

```zig
const Config = struct {
    host: []const u8,
    port: u16,
    timeout_ms: u32,
    validated: bool,

    pub const Builder = struct {
        host: ?[]const u8,
        port: u16,
        timeout_ms: u32,

        pub fn init() Builder {
            return Builder{
                .host = null,
                .port = 8080,
                .timeout_ms = 5000,
            };
        }

        pub fn setHost(self: *Builder, host: []const u8) *Builder {
            self.host = host;
            return self;
        }

        pub fn setPort(self: *Builder, port: u16) *Builder {
            self.port = port;
            return self;
        }

        pub fn setTimeout(self: *Builder, ms: u32) *Builder {
            self.timeout_ms = ms;
            return self;
        }

        pub fn build(self: *const Builder) !Config {
            if (self.host == null) return error.HostRequired;

            return Config{
                .host = self.host.?,
                .port = self.port,
                .timeout_ms = self.timeout_ms,
                .validated = true,
            };
        }
    };

    pub fn getHost(self: *const Config) []const u8 {
        return self.host;
    }
};

test "builder pattern" {
    var builder = Config.Builder.init();
    const config = try builder
        .setHost("localhost")
        .setPort(3000)
        .build();

    try std.testing.expectEqualStrings("localhost", config.getHost());
    try std.testing.expectEqual(@as(u16, 3000), config.port);
}
```

### Module-Level Encapsulation

Organize related functionality:

```zig
pub const Database = struct {
    const Self = @This();

    connection: Connection,

    const Connection = struct {
        handle: i32,
        is_open: bool,

        fn open(url: []const u8) !Connection {
            _ = url;
            return Connection{
                .handle = 42,
                .is_open = true,
            };
        }

        fn close(self: *Connection) void {
            self.is_open = false;
        }
    };

    pub fn init(url: []const u8) !Self {
        const conn = try Connection.open(url);
        return Self{ .connection = conn };
    }

    pub fn deinit(self: *Self) void {
        self.connection.close();
    }

    pub fn execute(self: *Self, query: []const u8) !void {
        _ = self;
        _ = query;
        // Execute query
    }
};

test "module encapsulation" {
    var db = try Database.init("postgresql://localhost");
    defer db.deinit();

    try db.execute("SELECT * FROM users");
}
```

### State Machine with Private States

Hide internal state transitions:

```zig
const StateMachine = struct {
    const State = enum {
        idle,
        running,
        paused,
        stopped,
    };

    current_state: State,
    transition_count: u32,

    pub fn init() StateMachine {
        return StateMachine{
            .current_state = .idle,
            .transition_count = 0,
        };
    }

    pub fn start(self: *StateMachine) !void {
        if (self.current_state != .idle) return error.InvalidTransition;
        self.transition(.running);
    }

    pub fn pause(self: *StateMachine) !void {
        if (self.current_state != .running) return error.InvalidTransition;
        self.transition(.paused);
    }

    pub fn resumeRunning(self: *StateMachine) !void {
        if (self.current_state != .paused) return error.InvalidTransition;
        self.transition(.running);
    }

    pub fn stop(self: *StateMachine) !void {
        self.transition(.stopped);
    }

    pub fn isRunning(self: *const StateMachine) bool {
        return self.current_state == .running;
    }

    fn transition(self: *StateMachine, new_state: State) void {
        self.current_state = new_state;
        self.transition_count += 1;
    }
};

test "state machine" {
    var sm = StateMachine.init();

    try sm.start();
    try std.testing.expect(sm.isRunning());

    try sm.pause();
    try std.testing.expect(!sm.isRunning());

    try sm.resumeRunning();
    try std.testing.expect(sm.isRunning());
}
```

### Opaque Handles

Hide implementation completely:

```zig
pub const Handle = opaque {
    pub fn create() *Handle {
        const impl = Implementation{
            .data = 42,
            .refs = 1,
        };
        const ptr = std.heap.page_allocator.create(Implementation) catch unreachable;
        ptr.* = impl;
        return @ptrCast(ptr);
    }

    pub fn destroy(handle: *Handle) void {
        const impl: *Implementation = @ptrCast(@alignCast(handle));
        std.heap.page_allocator.destroy(impl);
    }

    pub fn getValue(handle: *Handle) i32 {
        const impl: *Implementation = @ptrCast(@alignCast(handle));
        return impl.data;
    }

    const Implementation = struct {
        data: i32,
        refs: u32,
    };
};

test "opaque handle" {
    const handle = Handle.create();
    defer Handle.destroy(handle);

    const value = Handle.getValue(handle);
    try std.testing.expectEqual(@as(i32, 42), value);
}
```

### Interface Pattern

Define public interface with private implementation:

```zig
pub const Logger = struct {
    const Self = @This();

    vtable: *const VTable,
    ptr: *anyopaque,

    pub const VTable = struct {
        log: *const fn (ptr: *anyopaque, msg: []const u8) void,
    };

    pub fn log(self: Self, msg: []const u8) void {
        self.vtable.log(self.ptr, msg);
    }
};

const ConsoleLogger = struct {
    prefix: []const u8,

    fn log(ptr: *anyopaque, msg: []const u8) void {
        const self: *ConsoleLogger = @ptrCast(@alignCast(ptr));
        std.debug.print("[{s}] {s}\n", .{ self.prefix, msg });
    }

    const vtable = Logger.VTable{
        .log = log,
    };

    pub fn logger(self: *ConsoleLogger) Logger {
        return Logger{
            .vtable = &vtable,
            .ptr = self,
        };
    }
};

test "interface pattern" {
    var console = ConsoleLogger{ .prefix = "INFO" };
    const logger = console.logger();

    logger.log("Test message");
}
```

### Best Practices

**Default to Private:**
```zig
// Good: Only expose what's necessary
pub const Widget = struct {
    id: u32,          // Private
    state: State,     // Private

    pub fn getId(self: *const Widget) u32 {
        return self.id;
    }
};
```

**Document Public API:**
```zig
/// Represents a thread-safe counter
pub const Counter = struct {
    /// Get the current count
    pub fn get(self: *const Counter) i32 {
        return self.value;
    }

    value: i32,  // Implementation detail
};
```

**Consistent Naming:**
```zig
pub const Resource = struct {
    // Public methods use clear names
    pub fn create() !Resource { }
    pub fn destroy(self: *Resource) void { }

    // Private helpers use descriptive names
    fn allocateBuffer(size: usize) ![]u8 { }
    fn validateInput(data: []const u8) bool { }
};
```

**Separate Interface from Implementation:**
```zig
// Public interface
pub const API = struct {
    pub fn processData(data: []const u8) !Result { }
};

// Private implementation details
const Implementation = struct {
    fn parseData(data: []const u8) !ParsedData { }
    fn validateData(parsed: *const ParsedData) !void { }
};
```

### Related Patterns

- Recipe 8.6: Creating managed attributes (getters/setters)
- Recipe 8.12: Defining an interface
- Recipe 10.2: Controlling symbol export
