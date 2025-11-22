// Recipe 8.10: Using Lazily Computed Properties
// Target Zig Version: 0.15.2

const std = @import("std");
const testing = std.testing;

// ANCHOR: basic_lazy_optional
// Basic lazy evaluation with optional
const ExpensiveCalculation = struct {
    input: i32,
    result: ?i32,

    pub fn init(input: i32) ExpensiveCalculation {
        return ExpensiveCalculation{
            .input = input,
            .result = null,
        };
    }

    pub fn getResult(self: *ExpensiveCalculation) i32 {
        if (self.result) |cached| {
            return cached;
        }

        // Expensive computation
        const computed = self.input * self.input + self.input * 2 + 1;
        self.result = computed;
        return computed;
    }

    pub fn invalidate(self: *ExpensiveCalculation) void {
        self.result = null;
    }
};
// ANCHOR_END: basic_lazy_optional

test "basic lazy optional" {
    var calc = ExpensiveCalculation.init(10);

    try testing.expect(calc.result == null);

    const result1 = calc.getResult();
    try testing.expectEqual(@as(i32, 121), result1);
    try testing.expect(calc.result != null);

    const result2 = calc.getResult();
    try testing.expectEqual(result1, result2);

    calc.invalidate();
    try testing.expect(calc.result == null);
}

// ANCHOR: lazy_with_allocator
// Lazy initialization with allocator
const LazyString = struct {
    allocator: std.mem.Allocator,
    cached: ?[]u8,
    generator_called: u32,

    pub fn init(allocator: std.mem.Allocator) LazyString {
        return LazyString{
            .allocator = allocator,
            .cached = null,
            .generator_called = 0,
        };
    }

    pub fn deinit(self: *LazyString) void {
        if (self.cached) |data| {
            self.allocator.free(data);
        }
    }

    pub fn getValue(self: *LazyString) ![]const u8 {
        if (self.cached) |data| {
            return data;
        }

        // Expensive generation
        self.generator_called += 1;
        const generated = try std.fmt.allocPrint(
            self.allocator,
            "Generated value #{d}",
            .{self.generator_called},
        );
        self.cached = generated;
        return generated;
    }

    pub fn reset(self: *LazyString) void {
        if (self.cached) |data| {
            self.allocator.free(data);
            self.cached = null;
        }
    }
};
// ANCHOR_END: lazy_with_allocator

test "lazy with allocator" {
    var lazy = LazyString.init(testing.allocator);
    defer lazy.deinit();

    const value1 = try lazy.getValue();
    try testing.expectEqualStrings("Generated value #1", value1);
    try testing.expectEqual(@as(u32, 1), lazy.generator_called);

    const value2 = try lazy.getValue();
    try testing.expectEqualStrings("Generated value #1", value2);
    try testing.expectEqual(@as(u32, 1), lazy.generator_called);

    lazy.reset();
    const value3 = try lazy.getValue();
    try testing.expectEqualStrings("Generated value #2", value3);
}

// ANCHOR: cached_computed
// Cached computed properties
const Rectangle = struct {
    width: f32,
    height: f32,
    cached_area: ?f32,
    cached_perimeter: ?f32,

    pub fn init(width: f32, height: f32) Rectangle {
        return Rectangle{
            .width = width,
            .height = height,
            .cached_area = null,
            .cached_perimeter = null,
        };
    }

    pub fn getArea(self: *Rectangle) f32 {
        if (self.cached_area) |area| {
            return area;
        }

        const area = self.width * self.height;
        self.cached_area = area;
        return area;
    }

    pub fn getPerimeter(self: *Rectangle) f32 {
        if (self.cached_perimeter) |perim| {
            return perim;
        }

        const perim = 2 * (self.width + self.height);
        self.cached_perimeter = perim;
        return perim;
    }

    pub fn setWidth(self: *Rectangle, width: f32) void {
        self.width = width;
        self.invalidateCache();
    }

    pub fn setHeight(self: *Rectangle, height: f32) void {
        self.height = height;
        self.invalidateCache();
    }

    fn invalidateCache(self: *Rectangle) void {
        self.cached_area = null;
        self.cached_perimeter = null;
    }
};
// ANCHOR_END: cached_computed

test "cached computed" {
    var rect = Rectangle.init(5, 10);

    try testing.expectEqual(@as(f32, 50), rect.getArea());
    try testing.expect(rect.cached_area != null);

    try testing.expectEqual(@as(f32, 30), rect.getPerimeter());
    try testing.expect(rect.cached_perimeter != null);

    rect.setWidth(10);
    try testing.expect(rect.cached_area == null);

    try testing.expectEqual(@as(f32, 100), rect.getArea());
}

