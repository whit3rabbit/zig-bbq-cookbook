// Config module - demonstrates sibling import
const std = @import("std");

// Import sibling module using relative path
const logger = @import("logger.zig");

pub const Config = struct {
    host: []const u8,
    port: u16,

    pub fn init(host: []const u8, port: u16) Config {
        logger.info("Initializing configuration");
        return .{
            .host = host,
            .port = port,
        };
    }

    pub fn validate(self: *const Config) bool {
        if (self.port == 0) {
            logger.log(.err, "Invalid port: 0");
            return false;
        }
        logger.debug("Configuration validated");
        return true;
    }
};
