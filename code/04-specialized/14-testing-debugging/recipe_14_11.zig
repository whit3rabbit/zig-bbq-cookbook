const std = @import("std");
const testing = std.testing;

// ANCHOR: basic_debug_warning
fn processValue(value: i32) i32 {
    if (value < 0) {
        std.debug.print("Warning: Negative value {d} will be treated as zero\n", .{value});
        return 0;
    }
    if (value > 100) {
        std.debug.print("Warning: Value {d} exceeds maximum, capping at 100\n", .{value});
        return 100;
    }
    return value;
}

test "basic debug warnings" {
    try testing.expectEqual(@as(i32, 0), processValue(-10));
    try testing.expectEqual(@as(i32, 100), processValue(200));
    try testing.expectEqual(@as(i32, 50), processValue(50));
}
// ANCHOR_END: basic_debug_warning

// ANCHOR: structured_logging
const log = std.log.scoped(.cookbook);

fn validateInput(value: i32) i32 {
    if (value < 0) {
        log.warn("Invalid negative value: {d}", .{value});
        return 0;
    }
    if (value > 1000) {
        log.warn("Value {d} exceeds safe limit of 1000", .{value});
        return 1000;
    }
    log.info("Validated value: {d}", .{value});
    return value;
}

test "structured logging warnings" {
    try testing.expectEqual(@as(i32, 0), validateInput(-5));
    try testing.expectEqual(@as(i32, 1000), validateInput(5000));
    try testing.expectEqual(@as(i32, 500), validateInput(500));
}
// ANCHOR_END: structured_logging

// ANCHOR: warning_with_context
const WarningContext = struct {
    file: []const u8,
    line: usize,
    message: []const u8,

    fn warn(self: WarningContext) void {
        std.debug.print("[WARNING] {s}:{d} - {s}\n", .{ self.file, self.line, self.message });
    }
};

fn riskyOperation(value: i32) i32 {
    if (value == 0) {
        const ctx = WarningContext{
            .file = "recipe_14_11.zig",
            .line = 54,
            .message = "Division by zero prevented",
        };
        ctx.warn();
        return 1;
    }
    return @divTrunc(100, value);
}

test "warnings with context" {
    try testing.expectEqual(@as(i32, 1), riskyOperation(0));
    try testing.expectEqual(@as(i32, 10), riskyOperation(10));
}
// ANCHOR_END: warning_with_context

// ANCHOR: warning_levels
const WarningLevel = enum {
    info,
    warning,
    critical,

    fn emit(self: WarningLevel, message: []const u8) void {
        const prefix = switch (self) {
            .info => "INFO",
            .warning => "WARNING",
            .critical => "CRITICAL",
        };
        std.debug.print("[{s}] {s}\n", .{ prefix, message });
    }
};

fn checkStatus(status: u8) u8 {
    switch (status) {
        0...50 => WarningLevel.critical.emit("Status critically low"),
        51...80 => WarningLevel.warning.emit("Status below optimal"),
        81...100 => WarningLevel.info.emit("Status normal"),
        else => WarningLevel.critical.emit("Status out of range"),
    }
    return status;
}

test "warning levels" {
    _ = checkStatus(30);
    _ = checkStatus(70);
    _ = checkStatus(90);
    _ = checkStatus(150);
}
// ANCHOR_END: warning_levels

// ANCHOR: conditional_warnings
const Config = struct {
    verbose: bool,
    debug: bool,

    fn warn(self: Config, comptime level: []const u8, comptime fmt: []const u8, args: anytype) void {
        if (std.mem.eql(u8, level, "debug") and !self.debug) return;
        if (!self.verbose and std.mem.eql(u8, level, "info")) return;

        std.debug.print("[{s}] ", .{level});
        std.debug.print(fmt ++ "\n", args);
    }
};

fn processWithConfig(config: Config, value: i32) i32 {
    config.warn("debug", "Processing value: {d}", .{value});

    if (value < 0) {
        config.warn("warning", "Negative value detected: {d}", .{value});
        return 0;
    }

    config.warn("info", "Processing completed successfully", .{});
    return value;
}

test "conditional warnings based on config" {
    const quiet_config = Config{ .verbose = false, .debug = false };
    const verbose_config = Config{ .verbose = true, .debug = true };

    try testing.expectEqual(@as(i32, 0), processWithConfig(quiet_config, -5));
    try testing.expectEqual(@as(i32, 42), processWithConfig(verbose_config, 42));
}
// ANCHOR_END: conditional_warnings

// ANCHOR: deprecation_warnings
fn oldFunction(value: i32) i32 {
    std.debug.print("WARNING: oldFunction() is deprecated, use newFunction() instead\n", .{});
    return value * 2;
}

fn newFunction(value: i32) i32 {
    return value * 2;
}

test "deprecation warnings" {
    try testing.expectEqual(@as(i32, 20), oldFunction(10));
    try testing.expectEqual(@as(i32, 20), newFunction(10));
}
// ANCHOR_END: deprecation_warnings

