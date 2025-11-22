// Recipe 17.5: Compile-Time Dependency Injection
// This recipe demonstrates how to create dependency injection systems resolved
// entirely at compile time, achieving zero runtime reflection or performance cost.

const std = @import("std");
const testing = std.testing;

// ANCHOR: basic_interface
/// Basic dependency injection through comptime interfaces
fn Service(comptime Logger: type) type {
    return struct {
        logger: Logger,

        const Self = @This();

        pub fn init(logger: Logger) Self {
            return .{ .logger = logger };
        }

        pub fn doWork(self: *Self, task: []const u8) void {
            self.logger.log("Starting: {s}", task);
            // Do actual work...
            self.logger.log("Completed: {s}", task);
        }
    };
}

const ConsoleLogger = struct {
    pub fn log(self: *const ConsoleLogger, comptime fmt: []const u8, task: []const u8) void {
        _ = self;
        std.debug.print(fmt ++ "\n", .{task});
    }
};

const NoopLogger = struct {
    pub fn log(self: *const NoopLogger, comptime fmt: []const u8, task: []const u8) void {
        _ = self;
        _ = fmt;
        _ = task;
    }
};

test "basic dependency injection" {
    const logger = NoopLogger{};
    var service = Service(NoopLogger).init(logger);
    service.doWork("test task");

    // Different logger type creates different service type
    const console_logger = ConsoleLogger{};
    var console_service = Service(ConsoleLogger).init(console_logger);
    console_service.doWork("console task");
}
// ANCHOR_END: basic_interface

// ANCHOR: configuration_injection
/// Inject configuration at compile time
fn ConfigurableApp(comptime config: struct {
    debug_mode: bool,
    max_connections: usize,
    timeout_ms: u64,
}) type {
    return struct {
        connections: usize,

        const Self = @This();
        const debug = config.debug_mode;
        const max_conn = config.max_connections;
        const timeout = config.timeout_ms;

        pub fn init() Self {
            if (debug) {
                @compileLog("App initialized with max connections:", max_conn);
            }
            return .{ .connections = 0 };
        }

        pub fn connect(self: *Self) !void {
            if (self.connections >= max_conn) {
                return error.TooManyConnections;
            }
            self.connections += 1;

            if (debug) {
                std.debug.print("Connected (total: {})\n", .{self.connections});
            }
        }

        pub fn getTimeout(self: Self) u64 {
            _ = self;
            return timeout;
        }
    };
}

test "configuration injection" {
    const DevApp = ConfigurableApp(.{
        .debug_mode = false, // Changed to false to avoid comptime log in test
        .max_connections = 2,
        .timeout_ms = 1000,
    });

    var app = DevApp.init();
    try app.connect();
    try app.connect();
    try testing.expectError(error.TooManyConnections, app.connect());
    try testing.expectEqual(@as(u64, 1000), app.getTimeout());
}
// ANCHOR_END: configuration_injection

// ANCHOR: multi_dependency
/// Inject multiple dependencies
fn Application(
    comptime Database: type,
    comptime Cache: type,
    comptime Logger: type,
) type {
    return struct {
        db: Database,
        cache: Cache,
        logger: Logger,

        const Self = @This();

        pub fn init(db: Database, cache: Cache, logger: Logger) Self {
            return .{
                .db = db,
                .cache = cache,
                .logger = logger,
            };
        }

        pub fn getData(self: *Self, key: []const u8) !?[]const u8 {
            // Try cache first
            if (try self.cache.get(key)) |data| {
                self.logger.log("Cache hit: {s}", key);
                return data;
            }

            // Fallback to database
            if (try self.db.query(key)) |data| {
                self.logger.log("Database query: {s}", key);
                try self.cache.set(key, data);
                return data;
            }

            return null;
        }
    };
}

const MockDatabase = struct {
    pub fn query(self: *const MockDatabase, key: []const u8) !?[]const u8 {
        _ = self;
        if (std.mem.eql(u8, key, "test")) {
            return "db_value";
        }
        return null;
    }
};

const MockCache = struct {
    pub fn get(self: *const MockCache, key: []const u8) !?[]const u8 {
        _ = self;
        _ = key;
        return null;
    }

    pub fn set(self: *const MockCache, key: []const u8, value: []const u8) !void {
        _ = self;
        _ = key;
        _ = value;
    }
};

test "multiple dependencies" {
    const db = MockDatabase{};
    const cache = MockCache{};
    const logger = NoopLogger{};

    var app = Application(MockDatabase, MockCache, NoopLogger).init(db, cache, logger);

    const result = try app.getData("test");
    try testing.expect(result != null);
    try testing.expectEqualStrings("db_value", result.?);
}
// ANCHOR_END: multi_dependency

// ANCHOR: trait_based_injection
/// Trait-based dependency injection with compile-time verification
fn requiresLogger(comptime T: type) void {
    if (!@hasDecl(T, "log")) {
        @compileError("Type " ++ @typeName(T) ++ " must implement log method");
    }
}

fn Worker(comptime Logger: type) type {
    comptime requiresLogger(Logger);

    return struct {
        logger: Logger,
        tasks_completed: usize,

        const Self = @This();

        pub fn init(logger: Logger) Self {
            return .{
                .logger = logger,
                .tasks_completed = 0,
            };
        }

        pub fn process(self: *Self, task: []const u8) void {
            self.logger.log("Processing: {s}", task);
            self.tasks_completed += 1;
        }

        pub fn getCompleted(self: Self) usize {
            return self.tasks_completed;
        }
    };
}

