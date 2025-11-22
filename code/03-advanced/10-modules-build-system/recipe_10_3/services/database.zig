// Database service - demonstrates importing from parent package
const std = @import("std");

// Import from parent package using relative path
const core = @import("../core.zig");

pub const Database = struct {
    config: core.Config,
    connected: bool,

    pub fn init(config: core.Config) Database {
        core.logger.info("Database initialized");
        return .{
            .config = config,
            .connected = false,
        };
    }

    pub fn connect(self: *Database) !void {
        if (!self.config.validate()) {
            return error.InvalidConfig;
        }
        self.connected = true;
        core.logger.info("Database connected");
    }

    pub fn disconnect(self: *Database) void {
        self.connected = false;
        core.logger.info("Database disconnected");
    }
};
