## Problem

Your module has grown too large and handles multiple responsibilities. You want to split it into smaller, focused files organized by concern (types, validation, storage) while maintaining a simple, unified public API. You need to avoid forcing users to import from multiple files.

## Solution

Use the aggregator pattern: split your module into multiple specialized files, then create a main module that imports and re-exports them. Organize files by responsibility (types, logic, storage) and use relative imports to connect them. The aggregator provides a single import point for users.

### Module Structure

Create a directory for your split module:

```
recipe_10_4/
├── user_manager.zig (aggregator - public API)
├── user_types.zig (data structures)
├── user_validation.zig (validation logic)
└── user_storage.zig (storage operations)
```

### Importing the Aggregator

Users import only the aggregator module:

```zig
{{#include ../../../code/03-advanced/10-modules-build-system/recipe_10_4.zig:import_aggregator}}
```

The aggregator re-exports everything users need.

### Using the Split Module

Access all functionality through the aggregator:

```zig
test "using split module" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Use the aggregated API - implementation is split across files
    var manager = try UserManager.init(allocator);
    defer manager.deinit();

    const user = UserManager.User{
        .id = 1,
        .username = "alice",
        .email = "alice@example.com",
        .age = 25,
    };

    try manager.addUser(user);
    try testing.expectEqual(@as(usize, 1), manager.count());
}
```

Users don't need to know the implementation is split.

## Discussion

### Step 1: Define Types

Create `user_types.zig` for data structures:

```zig
// User data structures and types
const std = @import("std");

pub const User = struct {
    id: u32,
    username: []const u8,
    email: []const u8,
    age: u8,
};

pub const UserError = error{
    InvalidUser,
    UserNotFound,
    DuplicateUser,
};
```

Types have no dependencies except the standard library.

### Step 2: Implement Validation

Create `user_validation.zig` for validation logic:

```zig
// User validation logic
const std = @import("std");
const types = @import("user_types.zig");

pub fn validateUser(user: *const types.User) bool {
    if (user.id == 0) return false;
    if (!validateUsername(user.username)) return false;
    if (!validateEmail(user.email)) return false;
    if (!validateAge(user.age)) return false;
    return true;
}

pub fn validateUsername(username: []const u8) bool {
    if (username.len < 3) return false;
    if (username.len > 32) return false;

    // Username must contain only alphanumeric and underscores
    for (username) |c| {
        const valid = (c >= 'a' and c <= 'z') or
            (c >= 'A' and c <= 'Z') or
            (c >= '0' and c <= '9') or
            c == '_';
        if (!valid) return false;
    }

    return true;
}

pub fn validateEmail(email: []const u8) bool {
    if (email.len < 5) return false;

    // Simple email validation: must contain @ and . after @
    var has_at = false;
    var at_index: usize = 0;

    for (email, 0..) |c, i| {
        if (c == '@') {
            if (has_at) return false; // Multiple @ symbols
            if (i == 0) return false; // @ at start
            has_at = true;
            at_index = i;
        }
    }

    if (!has_at) return false;
    if (at_index == email.len - 1) return false; // @ at end

    // Check for . after @
    const domain = email[at_index + 1 ..];
    var has_dot = false;
    for (domain) |c| {
        if (c == '.') {
            has_dot = true;
            break;
        }
    }

    return has_dot;
}

pub fn validateAge(age: u8) bool {
    return age >= 18 and age <= 120;
}
```

Validation imports types but has no storage dependencies.

### Step 3: Implement Storage

Create `user_storage.zig` for storage operations:

```zig
// User storage operations
const std = @import("std");
const types = @import("user_types.zig");
const validation = @import("user_validation.zig");

pub const Storage = struct {
    users: std.ArrayList(types.User),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !Storage {
        return .{
            .users = .{},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Storage) void {
        self.users.deinit(self.allocator);
    }

    pub fn addUser(self: *Storage, user: types.User) !void {
        if (!validation.validateUser(&user)) {
            return error.InvalidUser;
        }

        // Check for duplicate ID
        for (self.users.items) |existing| {
            if (existing.id == user.id) {
                return error.DuplicateUser;
            }
        }

        try self.users.append(self.allocator, user);
    }

    pub fn findUser(self: *Storage, id: u32) ?*types.User {
        for (self.users.items) |*user| {
            if (user.id == id) {
                return user;
            }
        }
        return null;
    }

    pub fn removeUser(self: *Storage, id: u32) bool {
        for (self.users.items, 0..) |user, i| {
            if (user.id == id) {
                _ = self.users.swapRemove(i);
                return true;
            }
        }
        return false;
    }

    pub fn count(self: *const Storage) usize {
        return self.users.items.len;
    }

    pub fn clear(self: *Storage) void {
        self.users.clearRetainingCapacity();
    }
};
```

