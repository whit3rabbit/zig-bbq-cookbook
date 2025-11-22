## Problem

You want to control access to struct fields, validate values before assignment, compute derived properties, or implement lazy initialization—all without traditional getters and setters from object-oriented languages.

## Solution

Zig doesn't have built-in property syntax, but you can implement managed attributes using explicit getter and setter methods. This gives you fine-grained control over how data is accessed and modified.

### Basic Getters and Setters

```zig
{{#include ../../../code/03-advanced/08-structs-unions-objects/recipe_8_6.zig:basic_getters_setters}}
```

This pattern provides controlled access to fields and allows format conversion on the fly.

### Validated Setters

Add validation logic to setters to ensure data integrity:

```zig
// Validated setters
const BankAccount = struct {
    balance: f64,
    min_balance: f64,

    pub fn init(min_balance: f64) BankAccount {
        return BankAccount{
            .balance = 0,
            .min_balance = min_balance,
        };
    }

    pub fn getBalance(self: *const BankAccount) f64 {
        return self.balance;
    }

    pub fn deposit(self: *BankAccount, amount: f64) !void {
        if (amount <= 0) return error.InvalidAmount;
        self.balance += amount;
    }

    pub fn withdraw(self: *BankAccount, amount: f64) !void {
        if (amount <= 0) return error.InvalidAmount;
        if (self.balance - amount < self.min_balance) {
            return error.InsufficientFunds;
        }
        self.balance -= amount;
    }
};
```

Validation prevents invalid state and returns clear errors when constraints are violated.

### Computed Properties

Create read-only properties derived from stored data:

```zig
// Computed properties
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

    pub fn getDiagonal(self: *const Rectangle) f32 {
        return @sqrt(self.width * self.width + self.height * self.height);
    }

    pub fn setWidth(self: *Rectangle, width: f32) !void {
        if (width <= 0) return error.InvalidDimension;
        self.width = width;
    }

    pub fn setHeight(self: *Rectangle, height: f32) !void {
        if (height <= 0) return error.InvalidDimension;
        self.height = height;
    }
};
```

Computed properties avoid storing redundant data and ensure derived values stay consistent.

### Read-Only Properties

Some properties should only be readable, not writable:

```zig
// Read-only properties
const Person = struct {
    first_name: []const u8,
    last_name: []const u8,
    birth_year: u16,

    pub fn init(first: []const u8, last: []const u8, birth_year: u16) Person {
        return Person{
            .first_name = first,
            .last_name = last,
            .birth_year = birth_year,
        };
    }

    pub fn getFullName(self: *const Person, allocator: std.mem.Allocator) ![]u8 {
        return std.fmt.allocPrint(
            allocator,
            "{s} {s}",
            .{ self.first_name, self.last_name },
        );
    }

    pub fn getAge(self: *const Person, current_year: u16) u16 {
        return current_year - self.birth_year;
    }

    pub fn getBirthYear(self: *const Person) u16 {
        return self.birth_year;
    }
};
```

By omitting setters, you enforce immutability for specific fields.

### Lazy Initialization

Defer expensive computations until the value is actually needed:

```zig
// Lazy initialization
const DataCache = struct {
    data: ?[]const u8,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) DataCache {
        return DataCache{
            .data = null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *DataCache) void {
        if (self.data) |d| {
            self.allocator.free(d);
        }
    }

    pub fn getData(self: *DataCache) ![]const u8 {
        if (self.data) |d| {
            return d;
        }

        // Simulate expensive operation
        const loaded = try self.allocator.dupe(u8, "expensive data");
        self.data = loaded;
        return loaded;
    }

    pub fn invalidate(self: *DataCache) void {
        if (self.data) |d| {
            self.allocator.free(d);
            self.data = null;
        }
    }
};
```

The data is only loaded on first access, and subsequent calls return the cached value.

### Property Observers

Trigger callbacks when values change:

```zig
// Property observers (callbacks on change)
const ObservableValue = struct {
    value: i32,
    on_change: ?*const fn (old: i32, new: i32) void,

    pub fn init(initial: i32) ObservableValue {
        return ObservableValue{
            .value = initial,
            .on_change = null,
        };
    }

    pub fn getValue(self: *const ObservableValue) i32 {
        return self.value;
    }

    pub fn setValue(self: *ObservableValue, new_value: i32) void {
        const old = self.value;
        self.value = new_value;
        if (self.on_change) |callback| {
            callback(old, new_value);
        }
    }

    pub fn setObserver(self: *ObservableValue, callback: *const fn (old: i32, new: i32) void) void {
        self.on_change = callback;
    }
};
```

This pattern is useful for reactive programming and UI updates.

### Range-Constrained Properties

Enforce value ranges automatically:

