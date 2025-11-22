// Recipe 8.8: Extending a Property in a Subclass
// Target Zig Version: 0.15.2

const std = @import("std");
const testing = std.testing;

// ANCHOR: basic_property_extension
// Basic property extension
const BaseCounter = struct {
    value: i32,

    pub fn init() BaseCounter {
        return BaseCounter{ .value = 0 };
    }

    pub fn getValue(self: *const BaseCounter) i32 {
        return self.value;
    }

    pub fn setValue(self: *BaseCounter, val: i32) void {
        self.value = val;
    }

    pub fn increment(self: *BaseCounter) void {
        self.value += 1;
    }
};

const ExtendedCounter = struct {
    base: BaseCounter,
    history: [10]i32,
    history_len: usize,

    pub fn init() ExtendedCounter {
        return ExtendedCounter{
            .base = BaseCounter.init(),
            .history = undefined,
            .history_len = 0,
        };
    }

    // Extend getValue to include history tracking
    pub fn getValue(self: *const ExtendedCounter) i32 {
        return self.base.getValue();
    }

    // Extend setValue to record history
    pub fn setValue(self: *ExtendedCounter, val: i32) void {
        if (self.history_len < self.history.len) {
            self.history[self.history_len] = self.base.getValue();
            self.history_len += 1;
        }
        self.base.setValue(val);
    }

    pub fn increment(self: *ExtendedCounter) void {
        self.setValue(self.base.getValue() + 1);
    }

    pub fn getHistory(self: *const ExtendedCounter) []const i32 {
        return self.history[0..self.history_len];
    }
};
// ANCHOR_END: basic_property_extension

test "basic property extension" {
    var counter = ExtendedCounter.init();

    counter.setValue(5);
    counter.setValue(10);
    counter.increment();

    try testing.expectEqual(@as(i32, 11), counter.getValue());

    const history = counter.getHistory();
    try testing.expectEqual(@as(usize, 3), history.len);
    try testing.expectEqual(@as(i32, 0), history[0]);
    try testing.expectEqual(@as(i32, 5), history[1]);
    try testing.expectEqual(@as(i32, 10), history[2]);
}

// ANCHOR: extended_validation
// Extended validation rules
const BasicAccount = struct {
    balance: f64,

    pub fn init() BasicAccount {
        return BasicAccount{ .balance = 0 };
    }

    pub fn getBalance(self: *const BasicAccount) f64 {
        return self.balance;
    }

    pub fn deposit(self: *BasicAccount, amount: f64) !void {
        if (amount <= 0) return error.InvalidAmount;
        self.balance += amount;
    }
};

const PremiumAccount = struct {
    account: BasicAccount,
    min_deposit: f64,
    total_deposits: f64,

    pub fn init(min_deposit: f64) PremiumAccount {
        return PremiumAccount{
            .account = BasicAccount.init(),
            .min_deposit = min_deposit,
            .total_deposits = 0,
        };
    }

    pub fn getBalance(self: *const PremiumAccount) f64 {
        return self.account.getBalance();
    }

    // Extend with additional validation
    pub fn deposit(self: *PremiumAccount, amount: f64) !void {
        if (amount < self.min_deposit) return error.BelowMinimum;

        try self.account.deposit(amount);
        self.total_deposits += amount;
    }

    pub fn getTotalDeposits(self: *const PremiumAccount) f64 {
        return self.total_deposits;
    }
};
// ANCHOR_END: extended_validation

test "extended validation" {
    var premium = PremiumAccount.init(100);

    const small_deposit = premium.deposit(50);
    try testing.expectError(error.BelowMinimum, small_deposit);

    try premium.deposit(150);
    try testing.expectEqual(@as(f64, 150), premium.getBalance());
    try testing.expectEqual(@as(f64, 150), premium.getTotalDeposits());
}

// ANCHOR: computed_property_extension
// Computed properties building on parent
const Rectangle = struct {
    width: f32,
    height: f32,

    pub fn init(width: f32, height: f32) Rectangle {
        return Rectangle{ .width = width, .height = height };
    }

    pub fn getArea(self: *const Rectangle) f32 {
        return self.width * self.height;
    }

    pub fn getPerimeter(self: *const Rectangle) f32 {
        return 2 * (self.width + self.height);
    }
};