Storage imports both types and validation.

### Step 4: Create the Aggregator

Create `user_manager.zig` to unify the API:

```zig
// User Manager - Aggregator module
const std = @import("std");

// Import the split components
const types = @import("user_types.zig");
const validation = @import("user_validation.zig");
const storage = @import("user_storage.zig");

// Re-export types for public API
pub const User = types.User;
pub const UserError = types.UserError;

// Re-export validation functions
pub const validateUser = validation.validateUser;
pub const validateUsername = validation.validateUsername;
pub const validateEmail = validation.validateEmail;
pub const validateAge = validation.validateAge;

// Provide a convenience wrapper around storage
const Storage = storage.Storage;

pub fn init(allocator: std.mem.Allocator) !Storage {
    return Storage.init(allocator);
}

pub const deinit = Storage.deinit;
pub const addUser = Storage.addUser;
pub const findUser = Storage.findUser;
pub const removeUser = Storage.removeUser;
pub const count = Storage.count;
pub const clear = Storage.clear;
```

The aggregator imports all components and re-exports their public interfaces.

### Accessing Types

Types are accessible through the aggregator:

```zig
test "accessing types from split module" {
    // Types are re-exported from the aggregator
    const user: UserManager.User = .{
        .id = 1,
        .username = "bob",
        .email = "bob@example.com",
        .age = 30,
    };

    try testing.expectEqual(@as(u32, 1), user.id);
    try testing.expectEqualStrings("bob", user.username);
}
```

Users access `UserManager.User`, not `user_types.User`.

### Validation Through Aggregator

Validation functions work through the aggregator:

```zig
test "validation through aggregator" {
    // Validation functions are exposed through the aggregator
    const valid_user = UserManager.User{
        .id = 1,
        .username = "charlie",
        .email = "charlie@example.com",
        .age = 25,
    };

    try testing.expect(UserManager.validateUser(&valid_user));

    const invalid_user = UserManager.User{
        .id = 0,
        .username = "",
        .email = "invalid",
        .age = 150,
    };

    try testing.expect(!UserManager.validateUser(&invalid_user));
}
```

All validation is centralized and accessible.

### Storage Operations

Storage operations work seamlessly:

```zig
test "storage operations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var manager = try UserManager.init(allocator);
    defer manager.deinit();

    const user1 = UserManager.User{
        .id = 1,
        .username = "dave",
        .email = "dave@example.com",
        .age = 28,
    };

    const user2 = UserManager.User{
        .id = 2,
        .username = "eve",
        .email = "eve@example.com",
        .age = 32,
    };

    try manager.addUser(user1);
    try manager.addUser(user2);

    const found = manager.findUser(1);
    try testing.expect(found != null);
    try testing.expectEqualStrings("dave", found.?.username);

    const not_found = manager.findUser(999);
    try testing.expect(not_found == null);
}
```

Storage, validation, and types work together transparently.

### Error Handling

Errors propagate through the aggregator:

```zig
test "error handling in split module" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var manager = try UserManager.init(allocator);
    defer manager.deinit();

    // Invalid user should fail validation
    const invalid_user = UserManager.User{
        .id = 0,
        .username = "",
        .email = "bad",
        .age = 150,
    };

    const result = manager.addUser(invalid_user);
    try testing.expectError(error.InvalidUser, result);
}
```

Validation errors are returned to the caller.

### Username Validation

Test username validation rules:

```zig
test "username validation" {
    // Valid usernames
    try testing.expect(UserManager.validateUsername("alice"));
    try testing.expect(UserManager.validateUsername("bob123"));
    try testing.expect(UserManager.validateUsername("user_name"));

    // Invalid usernames
    try testing.expect(!UserManager.validateUsername(""));
    try testing.expect(!UserManager.validateUsername("ab"));
    try testing.expect(!UserManager.validateUsername("this_username_is_way_too_long_to_be_valid"));
}
```

