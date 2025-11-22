## Problem

You want to extend or modify the behavior of properties from a parent struct—adding validation, transforming values, tracking history, or applying pre/post processing—while maintaining the parent's interface.

## Solution

Use composition to embed the parent struct and override its methods with enhanced behavior. Your child struct can delegate to the parent while adding extra functionality before or after the delegation.

### Basic Property Extension

Add functionality by tracking additional state alongside the parent's behavior:

```zig
{{#include ../../../code/03-advanced/08-structs-unions-objects/recipe_8_8.zig:basic_property_extension}}
    }

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
```

`ExtendedCounter` tracks value history while maintaining the same interface as `BaseCounter`.

### Extended Validation

Add stricter validation rules to parent methods:

```zig
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
```

`PremiumAccount` enforces a minimum deposit amount before delegating to the parent.

### Computed Properties Building on Parent

Create new computed properties based on parent data:

```zig
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
```

The `getVisibleArea()` method combines parent data with child-specific properties.

### Property Transformation Wrapper

Transform values on get and set operations:

```zig
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
```

Users work with calibrated values while the parent stores raw values.

### Chaining Parent and Child Operations

Extend parent methods by adding child-specific parameters:

```zig
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
```

The child's `log()` accepts a timestamp before delegating to the parent.

### Override with Conditional Fallback

Add logic that conditionally delegates to the parent:

```zig
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
```

The TTL cache checks expiration before returning the parent's cached data.

### Pre and Post Processing

Add validation before and tracking after parent method calls:

```zig
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

    pub fn setValue(self: *ValidatedDataStore, val: i32) !void {
        // Pre-processing: validate
        if (val < self.min_value or val > self.max_value) {
            self.validation_failures += 1;
            return error.OutOfRange;
        }

        // Call parent
        self.store.setValue(val);

        // Post-processing could track successful sets, etc.
    }

    pub fn getValidationFailures(self: *const ValidatedDataStore) u32 {
        return self.validation_failures;
    }
};
```

This pattern is useful for metrics, logging, and debugging.

### Multi-Level Extension

Chain multiple levels of property extensions:

```zig
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
```

Each level applies its own transformation, creating a pipeline of operations.

## Discussion

Extending properties through composition follows the decorator pattern, where each layer adds functionality while maintaining the interface.

### Advantages of This Approach

1. **Flexibility** - Add or remove features by composing different structs
2. **Clarity** - Each extension is a separate struct with clear responsibilities
3. **Testability** - Test each layer independently
4. **No conflicts** - Unlike inheritance, no method name collisions
5. **Compile-time overhead only** - No runtime cost for delegation

### Common Extension Patterns

**Validation**: Add checks before delegating to parent
- Example: Minimum/maximum bounds, format validation

**Transformation**: Convert values on get/set
- Example: Unit conversion, encoding/decoding

**Observation**: Track or react to changes
- Example: History tracking, change notifications

**Caching**: Store computed results
- Example: Lazy properties, memoization

**Conditional logic**: Choose whether to delegate
- Example: TTL expiration, feature flags

### When to Use Property Extension

Use property extension when you want to:

- Add validation without modifying the parent struct
- Track metrics or history for existing properties
- Apply transformations transparently
- Implement caching or lazy evaluation
- Add time-based or conditional behavior

### Design Considerations

**Interface compatibility**: Decide whether to keep the same interface (drop-in replacement) or add parameters (explicit extension).

**Error handling**: Extended methods can add new error cases while still propagating parent errors.

**State synchronization**: When both parent and child have state, ensure they stay consistent.

**Performance**: Most extensions have zero runtime cost when inlined. Measure if concerned.

## See Also

- Recipe 8.6: Creating Managed Attributes
- Recipe 8.7: Calling a Method on a Parent Class
- Recipe 8.10: Using Lazily Computed Properties
- Recipe 8.14: Implementing Custom Containers

Full compilable example: `code/03-advanced/08-structs-unions-objects/recipe_8_8.zig`