// ANCHOR: lazy_file_load
// Lazy loading from external source
const ConfigFile = struct {
    path: []const u8,
    content: ?[]u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, path: []const u8) ConfigFile {
        return ConfigFile{
            .path = path,
            .content = null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ConfigFile) void {
        if (self.content) |data| {
            self.allocator.free(data);
        }
    }

    pub fn getContent(self: *ConfigFile) ![]const u8 {
        if (self.content) |data| {
            return data;
        }

        // Simulate file loading
        const loaded = try self.allocator.dupe(u8, "config data from file");
        self.content = loaded;
        return loaded;
    }

    pub fn reload(self: *ConfigFile) !void {
        if (self.content) |data| {
            self.allocator.free(data);
        }
        self.content = null;
        _ = try self.getContent();
    }
};
// ANCHOR_END: lazy_file_load

test "lazy file load" {
    var config = ConfigFile.init(testing.allocator, "/etc/config.txt");
    defer config.deinit();

    const content1 = try config.getContent();
    try testing.expectEqualStrings("config data from file", content1);

    const content2 = try config.getContent();
    try testing.expectEqual(content1.ptr, content2.ptr);

    try config.reload();
}

// ANCHOR: conditional_lazy
// Conditional lazy evaluation
const ConditionalCache = struct {
    enabled: bool,
    value: ?i32,
    compute_count: u32,

    pub fn init(enabled: bool) ConditionalCache {
        return ConditionalCache{
            .enabled = enabled,
            .value = null,
            .compute_count = 0,
        };
    }

    pub fn getValue(self: *ConditionalCache, input: i32) i32 {
        if (!self.enabled) {
            // Always compute when caching disabled
            return self.compute(input);
        }

        if (self.value) |cached| {
            return cached;
        }

        const result = self.compute(input);
        self.value = result;
        return result;
    }

    fn compute(self: *ConditionalCache, input: i32) i32 {
        self.compute_count += 1;
        return input * input;
    }

    pub fn setEnabled(self: *ConditionalCache, enabled: bool) void {
        self.enabled = enabled;
        if (!enabled) {
            self.value = null;
        }
    }
};
// ANCHOR_END: conditional_lazy

test "conditional lazy" {
    var cache_on = ConditionalCache.init(true);
    _ = cache_on.getValue(5);
    _ = cache_on.getValue(5);
    try testing.expectEqual(@as(u32, 1), cache_on.compute_count);

    var cache_off = ConditionalCache.init(false);
    _ = cache_off.getValue(5);
    _ = cache_off.getValue(5);
    try testing.expectEqual(@as(u32, 2), cache_off.compute_count);
}

// ANCHOR: dependency_lazy
// Multiple dependency lazy properties
const DataModel = struct {
    raw_data: []const i32,
    filtered: ?[]i32,
    sorted: ?[]i32,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, data: []const i32) DataModel {
        return DataModel{
            .raw_data = data,
            .filtered = null,
            .sorted = null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *DataModel) void {
        if (self.filtered) |f| self.allocator.free(f);
        if (self.sorted) |s| self.allocator.free(s);
    }

    pub fn getFiltered(self: *DataModel) ![]const i32 {
        if (self.filtered) |cached| {
            return cached;
        }

        // Filter out negative numbers
        var result = std.ArrayList(i32){};
        for (self.raw_data) |value| {
            if (value >= 0) {
                try result.append(self.allocator, value);
            }
        }

        const filtered = try result.toOwnedSlice(self.allocator);
        self.filtered = filtered;
        return filtered;
    }

    pub fn getSorted(self: *DataModel) ![]const i32 {
        if (self.sorted) |cached| {
            return cached;
        }

        // Depends on filtered data
        const filtered = try self.getFiltered();
        const sorted = try self.allocator.dupe(i32, filtered);
        std.mem.sort(i32, sorted, {}, comptime std.sort.asc(i32));

        self.sorted = sorted;
        return sorted;
    }

    pub fn invalidate(self: *DataModel) void {
        if (self.filtered) |f| {
            self.allocator.free(f);
            self.filtered = null;
        }
        if (self.sorted) |s| {
            self.allocator.free(s);
            self.sorted = null;
        }
    }
};
// ANCHOR_END: dependency_lazy

test "dependency lazy" {
    const data = [_]i32{ 3, -1, 5, -2, 1, 4 };
    var model = DataModel.init(testing.allocator, &data);
    defer model.deinit();

    const filtered = try model.getFiltered();
    try testing.expectEqual(@as(usize, 4), filtered.len);

    const sorted = try model.getSorted();
    try testing.expectEqual(@as(usize, 4), sorted.len);
    try testing.expectEqual(@as(i32, 1), sorted[0]);
    try testing.expectEqual(@as(i32, 5), sorted[3]);
}

// ANCHOR: lazy_generic
// Generic lazy wrapper
fn Lazy(comptime T: type) type {
    return struct {
        value: ?T,
        generator: *const fn () T,

        const Self = @This();

        pub fn init(generator: *const fn () T) Self {
            return Self{
                .value = null,
                .generator = generator,
            };
        }

        pub fn get(self: *Self) T {
            if (self.value) |cached| {
                return cached;
            }

            const computed = self.generator();
            self.value = computed;
            return computed;
        }

        pub fn invalidate(self: *Self) void {
            self.value = null;
        }

        pub fn isComputed(self: *const Self) bool {
            return self.value != null;
        }
    };
}

