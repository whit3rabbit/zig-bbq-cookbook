// User storage operations
// This file contains storage and retrieval logic

const std = @import("std");
const types = @import("user_types.zig");
const validation = @import("user_validation.zig");

// ANCHOR: storage_struct
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
// ANCHOR_END: storage_struct

    // ANCHOR: add_user
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
    // ANCHOR_END: add_user

    // ANCHOR: find_user
    pub fn findUser(self: *Storage, id: u32) ?*types.User {
        for (self.users.items) |*user| {
            if (user.id == id) {
                return user;
            }
        }
        return null;
    }
    // ANCHOR_END: find_user

    // ANCHOR: remove_user
    pub fn removeUser(self: *Storage, id: u32) bool {
        for (self.users.items, 0..) |user, i| {
            if (user.id == id) {
                // NOTE: swapRemove is O(1) but changes order by swapping with the last element.
                // If maintaining insertion order matters (e.g., for UI display), use:
                //   _ = self.users.orderedRemove(i);  // O(N) but preserves order
                // For most use cases, swapRemove's performance is preferred.
                _ = self.users.swapRemove(i);
                return true;
            }
        }
        return false;
    }
    // ANCHOR_END: remove_user

    // ANCHOR: count_users
    pub fn count(self: *const Storage) usize {
        return self.users.items.len;
    }
    // ANCHOR_END: count_users

    // ANCHOR: clear_users
    pub fn clear(self: *Storage) void {
        self.users.clearRetainingCapacity();
    }
    // ANCHOR_END: clear_users
};
