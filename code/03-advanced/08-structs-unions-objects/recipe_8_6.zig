// Recipe 8.6: Creating Managed Attributes
// Target Zig Version: 0.15.2

const std = @import("std");
const testing = std.testing;

// ANCHOR: basic_getters_setters
// Basic getter and setter pattern
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

    pub fn getFahrenheit(self: *const Temperature) f32 {
        return self.celsius * 9.0 / 5.0 + 32.0;
    }

    pub fn setFahrenheit(self: *Temperature, value: f32) void {
        self.celsius = (value - 32.0) * 5.0 / 9.0;
    }
};
// ANCHOR_END: basic_getters_setters

test "basic getters and setters" {
    var temp = Temperature.init(0);

    try testing.expectEqual(@as(f32, 0), temp.getCelsius());
    try testing.expectEqual(@as(f32, 32), temp.getFahrenheit());

    temp.setFahrenheit(212);
    try testing.expectEqual(@as(f32, 100), temp.getCelsius());
}

// ANCHOR: validated_setters
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
// ANCHOR_END: validated_setters

test "validated setters" {
    var account = BankAccount.init(100);

    try account.deposit(500);
    try testing.expectEqual(@as(f64, 500), account.getBalance());

    try account.withdraw(200);
    try testing.expectEqual(@as(f64, 300), account.getBalance());

    const result = account.withdraw(250);
    try testing.expectError(error.InsufficientFunds, result);
}

// ANCHOR: computed_properties
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
// ANCHOR_END: computed_properties

test "computed properties" {
    var rect = Rectangle.init(3, 4);

    try testing.expectEqual(@as(f32, 12), rect.getArea());
    try testing.expectEqual(@as(f32, 14), rect.getPerimeter());
    try testing.expectEqual(@as(f32, 5), rect.getDiagonal());

    try rect.setWidth(6);
    try testing.expectEqual(@as(f32, 24), rect.getArea());
}

// ANCHOR: readonly_properties
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
// ANCHOR_END: readonly_properties

test "read-only properties" {
    const person = Person.init("Jane", "Doe", 1990);

    const full_name = try person.getFullName(testing.allocator);
    defer testing.allocator.free(full_name);
    try testing.expectEqualStrings("Jane Doe", full_name);

    try testing.expectEqual(@as(u16, 34), person.getAge(2024));
    try testing.expectEqual(@as(u16, 1990), person.getBirthYear());
}

// ANCHOR: lazy_initialization
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
// ANCHOR_END: lazy_initialization

test "lazy initialization" {
    var cache = DataCache.init(testing.allocator);
    defer cache.deinit();

    const data1 = try cache.getData();
    try testing.expectEqualStrings("expensive data", data1);

    const data2 = try cache.getData();
    try testing.expectEqual(data1.ptr, data2.ptr); // Same pointer, cached

    cache.invalidate();
    const data3 = try cache.getData();
    try testing.expect(data1.ptr != data3.ptr); // Different pointer, reloaded
}

// ANCHOR: property_observers
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
// ANCHOR_END: property_observers

var observer_called = false;
var observer_old_value: i32 = 0;
var observer_new_value: i32 = 0;

fn testObserver(old: i32, new: i32) void {
    observer_called = true;
    observer_old_value = old;
    observer_new_value = new;
}

test "property observers" {
    observer_called = false;

    var observable = ObservableValue.init(10);
    observable.setObserver(&testObserver);

    observable.setValue(20);
    try testing.expect(observer_called);
    try testing.expectEqual(@as(i32, 10), observer_old_value);
    try testing.expectEqual(@as(i32, 20), observer_new_value);
}

// ANCHOR: private_backing_field
// Private backing field pattern
const User = struct {
    username: []const u8,
    password_hash: []const u8,
    login_attempts: u32,

    pub fn init(username: []const u8, password: []const u8) User {
        return User{
            .username = username,
            .password_hash = password, // In reality, this would be hashed
            .login_attempts = 0,
        };
    }

    pub fn getUsername(self: *const User) []const u8 {
        return self.username;
    }

    pub fn verifyPassword(self: *User, password: []const u8) !bool {
        if (self.login_attempts >= 3) return error.AccountLocked;

        const matches = std.mem.eql(u8, self.password_hash, password);
        if (!matches) {
            self.login_attempts += 1;
        } else {
            self.login_attempts = 0;
        }
        return matches;
    }

    pub fn getLoginAttempts(self: *const User) u32 {
        return self.login_attempts;
    }

    pub fn resetLoginAttempts(self: *User) void {
        self.login_attempts = 0;
    }
};
// ANCHOR_END: private_backing_field

test "private backing field" {
    var user = User.init("alice", "secret123");

    try testing.expectEqualStrings("alice", user.getUsername());

    const valid = try user.verifyPassword("secret123");
    try testing.expect(valid);
    try testing.expectEqual(@as(u32, 0), user.getLoginAttempts());

    const invalid = try user.verifyPassword("wrong");
    try testing.expect(!invalid);
    try testing.expectEqual(@as(u32, 1), user.getLoginAttempts());
}

// ANCHOR: range_constrained
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
// ANCHOR_END: range_constrained

test "range-constrained property" {
    var vol = Volume.init();
    try testing.expectEqual(@as(u8, 50), vol.getLevel());

    try vol.setLevel(75);
    try testing.expectEqual(@as(u8, 75), vol.getLevel());

    vol.increase(50);
    try testing.expect(vol.isMax());

    vol.decrease(100);
    try testing.expect(vol.isMuted());

    const result = vol.setLevel(101);
    try testing.expectError(error.ValueOutOfRange, result);
}

// ANCHOR: dependent_properties
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
// ANCHOR_END: dependent_properties

test "dependent properties" {
    var circle = try Circle.init(5);

    try testing.expectEqual(@as(f32, 5), circle.getRadius());
    try testing.expectEqual(@as(f32, 10), circle.getDiameter());

    try circle.setDiameter(20);
    try testing.expectEqual(@as(f32, 10), circle.getRadius());

    const circumference = circle.getCircumference();
    const expected_circ = 2 * std.math.pi * 10;
    try testing.expectApproxEqAbs(expected_circ, circumference, 0.001);
}

// ANCHOR: format_transformation
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
// ANCHOR_END: format_transformation

test "format transformation" {
    var phone = try PhoneNumber.init(testing.allocator, "5551234567");
    defer phone.deinit();

    try testing.expectEqualStrings("5551234567", phone.getDigits());

    const formatted = try phone.getFormatted(testing.allocator);
    defer testing.allocator.free(formatted);
    try testing.expectEqualStrings("(555) 123-4567", formatted);
}

// Comprehensive test
test "comprehensive managed attributes" {
    var temp = Temperature.init(100);
    temp.setFahrenheit(32);
    try testing.expectEqual(@as(f32, 0), temp.getCelsius());

    var account = BankAccount.init(0);
    try account.deposit(1000);
    try account.withdraw(500);
    try testing.expectEqual(@as(f64, 500), account.getBalance());

    var vol = Volume.init();
    vol.increase(50);
    try testing.expectEqual(@as(u8, 100), vol.getLevel());

    var circle = try Circle.init(1);
    const area = circle.getArea();
    try testing.expectApproxEqAbs(std.math.pi, area, 0.001);
}