Usernames must be 3-32 characters, alphanumeric plus underscores.

### Email Validation

Test email validation:

```zig
test "email validation" {
    // Valid emails
    try testing.expect(UserManager.validateEmail("user@example.com"));
    try testing.expect(UserManager.validateEmail("test.user@domain.org"));
    try testing.expect(UserManager.validateEmail("name+tag@site.co.uk"));

    // Invalid emails
    try testing.expect(!UserManager.validateEmail(""));
    try testing.expect(!UserManager.validateEmail("notanemail"));
    try testing.expect(!UserManager.validateEmail("missing@domain"));
    try testing.expect(!UserManager.validateEmail("@nodomain.com"));
}
```

Emails must contain @ with a domain including a dot.

### Age Validation

Test age bounds:

```zig
test "age validation" {
    // Valid ages
    try testing.expect(UserManager.validateAge(18));
    try testing.expect(UserManager.validateAge(25));
    try testing.expect(UserManager.validateAge(120));

    // Invalid ages
    try testing.expect(!UserManager.validateAge(0));
    try testing.expect(!UserManager.validateAge(17));
    try testing.expect(!UserManager.validateAge(121));
}
```

Age must be between 18 and 120 inclusive.

### Bulk Operations

Manage multiple users:

```zig
test "bulk operations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var manager = try UserManager.init(allocator);
    defer manager.deinit();

    const users = [_]UserManager.User{
        .{ .id = 1, .username = "user1", .email = "user1@test.com", .age = 25 },
        .{ .id = 2, .username = "user2", .email = "user2@test.com", .age = 30 },
        .{ .id = 3, .username = "user3", .email = "user3@test.com", .age = 35 },
    };

    for (users) |user| {
        try manager.addUser(user);
    }

    try testing.expectEqual(@as(usize, 3), manager.count());

    // Remove one user
    const removed = manager.removeUser(2);
    try testing.expect(removed);
    try testing.expectEqual(@as(usize, 2), manager.count());

    // Try to remove non-existent user
    const not_removed = manager.removeUser(999);
    try testing.expect(!not_removed);
}
```

The API supports efficient batch operations.

### Clear All Users

Reset the storage:

```zig
test "clear all users" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var manager = try UserManager.init(allocator);
    defer manager.deinit();

    try manager.addUser(.{ .id = 1, .username = "user1", .email = "u1@test.com", .age = 25 });
    try manager.addUser(.{ .id = 2, .username = "user2", .email = "u2@test.com", .age = 30 });

    try testing.expectEqual(@as(usize, 2), manager.count());

    manager.clear();
    try testing.expectEqual(@as(usize, 0), manager.count());
}
```

Clearing retains capacity for performance.

### Organizational Benefits

Splitting modules provides clear advantages:

```zig
test "organizational benefits of splitting" {
    // Benefit 1: Types are in a dedicated file (user_types.zig)
    // Benefit 2: Validation logic is separate (user_validation.zig)
    // Benefit 3: Storage operations are isolated (user_storage.zig)
    // Benefit 4: Aggregator provides unified API (user_manager.zig)

    // Users interact with a single clean interface
    const user = UserManager.User{
        .id = 1,
        .username = "organized",
        .email = "org@example.com",
        .age = 25,
    };

    // But implementation is logically organized across files
    try testing.expect(UserManager.validateUser(&user));
}
```

Each file has a single, clear responsibility.

### Dependency Layering

Organize modules in layers:

```
Layer 1: user_types.zig (no dependencies)
         ↑
Layer 2: user_validation.zig (depends on types)
         ↑
Layer 3: user_storage.zig (depends on types + validation)
         ↑
Layer 4: user_manager.zig (aggregates all layers)
```

Dependencies flow in one direction, preventing circular imports.

### Module Responsibilities

Each file has a focused purpose:

**user_types.zig (Data Layer):**
- Define data structures
- Define error types
- No logic, just definitions

**user_validation.zig (Logic Layer):**
- Stateless validation functions
- No storage dependencies
- Pure functions

**user_storage.zig (Storage Layer):**
- Stateful operations
- Uses validation before mutations
- Manages ArrayList lifecycle

**user_manager.zig (API Layer):**
- Re-exports public types
- Re-exports public functions
- Single import point for users

### Benefits of Splitting

**Better Organization:**
- Each file is small and focused
- Easy to find specific functionality
- Clear separation of concerns