const ColoredRectangle = struct {
    rect: Rectangle,
    color: []const u8,
    opacity: f32,

    pub fn init(width: f32, height: f32, color: []const u8) ColoredRectangle {
        return ColoredRectangle{
            .rect = Rectangle.init(width, height),
            .color = color,
            .opacity = 1.0,
        };
    }

    // Delegate basic properties
    pub fn getArea(self: *const ColoredRectangle) f32 {
        return self.rect.getArea();
    }

    pub fn getPerimeter(self: *const ColoredRectangle) f32 {
        return self.rect.getPerimeter();
    }

    // Extended computed property
    pub fn getVisibleArea(self: *const ColoredRectangle) f32 {
        return self.rect.getArea() * self.opacity;
    }

    pub fn setOpacity(self: *ColoredRectangle, opacity: f32) !void {
        if (opacity < 0 or opacity > 1) return error.InvalidOpacity;
        self.opacity = opacity;
    }
};
// ANCHOR_END: computed_property_extension

test "computed property extension" {
    var colored = ColoredRectangle.init(10, 5, "red");

    try testing.expectEqual(@as(f32, 50), colored.getArea());
    try testing.expectEqual(@as(f32, 50), colored.getVisibleArea());

    try colored.setOpacity(0.5);
    try testing.expectEqual(@as(f32, 25), colored.getVisibleArea());
}

// ANCHOR: transformation_wrapper
// Property transformation wrapper
const Temperature = struct {
    celsius: f32,

    pub fn init(celsius: f32) Temperature {
        return Temperature{ .celsius = celsius };
    }

    pub fn getCelsius(self: *const Temperature) f32 {
        return self.celsius;
    }

    pub fn setCelsius(self: *Temperature, value: f32) void {
        self.celsius = value;
    }
};

const CalibratedTemperature = struct {
    temp: Temperature,
    offset: f32,

    pub fn init(celsius: f32, offset: f32) CalibratedTemperature {
        return CalibratedTemperature{
            .temp = Temperature.init(celsius),
            .offset = offset,
        };
    }

    // Transform getter to apply calibration
    pub fn getCelsius(self: *const CalibratedTemperature) f32 {
        return self.temp.getCelsius() + self.offset;
    }

    // Transform setter to remove calibration
    pub fn setCelsius(self: *CalibratedTemperature, value: f32) void {
        self.temp.setCelsius(value - self.offset);
    }

    pub fn getRawCelsius(self: *const CalibratedTemperature) f32 {
        return self.temp.getCelsius();
    }
};
// ANCHOR_END: transformation_wrapper

test "transformation wrapper" {
    var calibrated = CalibratedTemperature.init(100, 2.5);

    try testing.expectEqual(@as(f32, 102.5), calibrated.getCelsius());
    try testing.expectEqual(@as(f32, 100), calibrated.getRawCelsius());

    calibrated.setCelsius(50);
    try testing.expectEqual(@as(f32, 50), calibrated.getCelsius());
    try testing.expectEqual(@as(f32, 47.5), calibrated.getRawCelsius());
}

// ANCHOR: chained_operations
// Chaining parent and child operations
const Logger = struct {
    prefix: []const u8,
    log_count: u32,

    pub fn init(prefix: []const u8) Logger {
        return Logger{
            .prefix = prefix,
            .log_count = 0,
        };
    }

    pub fn log(self: *Logger, message: []const u8) void {
        _ = message;
        self.log_count += 1;
        // In reality: std.debug.print("[{s}] {s}\n", .{ self.prefix, message });
    }

    pub fn getLogCount(self: *const Logger) u32 {
        return self.log_count;
    }
};

