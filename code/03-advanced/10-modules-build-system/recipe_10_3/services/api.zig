// API service - demonstrates multiple relative imports
const std = @import("std");

// Import sibling module
const database = @import("database.zig");

// Import from parent package
const core = @import("../core.zig");

pub const API = struct {
    db: database.Database,

    pub fn init(config: core.Config) API {
        core.logger.info("API initialized");
        return .{
            .db = database.Database.init(config),
        };
    }

    pub fn start(self: *API) !void {
        try self.db.connect();
        core.logger.info("API started");
    }

    pub fn stop(self: *API) void {
        self.db.disconnect();
        core.logger.info("API stopped");
    }
};
