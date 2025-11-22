const std = @import("std");

// ANCHOR: basic_metadata
/// Parameter information metadata
const ParamInfo = struct {
    name: []const u8,
    description: []const u8,
    min_value: ?i32 = null,
    max_value: ?i32 = null,
};

/// Create user with metadata
pub fn createUser(params: struct {
    username: []const u8,
    age: i32,
    email: []const u8,

    pub const metadata = .{
        .username = ParamInfo{
            .name = "username",
            .description = "User's login name",
        },
        .age = ParamInfo{
            .name = "age",
            .description = "User's age in years",
            .min_value = 0,
            .max_value = 150,
        },
        .email = ParamInfo{
            .name = "email",
            .description = "User's email address",
        },
    };
}) !void {
    // Validate age using metadata
    if (params.age < @TypeOf(params).metadata.age.min_value.? or
        params.age > @TypeOf(params).metadata.age.max_value.?)
    {
        return error.InvalidAge;
    }

    std.debug.print("Creating user: {s}, age {}, email {s}\n", .{
        params.username,
        params.age,
        params.email,
    });
}
// ANCHOR_END: basic_metadata

// ANCHOR: generic_validator
/// Generic validator using metadata
const Validator = struct {
    pub fn validate(comptime T: type, value: T) !void {
        const type_info = @typeInfo(T);

        switch (type_info) {
            .@"struct" => |struct_info| {
                if (@hasDecl(T, "metadata")) {
                    const metadata = T.metadata;

                    inline for (struct_info.fields) |field| {
                        const field_value = @field(value, field.name);

                        if (@hasField(@TypeOf(metadata), field.name)) {
                            const field_meta = @field(metadata, field.name);

                            if (@hasField(@TypeOf(field_meta), "min_value")) {
                                const min = field_meta.min_value;
                                if (field_value < min) {
                                    return error.ValueTooSmall;
                                }
                            }

                            if (@hasField(@TypeOf(field_meta), "max_value")) {
                                const max = field_meta.max_value;
                                if (field_value > max) {
                                    return error.ValueTooLarge;
                                }
                            }
                        }
                    }
                }
            },
            else => {},
        }
    }
};
// ANCHOR_END: generic_validator

// ANCHOR: constrained_types
/// User parameters with metadata
const UserParams = struct {
    age: i32,
    score: f32,

    pub const metadata = .{
        .age = .{ .min_value = 0, .max_value = 150 },
        .score = .{ .min_value = 0.0, .max_value = 100.0 },
    };
};

/// Generate documentation from metadata
pub fn generateDocs(comptime T: type) []const u8 {
    const type_info = @typeInfo(T);

    if (type_info != .@"struct") {
        return "Not a struct";
    }

    if (!@hasDecl(T, "metadata")) {
        return "No metadata available";
    }

    comptime var doc: []const u8 = "Parameters:\n";
    const metadata = T.metadata;

    inline for (type_info.@"struct".fields) |field| {
        if (@hasField(@TypeOf(metadata), field.name)) {
            const field_meta = @field(metadata, field.name);

            doc = doc ++ "  " ++ field.name ++ ": " ++ @typeName(field.type);

            if (@hasField(@TypeOf(field_meta), "description")) {
                doc = doc ++ " - " ++ field_meta.description;
            }

            doc = doc ++ "\n";
        }
    }

    return doc;
}

/// Config parameters with metadata
const ConfigParams = struct {
    timeout: u32,
    retries: u8,

    pub const metadata = .{
        .timeout = .{ .description = "Timeout in milliseconds" },
        .retries = .{ .description = "Number of retry attempts" },
    };
};

/// Constrained type with validation
pub fn Constrained(comptime T: type, comptime constraints: anytype) type {
    return struct {
        value: T,

        pub fn init(val: T) !@This() {
            if (@hasField(@TypeOf(constraints), "min")) {
                if (val < constraints.min) {
                    return error.BelowMinimum;
                }
            }

            if (@hasField(@TypeOf(constraints), "max")) {
                if (val > constraints.max) {
                    return error.AboveMaximum;
                }
            }

            return .{ .value = val };
        }

        pub fn get(self: @This()) T {
            return self.value;
        }
    };
}