// ANCHOR: warning_accumulator
const WarningAccumulator = struct {
    warnings: std.ArrayList([]const u8),
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator) WarningAccumulator {
        return .{
            .warnings = std.ArrayList([]const u8){},
            .allocator = allocator,
        };
    }

    fn deinit(self: *WarningAccumulator) void {
        for (self.warnings.items) |warning| {
            self.allocator.free(warning);
        }
        self.warnings.deinit(self.allocator);
    }

    fn add(self: *WarningAccumulator, comptime fmt: []const u8, args: anytype) !void {
        const message = try std.fmt.allocPrint(self.allocator, fmt, args);
        try self.warnings.append(self.allocator, message);
    }

    fn printAll(self: *const WarningAccumulator) void {
        for (self.warnings.items, 0..) |warning, i| {
            std.debug.print("Warning {d}: {s}\n", .{ i + 1, warning });
        }
    }

    fn count(self: *const WarningAccumulator) usize {
        return self.warnings.items.len;
    }
};

fn validateData(data: []const i32, accumulator: *WarningAccumulator) !void {
    for (data, 0..) |value, i| {
        if (value < 0) {
            try accumulator.add("Negative value at index {d}: {d}", .{ i, value });
        }
        if (value > 100) {
            try accumulator.add("Excessive value at index {d}: {d}", .{ i, value });
        }
    }
}

test "accumulate warnings" {
    var accumulator = WarningAccumulator.init(testing.allocator);
    defer accumulator.deinit();

    const data = [_]i32{ 50, -10, 200, 30, -5 };
    try validateData(&data, &accumulator);

    try testing.expectEqual(@as(usize, 3), accumulator.count());
}
// ANCHOR_END: warning_accumulator

// ANCHOR: warning_callback
const WarningHandler = struct {
    callback: *const fn ([]const u8) void,

    fn emit(self: WarningHandler, message: []const u8) void {
        self.callback(message);
    }
};

fn defaultWarningHandler(message: []const u8) void {
    std.debug.print("[DEFAULT] {s}\n", .{message});
}

fn customWarningHandler(message: []const u8) void {
    std.debug.print("[CUSTOM] WARNING: {s}\n", .{message});
}

fn processWithHandler(value: i32, handler: WarningHandler) i32 {
    if (value < 0) {
        handler.emit("Negative value detected");
        return 0;
    }
    return value;
}

test "warning callbacks" {
    const default_handler = WarningHandler{ .callback = &defaultWarningHandler };
    const custom_handler = WarningHandler{ .callback = &customWarningHandler };

    try testing.expectEqual(@as(i32, 0), processWithHandler(-5, default_handler));
    try testing.expectEqual(@as(i32, 0), processWithHandler(-10, custom_handler));
    try testing.expectEqual(@as(i32, 42), processWithHandler(42, default_handler));
}
// ANCHOR_END: warning_callback

// ANCHOR: warning_categories
const WarningCategory = enum {
    security,
    performance,
    compatibility,
    deprecation,

    fn emit(self: WarningCategory, message: []const u8) void {
        const category_name = @tagName(self);
        std.debug.print("[{s}] {s}\n", .{ category_name, message });
    }
};

fn analyzeCode(code: []const u8) void {
    if (std.mem.indexOf(u8, code, "unsafe") != null) {
        WarningCategory.security.emit("Unsafe operation detected");
    }
    if (std.mem.indexOf(u8, code, "deprecated") != null) {
        WarningCategory.deprecation.emit("Deprecated API usage");
    }
    if (std.mem.indexOf(u8, code, "slow") != null) {
        WarningCategory.performance.emit("Potentially slow operation");
    }
}

test "categorized warnings" {
    analyzeCode("unsafe operation here");
    analyzeCode("using deprecated function");
    analyzeCode("slow algorithm detected");
}
// ANCHOR_END: warning_categories

// ANCHOR: runtime_assertions
fn assertValid(value: i32, min: i32, max: i32) i32 {
    if (value < min) {
        std.debug.print("Assertion: value {d} below minimum {d}\n", .{ value, min });
        return min;
    }
    if (value > max) {
        std.debug.print("Assertion: value {d} above maximum {d}\n", .{ value, max });
        return max;
    }
    return value;
}

test "runtime assertions with warnings" {
    try testing.expectEqual(@as(i32, 0), assertValid(-10, 0, 100));
    try testing.expectEqual(@as(i32, 100), assertValid(200, 0, 100));
    try testing.expectEqual(@as(i32, 50), assertValid(50, 0, 100));
}
// ANCHOR_END: runtime_assertions

// ANCHOR: warning_suppression
const SuppressedWarnings = std.EnumSet(WarningCategory);

fn processWithSuppression(code: []const u8, suppressed: SuppressedWarnings) void {
    if (std.mem.indexOf(u8, code, "unsafe") != null) {
        if (!suppressed.contains(.security)) {
            WarningCategory.security.emit("Unsafe operation");
        }
    }
    if (std.mem.indexOf(u8, code, "deprecated") != null) {
        if (!suppressed.contains(.deprecation)) {
            WarningCategory.deprecation.emit("Deprecated usage");
        }
    }
}

test "warning suppression" {
    var suppressed = SuppressedWarnings.initEmpty();
    suppressed.insert(.security);

    processWithSuppression("unsafe code", suppressed); // No warning
    processWithSuppression("deprecated code", suppressed); // Warning emitted
}
// ANCHOR_END: warning_suppression