const TimestampedLogger = struct {
    logger: Logger,
    last_timestamp: i64,

    pub fn init(prefix: []const u8) TimestampedLogger {
        return TimestampedLogger{
            .logger = Logger.init(prefix),
            .last_timestamp = 0,
        };
    }

    pub fn log(self: *TimestampedLogger, message: []const u8, timestamp: i64) void {
        self.last_timestamp = timestamp;
        self.logger.log(message);
    }

    pub fn getLogCount(self: *const TimestampedLogger) u32 {
        return self.logger.getLogCount();
    }

    pub fn getLastTimestamp(self: *const TimestampedLogger) i64 {
        return self.last_timestamp;
    }
};
// ANCHOR_END: chained_operations

test "chained operations" {
    var logger = TimestampedLogger.init("INFO");

    logger.log("First message", 1000);
    logger.log("Second message", 2000);

    try testing.expectEqual(@as(u32, 2), logger.getLogCount());
    try testing.expectEqual(@as(i64, 2000), logger.getLastTimestamp());
}

// ANCHOR: override_with_fallback
// Override with fallback to parent
const Cache = struct {
    data: ?[]const u8,

    pub fn init() Cache {
        return Cache{ .data = null };
    }

    pub fn get(self: *const Cache) ?[]const u8 {
        return self.data;
    }

    pub fn set(self: *Cache, value: []const u8) void {
        self.data = value;
    }

    pub fn clear(self: *Cache) void {
        self.data = null;
    }
};

const TtlCache = struct {
    cache: Cache,
    ttl_seconds: i64,
    set_time: i64,

    pub fn init(ttl_seconds: i64) TtlCache {
        return TtlCache{
            .cache = Cache.init(),
            .ttl_seconds = ttl_seconds,
            .set_time = 0,
        };
    }

    pub fn get(self: *const TtlCache, current_time: i64) ?[]const u8 {
        if (self.cache.get()) |data| {
            if (current_time - self.set_time < self.ttl_seconds) {
                return data;
            }
        }
        return null;
    }

    pub fn set(self: *TtlCache, value: []const u8, current_time: i64) void {
        self.cache.set(value);
        self.set_time = current_time;
    }

    pub fn clear(self: *TtlCache) void {
        self.cache.clear();
        self.set_time = 0;
    }
};
// ANCHOR_END: override_with_fallback

test "override with fallback" {
    var ttl_cache = TtlCache.init(100);

    ttl_cache.set("cached value", 1000);

    const value1 = ttl_cache.get(1050);
    try testing.expect(value1 != null);

    const value2 = ttl_cache.get(1200);
    try testing.expect(value2 == null);
}

// ANCHOR: pre_post_processing
// Pre and post processing
const DataStore = struct {
    value: i32,

    pub fn init() DataStore {
        return DataStore{ .value = 0 };
    }

    pub fn getValue(self: *const DataStore) i32 {
        return self.value;
    }

    pub fn setValue(self: *DataStore, val: i32) void {
        self.value = val;
    }
};

const ValidatedDataStore = struct {
    store: DataStore,
    min_value: i32,
    max_value: i32,
    validation_failures: u32,

    pub fn init(min: i32, max: i32) ValidatedDataStore {
        return ValidatedDataStore{
            .store = DataStore.init(),
            .min_value = min,
            .max_value = max,
            .validation_failures = 0,
        };
    }

    pub fn getValue(self: *const ValidatedDataStore) i32 {
        return self.store.getValue();
    }

    // Pre-processing: validate, post-processing: track failures
    pub fn setValue(self: *ValidatedDataStore, val: i32) !void {
        // Pre-processing
        if (val < self.min_value or val > self.max_value) {
            self.validation_failures += 1;
            return error.OutOfRange;
        }

        // Call parent
        self.store.setValue(val);

        // Post-processing could go here
    }

    pub fn getValidationFailures(self: *const ValidatedDataStore) u32 {
        return self.validation_failures;
    }
};
// ANCHOR_END: pre_post_processing

test "pre and post processing" {
    var validated = ValidatedDataStore.init(0, 100);

    try validated.setValue(50);
    try testing.expectEqual(@as(i32, 50), validated.getValue());

    const result = validated.setValue(150);
    try testing.expectError(error.OutOfRange, result);
    try testing.expectEqual(@as(u32, 1), validated.getValidationFailures());
}