const Age = Constrained(u8, .{ .min = 0, .max = 150 });
const Percentage = Constrained(f32, .{ .min = 0.0, .max = 100.0 });
// ANCHOR_END: constrained_types

/// Parameter tag for API functions
const ParamTag = enum {
    required,
    optional,
    deprecated,
};

/// API function with tagged parameters
pub fn ApiFunction(comptime params: anytype) type {
    return struct {
        pub fn call(args: anytype) !void {
            const ArgsType = @TypeOf(args);
            const args_info = @typeInfo(ArgsType);

            // Check required parameters
            inline for (@typeInfo(@TypeOf(params)).@"struct".fields) |param_field| {
                const param_info = @field(params, param_field.name);

                if (param_info.tag == .required) {
                    if (!@hasField(ArgsType, param_field.name)) {
                        @compileError("Missing required parameter: " ++ param_field.name);
                    }
                }
            }

            std.debug.print("API call successful\n", .{});
            _ = args_info;
        }
    };
}

const MyApi = ApiFunction(.{
    .username = .{ .tag = .required, .type = []const u8 },
    .email = .{ .tag = .required, .type = []const u8 },
    .phone = .{ .tag = .optional, .type = []const u8 },
});

/// Serialization metadata
const SerializeInfo = struct {
    json_name: []const u8,
    omit_empty: bool = false,
    format: enum { default, timestamp, base64 } = .default,
};

/// User with serialization metadata
const User = struct {
    id: u64,
    username: []const u8,
    created_at: i64,
    avatar_data: ?[]const u8,

    pub const serialize_info = .{
        .id = SerializeInfo{ .json_name = "user_id" },
        .username = SerializeInfo{ .json_name = "name" },
        .created_at = SerializeInfo{
            .json_name = "createdAt",
            .format = .timestamp,
        },
        .avatar_data = SerializeInfo{
            .json_name = "avatar",
            .omit_empty = true,
            .format = .base64,
        },
    };

    pub fn toJson(self: User, allocator: std.mem.Allocator) ![]u8 {
        var list = std.ArrayList(u8){};
        errdefer list.deinit(allocator);

        try list.appendSlice(allocator, "{");

        const type_info = @typeInfo(@This());
        inline for (type_info.@"struct".fields, 0..) |field, i| {
            if (i > 0) try list.appendSlice(allocator, ",");

            const serialize_meta = @field(serialize_info, field.name);
            const field_value = @field(self, field.name);

            try list.appendSlice(allocator, "\"");
            try list.appendSlice(allocator, serialize_meta.json_name);
            try list.appendSlice(allocator, "\":");

            const value_str = try std.fmt.allocPrint(allocator, "{any}", .{field_value});
            defer allocator.free(value_str);
            try list.appendSlice(allocator, value_str);
        }

        try list.appendSlice(allocator, "}");
        return list.toOwnedSlice(allocator);
    }
};

/// Inspect parameters at runtime
pub fn inspectParams(comptime T: type) void {
    const type_info = @typeInfo(T);

    if (type_info != .@"struct") {
        std.debug.print("Not a struct\n", .{});
        return;
    }

    std.debug.print("Function parameters for {s}:\n", .{@typeName(T)});

    inline for (type_info.@"struct".fields) |field| {
        std.debug.print("  {s}: {s}", .{ field.name, @typeName(field.type) });

        if (@hasDecl(T, "metadata")) {
            const metadata = T.metadata;
            if (@hasField(@TypeOf(metadata), field.name)) {
                const field_meta = @field(metadata, field.name);
                if (@hasField(@TypeOf(field_meta), "description")) {
                    std.debug.print(" - {s}", .{field_meta.description});
                }
            }
        }

        std.debug.print("\n", .{});
    }
}