fn generateNumber() i32 {
    return 42;
}
// ANCHOR_END: lazy_generic

test "lazy generic" {
    var lazy = Lazy(i32).init(&generateNumber);

    try testing.expect(!lazy.isComputed());

    const value1 = lazy.get();
    try testing.expectEqual(@as(i32, 42), value1);
    try testing.expect(lazy.isComputed());

    lazy.invalidate();
    try testing.expect(!lazy.isComputed());
}

// ANCHOR: time_based_invalidation
// Time-based cache invalidation
const TimedCache = struct {
    value: ?[]const u8,
    computed_at: i64,
    ttl_seconds: i64,

    pub fn init(ttl_seconds: i64) TimedCache {
        return TimedCache{
            .value = null,
            .computed_at = 0,
            .ttl_seconds = ttl_seconds,
        };
    }

    pub fn getValue(self: *TimedCache, current_time: i64) []const u8 {
        if (self.value) |cached| {
            if (current_time - self.computed_at < self.ttl_seconds) {
                return cached;
            }
        }

        // Generate new value
        const generated = "fresh value";
        self.value = generated;
        self.computed_at = current_time;
        return generated;
    }

    pub fn isValid(self: *const TimedCache, current_time: i64) bool {
        if (self.value == null) return false;
        return current_time - self.computed_at < self.ttl_seconds;
    }
};
// ANCHOR_END: time_based_invalidation

test "time-based invalidation" {
    var cache = TimedCache.init(100);

    const value1 = cache.getValue(1000);
    try testing.expectEqualStrings("fresh value", value1);
    try testing.expect(cache.isValid(1050));

    const value2 = cache.getValue(1050);
    try testing.expectEqual(value1.ptr, value2.ptr);

    try testing.expect(!cache.isValid(1200));
}

// ANCHOR: memoization
// Memoization pattern
const Fibonacci = struct {
    cache: [100]?u64,

    pub fn init() Fibonacci {
        return Fibonacci{
            .cache = [_]?u64{null} ** 100,
        };
    }

    pub fn compute(self: *Fibonacci, n: usize) u64 {
        if (n < 2) return n;

        if (n < self.cache.len) {
            if (self.cache[n]) |cached| {
                return cached;
            }
        }

        const result = self.compute(n - 1) + self.compute(n - 2);

        if (n < self.cache.len) {
            self.cache[n] = result;
        }

        return result;
    }
};
// ANCHOR_END: memoization

test "memoization" {
    var fib = Fibonacci.init();

    try testing.expectEqual(@as(u64, 0), fib.compute(0));
    try testing.expectEqual(@as(u64, 1), fib.compute(1));
    try testing.expectEqual(@as(u64, 55), fib.compute(10));
    try testing.expectEqual(@as(u64, 6765), fib.compute(20));

    try testing.expect(fib.cache[10] != null);
}

// ANCHOR: lazy_with_error
// Lazy evaluation with errors
const FallibleLazy = struct {
    value: ?i32,
    last_error: ?anyerror,

    pub fn init() FallibleLazy {
        return FallibleLazy{
            .value = null,
            .last_error = null,
        };
    }

    pub fn getValue(self: *FallibleLazy, input: i32) !i32 {
        if (self.value) |cached| {
            return cached;
        }

        const result = self.compute(input) catch |err| {
            self.last_error = err;
            return err;
        };

        self.value = result;
        self.last_error = null;
        return result;
    }

    fn compute(self: *FallibleLazy, input: i32) !i32 {
        _ = self;
        if (input < 0) return error.NegativeInput;
        return input * 2;
    }

    pub fn clearError(self: *FallibleLazy) void {
        self.last_error = null;
    }
};
// ANCHOR_END: lazy_with_error

test "lazy with error" {
    var lazy = FallibleLazy.init();

    const result = lazy.getValue(-5);
    try testing.expectError(error.NegativeInput, result);
    try testing.expect(lazy.last_error != null);

    lazy.clearError();
    const valid_result = try lazy.getValue(10);
    try testing.expectEqual(@as(i32, 20), valid_result);
}

// Comprehensive test
test "comprehensive lazy properties" {
    var calc = ExpensiveCalculation.init(7);
    try testing.expectEqual(@as(i32, 64), calc.getResult());

    var rect = Rectangle.init(4, 6);
    try testing.expectEqual(@as(f32, 24), rect.getArea());

    var lazy_str = LazyString.init(testing.allocator);
    defer lazy_str.deinit();
    const str = try lazy_str.getValue();
    try testing.expect(str.len > 0);

    var fib = Fibonacci.init();
    try testing.expectEqual(@as(u64, 13), fib.compute(7));
}