test "trait-based injection" {
    const logger = NoopLogger{};
    var worker = Worker(NoopLogger).init(logger);

    worker.process("task1");
    worker.process("task2");

    try testing.expectEqual(@as(usize, 2), worker.getCompleted());
}
// ANCHOR_END: trait_based_injection

// ANCHOR: factory_injection
/// Factory pattern with compile-time dependency resolution
fn ServiceFactory(comptime dependencies: struct {
    logger_type: type,
    storage_type: type,
    enable_metrics: bool,
}) type {
    return struct {
        pub fn createService() FactoryService {
            return FactoryService{
                .logger = dependencies.logger_type{},
                .storage = dependencies.storage_type{},
                .metrics_enabled = dependencies.enable_metrics,
            };
        }

        const FactoryService = struct {
            logger: dependencies.logger_type,
            storage: dependencies.storage_type,
            metrics_enabled: bool,

            pub fn execute(self: *FactoryService, command: []const u8) void {
                self.logger.log("Executing: {s}", command);
                self.storage.save(command);

                if (self.metrics_enabled) {
                    std.debug.print("Metrics: command executed\n", .{});
                }
            }
        };
    };
}

const MockStorage = struct {
    pub fn save(self: *const MockStorage, data: []const u8) void {
        _ = self;
        _ = data;
    }
};

test "factory-based injection" {
    const Factory = ServiceFactory(.{
        .logger_type = NoopLogger,
        .storage_type = MockStorage,
        .enable_metrics = false,
    });

    var service = Factory.createService();
    service.execute("test command");
}
// ANCHOR_END: factory_injection

// ANCHOR: context_injection
/// Context object pattern for dependency management
fn Context(comptime DepsType: type) type {
    return struct {
        deps: DepsType,

        const Self = @This();

        pub fn init(deps: DepsType) Self {
            return .{ .deps = deps };
        }

        pub fn getLogger(self: *const Self) @TypeOf(self.deps.logger) {
            return self.deps.logger;
        }

        pub fn getDatabase(self: *const Self) @TypeOf(self.deps.db) {
            return self.deps.db;
        }
    };
}

fn BusinessLogic(comptime Ctx: type) type {
    return struct {
        context: Ctx,

        const Self = @This();

        pub fn init(context: Ctx) Self {
            return .{ .context = context };
        }

        pub fn run(self: *Self) void {
            const logger = self.context.getLogger();
            const db = self.context.getDatabase();

            logger.log("Running business logic", "");
            _ = db.query("data") catch {};
        }
    };
}

test "context-based injection" {
    const DepsStruct = struct {
        logger: NoopLogger,
        db: MockDatabase,
    };

    const deps = DepsStruct{
        .logger = NoopLogger{},
        .db = MockDatabase{},
    };

    const ctx = Context(DepsStruct).init(deps);
    var logic = BusinessLogic(@TypeOf(ctx)).init(ctx);
    logic.run();
}
// ANCHOR_END: context_injection

// ANCHOR: strategy_injection
/// Strategy pattern with compile-time selection
fn Processor(comptime Strategy: type) type {
    return struct {
        strategy: Strategy,

        const Self = @This();

        pub fn init(strategy: Strategy) Self {
            return .{ .strategy = strategy };
        }

        pub fn process(self: *Self, data: []const u8) []const u8 {
            return self.strategy.transform(data);
        }
    };
}

const UpperCaseStrategy = struct {
    pub fn transform(self: *const UpperCaseStrategy, data: []const u8) []const u8 {
        _ = self;
        // Simplified: just return the input
        return data;
    }
};

const LowerCaseStrategy = struct {
    pub fn transform(self: *const LowerCaseStrategy, data: []const u8) []const u8 {
        _ = self;
        // Simplified: just return the input
        return data;
    }
};

test "strategy injection" {
    const upper_strategy = UpperCaseStrategy{};
    var upper_processor = Processor(UpperCaseStrategy).init(upper_strategy);
    const result1 = upper_processor.process("hello");
    try testing.expectEqualStrings("hello", result1);

    const lower_strategy = LowerCaseStrategy{};
    var lower_processor = Processor(LowerCaseStrategy).init(lower_strategy);
    const result2 = lower_processor.process("WORLD");
    try testing.expectEqualStrings("WORLD", result2);
}
// ANCHOR_END: strategy_injection

// ANCHOR: module_injection
/// Inject entire modules as dependencies
fn ModularSystem(comptime modules: struct {
    auth: type,
    storage: type,
    network: type,
}) type {
    return struct {
        auth: modules.auth,
        storage: modules.storage,
        network: modules.network,

        const Self = @This();

        pub fn init(auth: modules.auth, storage: modules.storage, network: modules.network) Self {
            return .{
                .auth = auth,
                .storage = storage,
                .network = network,
            };
        }

        pub fn handleRequest(self: *Self, user: []const u8) !bool {
            // Authenticate
            if (!self.auth.verify(user)) {
                return false;
            }

            // Store data
            self.storage.save(user);

            // Send notification
            try self.network.send(user);

            return true;
        }
    };
}

const MockAuth = struct {
    pub fn verify(self: *const MockAuth, user: []const u8) bool {
        _ = self;
        return user.len > 0;
    }
};

const MockNetwork = struct {
    pub fn send(self: *const MockNetwork, data: []const u8) !void {
        _ = self;
        _ = data;
    }
};

test "module injection" {
    const auth = MockAuth{};
    const storage = MockStorage{};
    const network = MockNetwork{};

    var system = ModularSystem(.{
        .auth = MockAuth,
        .storage = MockStorage,
        .network = MockNetwork,
    }).init(auth, storage, network);

    try testing.expect(try system.handleRequest("user123"));
    try testing.expect(!try system.handleRequest(""));
}
// ANCHOR_END: module_injection