```zig
// Range-constrained property
const Volume = struct {
    level: u8, // 0-100

    pub fn init() Volume {
        return Volume{ .level = 50 };
    }

    pub fn getLevel(self: *const Volume) u8 {
        return self.level;
    }

    pub fn setLevel(self: *Volume, value: u8) !void {
        if (value > 100) return error.ValueOutOfRange;
        self.level = value;
    }

    pub fn increase(self: *Volume, amount: u8) void {
        const new_level = @min(self.level + amount, 100);
        self.level = new_level;
    }

    pub fn decrease(self: *Volume, amount: u8) void {
        const new_level = if (self.level >= amount) self.level - amount else 0;
        self.level = new_level;
    }

    pub fn isMuted(self: *const Volume) bool {
        return self.level == 0;
    }

    pub fn isMax(self: *const Volume) bool {
        return self.level == 100;
    }
};
```

Helper methods like `increase()` and `decrease()` automatically clamp values to valid ranges.

### Dependent Properties

Allow setting values through different representations:

```zig
// Dependent properties
const Circle = struct {
    radius: f32,

    pub fn init(radius: f32) !Circle {
        if (radius <= 0) return error.InvalidRadius;
        return Circle{ .radius = radius };
    }

    pub fn getRadius(self: *const Circle) f32 {
        return self.radius;
    }

    pub fn setRadius(self: *Circle, radius: f32) !void {
        if (radius <= 0) return error.InvalidRadius;
        self.radius = radius;
    }

    pub fn getDiameter(self: *const Circle) f32 {
        return self.radius * 2;
    }

    pub fn setDiameter(self: *Circle, diameter: f32) !void {
        if (diameter <= 0) return error.InvalidDiameter;
        self.radius = diameter / 2;
    }

    pub fn getCircumference(self: *const Circle) f32 {
        return 2 * std.math.pi * self.radius;
    }

    pub fn getArea(self: *const Circle) f32 {
        return std.math.pi * self.radius * self.radius;
    }
};
```

You can set the circle size via radius or diameter—both update the same underlying value.

### Format Transformation

Store data in one format but provide different representations:

```zig
// Format transformation properties
const PhoneNumber = struct {
    digits: []const u8, // Store as digits only
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, digits: []const u8) !PhoneNumber {
        if (digits.len != 10) return error.InvalidPhoneNumber;
        for (digits) |c| {
            if (c < '0' or c > '9') return error.InvalidPhoneNumber;
        }
        const owned = try allocator.dupe(u8, digits);
        return PhoneNumber{
            .digits = owned,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *PhoneNumber) void {
        self.allocator.free(self.digits);
    }

    pub fn getDigits(self: *const PhoneNumber) []const u8 {
        return self.digits;
    }

    pub fn getFormatted(self: *const PhoneNumber, allocator: std.mem.Allocator) ![]u8 {
        return std.fmt.allocPrint(
            allocator,
            "({s}) {s}-{s}",
            .{ self.digits[0..3], self.digits[3..6], self.digits[6..10] },
        );
    }
};
```

Data is stored efficiently (digits only) but can be retrieved in user-friendly formats.

## Discussion

Managed attributes in Zig follow the principle of explicit control. Unlike languages with property syntax, Zig makes the accessor methods visible, which:

1. **Makes costs obvious** - You can see when a "getter" allocates memory or does expensive computation
2. **Enables validation** - Setters can enforce invariants and return errors
3. **Supports transformation** - Convert between representations on access
4. **Allows lazy evaluation** - Defer work until actually needed
5. **Maintains explicitness** - No hidden behavior or magic

### Naming Conventions

While Zig doesn't enforce naming, common patterns include:

- `getValue()` / `setValue()` for simple accessors
- `deposit()` / `withdraw()` for domain-specific operations
- `increase()` / `decrease()` for relative changes
- Computed properties often omit "get" prefix: `area()` instead of `getArea()`

### When to Use Managed Attributes

Use managed attributes when you need:

- **Validation** - Prevent invalid state
- **Computation** - Derive values from stored data
- **Transformation** - Convert between formats
- **Lazy loading** - Defer expensive operations
- **Observation** - React to changes
- **Encapsulation** - Hide implementation details

For simple data storage without logic, direct field access is more idiomatic in Zig.

### Memory Management

When getters allocate memory (like `getFullName()` or `getFormatted()`), they should:

1. Take an `allocator` parameter
2. Return an error union: `![]u8`
3. Document that the caller owns the returned memory
4. Expect the caller to use `defer allocator.free(result)`

This follows Zig's principle of making memory allocation explicit.

### Performance Considerations

- Getters that compute values run on every access—consider caching for expensive operations
- Use `*const Self` for getters to enable calling on const instances
- Range-constrained setters with clamping (`@min`, `@max`) avoid branches
- Lazy initialization trades memory for first-access latency

## See Also

- Recipe 8.5: Encapsulating Names in a Struct
- Recipe 8.10: Using Lazily Computed Properties
- Recipe 8.11: Simplifying the Initialization of Data Structures
- Recipe 8.14: Implementing Custom Containers

Full compilable example: `code/03-advanced/08-structs-unions-objects/recipe_8_6.zig`