/// API parameters with metadata
const ApiParams = struct {
    endpoint: []const u8,
    method: []const u8,
    timeout: u32,

    pub const metadata = .{
        .endpoint = .{ .description = "API endpoint URL" },
        .method = .{ .description = "HTTP method (GET, POST, etc.)" },
        .timeout = .{ .description = "Request timeout in milliseconds" },
    };
};

// Tests

test "function with metadata" {
    try createUser(.{
        .username = "alice",
        .age = 30,
        .email = "alice@example.com",
    });

    try std.testing.expectError(
        error.InvalidAge,
        createUser(.{ .username = "bob", .age = 200, .email = "bob@example.com" }),
    );
}

test "automatic validation" {
    const valid = UserParams{ .age = 25, .score = 85.5 };
    try Validator.validate(UserParams, valid);

    const invalid_age = UserParams{ .age = 200, .score = 50.0 };
    try std.testing.expectError(error.ValueTooLarge, Validator.validate(UserParams, invalid_age));
}

test "documentation generation" {
    const docs = comptime generateDocs(ConfigParams);
    try std.testing.expect(std.mem.indexOf(u8, docs, "timeout") != null);
    try std.testing.expect(std.mem.indexOf(u8, docs, "milliseconds") != null);
}

test "type constraints" {
    const age = try Age.init(25);
    try std.testing.expectEqual(@as(u8, 25), age.get());

    try std.testing.expectError(error.AboveMaximum, Age.init(200));

    const pct = try Percentage.init(75.5);
    try std.testing.expectEqual(@as(f32, 75.5), pct.get());
}

test "tagged parameters" {
    try MyApi.call(.{
        .username = "alice",
        .email = "alice@example.com",
    });

    try MyApi.call(.{
        .username = "bob",
        .email = "bob@example.com",
        .phone = "555-1234",
    });
}

test "serialization metadata" {
    const allocator = std.testing.allocator;

    const user = User{
        .id = 42,
        .username = "alice",
        .created_at = 1234567890,
        .avatar_data = null,
    };

    const json = try user.toJson(allocator);
    defer allocator.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "user_id") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "name") != null);
}

test "runtime inspection" {
    inspectParams(ApiParams);
}

test "validation with min value" {
    const invalid_small = UserParams{ .age = -10, .score = 50.0 };
    try std.testing.expectError(error.ValueTooSmall, Validator.validate(UserParams, invalid_small));
}

test "validation with max score" {
    const invalid_score = UserParams{ .age = 25, .score = 150.0 };
    try std.testing.expectError(error.ValueTooLarge, Validator.validate(UserParams, invalid_score));
}

test "constrained type at minimum" {
    const age = try Age.init(0);
    try std.testing.expectEqual(@as(u8, 0), age.get());
}

test "constrained type at maximum" {
    const age = try Age.init(150);
    try std.testing.expectEqual(@as(u8, 150), age.get());
}

test "constrained type below minimum" {
    // Age is u8, so can't test negative, but test 0 boundary
    const age = try Age.init(0);
    try std.testing.expectEqual(@as(u8, 0), age.get());
}

test "percentage at boundaries" {
    const min = try Percentage.init(0.0);
    try std.testing.expectEqual(@as(f32, 0.0), min.get());

    const max = try Percentage.init(100.0);
    try std.testing.expectEqual(@as(f32, 100.0), max.get());
}

test "percentage out of bounds" {
    try std.testing.expectError(error.AboveMaximum, Percentage.init(150.0));
    try std.testing.expectError(error.BelowMinimum, Percentage.init(-10.0));
}

test "metadata field access" {
    // Access metadata through ConfigParams
    const meta = ConfigParams.metadata;
    try std.testing.expect(std.mem.indexOf(u8, meta.timeout.description, "milliseconds") != null);
    try std.testing.expectEqualStrings("Number of retry attempts", meta.retries.description);
}
