# Structs, Enums, and Simple Data Models

## Problem

You need to group related data and create custom types for your program. How do you define structs? How do enums work? What are tagged unions, and how do they differ from structs?

Coming from object-oriented languages, you might be looking for classes with inheritance. Zig takes a different approach focused on composition and explicit data modeling.

## Solution

Zig provides three main ways to create custom types:

1. **Structs** - Group related data with optional methods
2. **Enums** - Define a set of named constants
3. **Tagged Unions** - Store different types in the same variable (variant types)

These combine to create expressive data models without complex inheritance hierarchies.

## Discussion

### Part 1: Basic Structs

```zig
{{#include ../../code/00-bootcamp/recipe_0_10.zig:basic_structs}}
```

**Coming from OOP:** Zig doesn't have classes or inheritance. Structs are pure data with optional functions. There's no `this` keyword - you explicitly pass `self`.

### Part 2: Enums

```zig
{{#include ../../code/00-bootcamp/recipe_0_10.zig:enums}}
```

Enums can have methods like structs.

### Part 3: Tagged Unions - Variant Types

```zig
{{#include ../../code/00-bootcamp/recipe_0_10.zig:tagged_unions}}
```

**Coming from TypeScript:** Tagged unions are like discriminated unions. The tag tells you which variant is active.

**Coming from Rust:** `union(enum)` is like Rust's `enum`. Zig calls it a tagged union because it combines a union with an enum tag.

### Public vs Private

Use `pub` to expose members outside the file:

```zig
test "public vs private members" {
    const Counter = struct {
        // Private field (default)
        count: i32 = 0,

        // Public function
        pub fn increment(self: *@This()) void {
            self.count += 1;
        }

        pub fn get(self: @This()) i32 {
            return self.count;
        }

        // Private function
        fn reset(self: *@This()) void {
            self.count = 0;
        }

        pub fn resetPublic(self: *@This()) void {
            self.reset();
        }
    };

    var counter = Counter{};
    counter.increment();
    try testing.expectEqual(@as(i32, 1), counter.get());
}
```

Without `pub`, members are private to the file. This provides encapsulation without access modifiers like `private`/`protected`/`public`.

### Nested Structs

Keep related types together:

```zig
test "nested structs" {
    const Company = struct {
        const Employee = struct {
            name: []const u8,
            salary: u32,
        };

        name: []const u8,
        employees: []const Employee,

        fn totalSalary(self: @This()) u32 {
            var total: u32 = 0;
            for (self.employees) |emp| {
                total += emp.salary;
            }
            return total;
        }
    };

    const employees = [_]Company.Employee{
        .{ .name = "Alice", .salary = 50000 },
        .{ .name = "Bob", .salary = 60000 },
    };

    const company = Company{
        .name = "Acme Corp",
        .employees = &employees,
    };

    try testing.expectEqual(@as(u32, 110000), company.totalSalary());
}
```

`Company.Employee` is a nested type, namespaced under `Company`.

### Putting It All Together

Here's a complete example combining structs, enums, and methods:

```zig
test "putting it all together" {
    const User = struct {
        const Role = enum {
            admin,
            moderator,
            user,

            fn canDelete(self: @This()) bool {
                return switch (self) {
                    .admin, .moderator => true,
                    .user => false,
                };
            }
        };

        id: u32,
        name: []const u8,
        role: Role,

        fn init(id: u32, name: []const u8, role: Role) @This() {
            return .{
                .id = id,
                .name = name,
                .role = role,
            };
        }

        fn describe(self: @This()) void {
            const role_str = switch (self.role) {
                .admin => "Admin",
                .moderator => "Moderator",
                .user => "User",
            };
            std.debug.print("User #{d}: {s} ({s})\n", .{ self.id, self.name, role_str });
        }
    };

    const admin = User.init(1, "Alice", .admin);
    const user = User.init(2, "Bob", .user);

    try testing.expectEqual(true, admin.role.canDelete());
    try testing.expectEqual(false, user.role.canDelete());
}
```

This pattern is idiomatic Zig: nested types, explicit initialization, methods that operate on data.

### Design Patterns

**Instead of inheritance, use composition:**
```zig
const Engine = struct { horsepower: u32 };
const Car = struct {
    engine: Engine,
    brand: []const u8
};
```

**Instead of interfaces, use function pointers or generic functions:**
```zig
fn processAny(comptime T: type, thing: T) void {
    thing.process(); // Works if T has a process() method
}
```

**Instead of null objects, use optionals:**
```zig
const maybe_user: ?User = null;
```

### Common Patterns

**Factory functions:**
```zig
fn create() @This() {
    return .{ .field = default_value };
}
```

**Builder pattern with default values:**
```zig
const Config = struct {
    host: []const u8 = "localhost",
    port: u16 = 8080,
};

const config = Config{ .port = 3000 }; // Override only what you need
```

**State machines with tagged unions:**
```zig
const State = union(enum) {
    idle,
    running: struct { progress: f32 },
    error: []const u8,
};
```

### Common Mistakes

**Forgetting field names:**
```zig
const p = Point{ 10, 20 };  // error
const p = Point{ .x = 10, .y = 20 };  // fixed
```

**Using wrong self parameter:**
```zig
fn modify(self: @This()) void {  // Can't modify - passed by value
    self.field = 10;  // error
}

fn modify(self: *@This()) void {  // Fixed - use pointer
    self.field = 10;
}
```

**Not handling all enum cases:**
```zig
switch (color) {
    .red => ...,
    .green => ...,
    // Missing .blue - compiler error!
}
```

**Accessing wrong union variant:**
```zig
const val = Value{ .int = 42 };
const f = val.float;  // Undefined behavior!

// Use switch instead:
switch (val) {
    .int => |i| ...,
    .float => |f| ...,
}
```

## See Also

- Recipe 0.9: Understanding Pointers - Using pointers with structs
- Recipe 0.7: Functions and Standard Library - Comptime for generic structs
- Recipe 2.13: Creating Data Processing Pipelines - Using tagged unions for data flow

Full compilable example: `code/00-bootcamp/recipe_0_10.zig`