// ANCHOR: lazy_property_extension
// Extending lazy properties
const BaseLazy = struct {
    computed: ?i32,

    pub fn init() BaseLazy {
        return BaseLazy{ .computed = null };
    }

    pub fn getComputed(self: *BaseLazy) i32 {
        if (self.computed) |val| return val;

        const result = 42; // Expensive computation
        self.computed = result;
        return result;
    }
};

const CachedLazy = struct {
    lazy: BaseLazy,
    access_count: u32,
    cache_hits: u32,

    pub fn init() CachedLazy {
        return CachedLazy{
            .lazy = BaseLazy.init(),
            .access_count = 0,
            .cache_hits = 0,
        };
    }

    pub fn getComputed(self: *CachedLazy) i32 {
        self.access_count += 1;
        if (self.lazy.computed != null) {
            self.cache_hits += 1;
        }
        return self.lazy.getComputed();
    }

    pub fn getCacheHitRate(self: *const CachedLazy) f32 {
        if (self.access_count == 0) return 0;
        return @as(f32, @floatFromInt(self.cache_hits)) / @as(f32, @floatFromInt(self.access_count));
    }
};
// ANCHOR_END: lazy_property_extension

test "lazy property extension" {
    var cached = CachedLazy.init();

    _ = cached.getComputed();
    _ = cached.getComputed();
    _ = cached.getComputed();

    try testing.expectEqual(@as(u32, 3), cached.access_count);
    try testing.expectEqual(@as(u32, 2), cached.cache_hits);

    const hit_rate = cached.getCacheHitRate();
    try testing.expectApproxEqAbs(0.666, hit_rate, 0.01);
}

// ANCHOR: multi_level_extension
// Multi-level property extension
const Level1 = struct {
    value: i32,

    pub fn init() Level1 {
        return Level1{ .value = 0 };
    }

    pub fn getValue(self: *const Level1) i32 {
        return self.value;
    }

    pub fn setValue(self: *Level1, val: i32) void {
        self.value = val;
    }
};

const Level2 = struct {
    level1: Level1,
    multiplier: i32,

    pub fn init(multiplier: i32) Level2 {
        return Level2{
            .level1 = Level1.init(),
            .multiplier = multiplier,
        };
    }

    pub fn getValue(self: *const Level2) i32 {
        return self.level1.getValue() * self.multiplier;
    }

    pub fn setValue(self: *Level2, val: i32) void {
        self.level1.setValue(@divTrunc(val, self.multiplier));
    }
};

const Level3 = struct {
    level2: Level2,
    offset: i32,

    pub fn init(multiplier: i32, offset: i32) Level3 {
        return Level3{
            .level2 = Level2.init(multiplier),
            .offset = offset,
        };
    }

    pub fn getValue(self: *const Level3) i32 {
        return self.level2.getValue() + self.offset;
    }

    pub fn setValue(self: *Level3, val: i32) void {
        self.level2.setValue(val - self.offset);
    }
};
// ANCHOR_END: multi_level_extension

test "multi-level extension" {
    var level3 = Level3.init(10, 5);

    level3.setValue(105);
    try testing.expectEqual(@as(i32, 105), level3.getValue());

    // Verify internal transformations
    try testing.expectEqual(@as(i32, 10), level3.level2.level1.value);
}

// Comprehensive test
test "comprehensive property extension" {
    var extended = ExtendedCounter.init();
    extended.setValue(10);
    try testing.expectEqual(@as(i32, 10), extended.getValue());

    var premium = PremiumAccount.init(50);
    try premium.deposit(100);
    try testing.expectEqual(@as(f64, 100), premium.getBalance());

    var colored = ColoredRectangle.init(4, 5, "blue");
    try testing.expectEqual(@as(f32, 20), colored.getArea());

    var calibrated = CalibratedTemperature.init(20, 1.5);
    try testing.expectEqual(@as(f32, 21.5), calibrated.getCelsius());
}
