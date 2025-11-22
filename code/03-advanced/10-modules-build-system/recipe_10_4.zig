// Recipe 10.4: Splitting a Module into Multiple Files
// Target Zig Version: 0.15.2
//
// This recipe demonstrates how to split a large module into multiple files
// while maintaining a clean public API through an aggregator module.
//
// Package structure:
// recipe_10_4.zig (root test file)
// └── recipe_10_4/
//     ├── user_manager.zig (aggregator - public API)
//     ├── user_types.zig (data structures)
//     ├── user_validation.zig (validation logic)
//     └── user_storage.zig (storage operations)

const std = @import("std");
const testing = std.testing;

// ANCHOR: import_aggregator
// Import the aggregator module which re-exports the split components
const UserManager = @import("recipe_10_4/user_manager.zig");
// ANCHOR_END: import_aggregator

// ANCHOR: using_split_module
test "using split module" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) {
            @panic("Memory leak detected!");
        }
    }
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
// ANCHOR_END: using_split_module

// ANCHOR: type_access
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
// ANCHOR_END: type_access

// ANCHOR: validation_through_aggregator
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
// ANCHOR_END: validation_through_aggregator

// ANCHOR: storage_operations
test "storage operations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) {
            @panic("Memory leak detected!");
        }
    }
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
// ANCHOR_END: storage_operations

// ANCHOR: error_handling
test "error handling in split module" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) {
            @panic("Memory leak detected!");
        }
    }
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
// ANCHOR_END: error_handling

// ANCHOR: username_validation
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
// ANCHOR_END: username_validation

// ANCHOR: email_validation
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
// ANCHOR_END: email_validation

// ANCHOR: age_validation
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
// ANCHOR_END: age_validation

// ANCHOR: bulk_operations
test "bulk operations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) {
            @panic("Memory leak detected!");
        }
    }
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
// ANCHOR_END: bulk_operations

// ANCHOR: clear_all
test "clear all users" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) {
            @panic("Memory leak detected!");
        }
    }
    const allocator = gpa.allocator();

    var manager = try UserManager.init(allocator);
    defer manager.deinit();

    try manager.addUser(.{ .id = 1, .username = "user1", .email = "u1@test.com", .age = 25 });
    try manager.addUser(.{ .id = 2, .username = "user2", .email = "u2@test.com", .age = 30 });

    try testing.expectEqual(@as(usize, 2), manager.count());

    manager.clear();
    try testing.expectEqual(@as(usize, 0), manager.count());
}
// ANCHOR_END: clear_all

// ANCHOR: organizational_benefits
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
// ANCHOR_END: organizational_benefits

// Comprehensive test
test "comprehensive split module usage" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) {
            @panic("Memory leak detected!");
        }
    }
    const allocator = gpa.allocator();

    var manager = try UserManager.init(allocator);
    defer manager.deinit();

    const users = [_]UserManager.User{
        .{ .id = 1, .username = "alice", .email = "alice@example.com", .age = 25 },
        .{ .id = 2, .username = "bob", .email = "bob@example.com", .age = 30 },
        .{ .id = 3, .username = "charlie", .email = "charlie@example.com", .age = 35 },
    };

    for (users) |user| {
        try testing.expect(UserManager.validateUser(&user));
        try manager.addUser(user);
    }

    try testing.expectEqual(@as(usize, 3), manager.count());

    for (users) |user| {
        const found = manager.findUser(user.id);
        try testing.expect(found != null);
        try testing.expectEqualStrings(user.username, found.?.username);
    }

    const removed = manager.removeUser(2);
    try testing.expect(removed);
    try testing.expectEqual(@as(usize, 2), manager.count());

    manager.clear();
    try testing.expectEqual(@as(usize, 0), manager.count());
}