**Easier Testing:**
- Test validation independently
- Test storage independently
- Integration tests use aggregator

**Simpler Refactoring:**
- Change validation without touching storage
- Change storage implementation without affecting API
- Modify types with clear impact analysis

**Team Collaboration:**
- Different developers can work on different layers
- Merge conflicts are less likely
- Code review is easier with smaller files

### When to Split Modules

Split a module when:

**Size:** File exceeds 300-500 lines
**Responsibilities:** Module handles multiple concerns
**Testing:** Tests become difficult to organize
**Collaboration:** Multiple developers work on the same file

Don't split when:

**Small:** File is under 200 lines
**Cohesive:** All code serves a single purpose
**Simple:** Few public functions
**Stable:** Code rarely changes

### Best Practices

**Use Layered Dependencies:**
```
foundation → logic → storage → API
```

**Keep Aggregator Thin:**
```zig
// Good: Just re-exports
pub const User = types.User;
pub const validate = validation.validate;

// Bad: Logic in aggregator
pub fn processUser(user: User) !void {
    // Complex logic here - belongs in a layer file
}
```

**Name Files Clearly:**
```
user_types.zig     (not types.zig)
user_validation.zig (not validate.zig)
user_storage.zig   (not store.zig)
```

**Document Dependencies:**
```zig
// user_storage.zig - depends on types and validation
const types = @import("user_types.zig");
const validation = @import("user_validation.zig");
```

### Common Patterns

**Simple Aggregator:**
```zig
pub const Type = submodule.Type;
pub const function = submodule.function;
```

**Wrapper Aggregator:**
```zig
pub fn init(allocator: std.mem.Allocator) !Storage {
    return Storage.init(allocator);
}
```

**Selective Export:**
```zig
// Export only public API, hide internals
pub const Public = internal.PublicType;
// Don't export: internal.PrivateType
```

### Preventing Circular Dependencies

Avoid cycles by layering:

**Bad (Circular):**
```
validation.zig imports storage.zig
storage.zig imports validation.zig
```

**Good (Layered):**
```
types.zig (no dependencies)
validation.zig imports types.zig
storage.zig imports types.zig + validation.zig
```

Cycles indicate unclear responsibilities - refactor to extract shared types.

### Testing Split Modules

Test each layer independently:

```zig
// Test validation alone
test "validation logic" {
    const valid = validation.validateUsername("alice");
    try testing.expect(valid);
}

// Test storage with mocked validation
test "storage operations" {
    var manager = try Storage.init(allocator);
    defer manager.deinit();
    // ...
}

// Integration test through aggregator
test "complete workflow" {
    var manager = try UserManager.init(allocator);
    defer manager.deinit();
    // ...
}
```

### File Size Guidelines

Keep files focused and readable:

**Types:** 50-150 lines (simple definitions)
**Validation:** 100-300 lines (logic functions)
**Storage:** 200-500 lines (stateful operations)
**Aggregator:** 50-100 lines (just re-exports)

If a file grows larger, consider splitting it further.

### Refactoring to Split Modules

Start with a large module:

```zig
// user.zig - 800 lines, too large
pub const User = struct { ... };
pub fn validate(...) bool { ... }
pub const Storage = struct { ... };
```

Extract types first:

```zig
// user_types.zig - new file
pub const User = struct { ... };
```

Then extract validation:

```zig
// user_validation.zig - new file
const types = @import("user_types.zig");
pub fn validate(user: *const types.User) bool { ... }
```

Then extract storage:

```zig
// user_storage.zig - new file
const types = @import("user_types.zig");
const validation = @import("user_validation.zig");
pub const Storage = struct { ... };
```

Finally create aggregator:

```zig
// user.zig - now an aggregator
const types = @import("user_types.zig");
const validation = @import("user_validation.zig");
const storage = @import("user_storage.zig");

pub const User = types.User;
pub const validate = validation.validate;
pub const Storage = storage.Storage;
```

Users' code doesn't change - they still import `user.zig`.

## See Also

- Recipe 10.1: Making a hierarchical package of modules
- Recipe 10.2: Controlling the export of symbols
- Recipe 10.3: Importing package submodules using relative names
- Recipe 10.5: Making separate directories of code import under a common namespace

Full compilable example: `code/03-advanced/10-modules-build-system/recipe_10_4.zig`
