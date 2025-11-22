// Core module - aggregates child modules in core/ directory
const std = @import("std");

// Import child modules from subdirectory
pub const logger = @import("core/logger.zig");
pub const config = @import("core/config.zig");

// Re-export commonly used types
pub const Config = config.Config;
pub const LogLevel = logger.Level;
