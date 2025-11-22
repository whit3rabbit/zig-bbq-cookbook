// Recipe 8.5: Encapsulating Names in a Struct
// Target Zig Version: 0.15.2

const std = @import("std");

// ANCHOR: basic_encapsulation
// Basic encapsulation
const Counter = struct {
    value: i32,

    pub fn init() Counter {
        return Counter{ .value = 0 };
    }

    pub fn increment(self: *Counter) void {
        self.value += 1;
    }

    pub fn get(self: *const Counter) i32 {
        return self.value;
    }
};
// ANCHOR_END: basic_encapsulation

test "basic encapsulation" {
    var counter = Counter.init();
    counter.increment();
    counter.increment();

    try std.testing.expectEqual(@as(i32, 2), counter.get());
    try std.testing.expectEqual(@as(i32, 2), counter.value);
}

// Bank account with private fields
const BankAccount = struct {
    balance: f64,
    account_number: []const u8,

    pub const Currency = enum { USD, EUR, GBP };

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
    try std.testing.expect(account.validateBalance());
}

// Struct-level privacy
const InternalCache = struct {
    data: [100]u8,
    size: usize,
};

pub const DataStore = struct {
    cache: InternalCache,
    name: []const u8,

    fn initCache() InternalCache {
        return InternalCache{
            .data = undefined,
            .size = 0,
        };
    }

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

// Read-only properties
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

// ANCHOR: builder_pattern
// Builder pattern
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
// ANCHOR_END: builder_pattern

test "builder pattern" {
    var builder = Config.Builder.init();
    const config = try builder
        .setHost("localhost")
        .setPort(3000)
        .build();

    try std.testing.expectEqualStrings("localhost", config.getHost());
    try std.testing.expectEqual(@as(u16, 3000), config.port);
}

// Module-level encapsulation
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
    }
};

test "module encapsulation" {
    var db = try Database.init("postgresql://localhost");
    defer db.deinit();

    try db.execute("SELECT * FROM users");
}

// State machine with private states
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

// ANCHOR: opaque_handle
// Opaque handle
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
// ANCHOR_END: opaque_handle

test "opaque handle" {
    const handle = Handle.create();
    defer Handle.destroy(handle);

    const value = Handle.getValue(handle);
    try std.testing.expectEqual(@as(i32, 42), value);
}

// Interface pattern
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
        _ = self;
        _ = msg;
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

// Comprehensive test
test "comprehensive encapsulation" {
    var counter = Counter.init();
    counter.increment();
    try std.testing.expectEqual(@as(i32, 1), counter.get());

    var account = BankAccount.init("TEST");
    try account.deposit(50.0);
    try std.testing.expectEqual(@as(f64, 50.0), account.getBalance());

    var timer = Timer.init(100);
    timer.update(200);
    try std.testing.expectEqual(@as(i64, 100), timer.getElapsed());
}
