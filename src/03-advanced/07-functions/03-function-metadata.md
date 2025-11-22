## Problem

You need to attach metadata or documentation to function arguments for validation, serialization, or documentation purposes.

## Solution

Use struct fields with compile-time reflection to attach metadata:

```zig
{{#include ../../../code/03-advanced/07-functions/recipe_7_3.zig:basic_metadata}}
```

## Discussion

### Validation with Metadata

Automatically validate parameters using metadata:

```zig
{{#include ../../../code/03-advanced/07-functions/recipe_7_3.zig:generic_validator}}
```

### Documentation Generation

Extract documentation from metadata:

```zig
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

const ConfigParams = struct {
    timeout: u32,
    retries: u8,

    pub const metadata = .{
        .timeout = .{ .description = "Timeout in milliseconds" },
        .retries = .{ .description = "Number of retry attempts" },
    };
};

test "documentation generation" {
    const docs = comptime generateDocs(ConfigParams);
    try std.testing.expect(std.mem.indexOf(u8, docs, "timeout") != null);
    try std.testing.expect(std.mem.indexOf(u8, docs, "milliseconds") != null);
}
```

### Type Constraints

Enforce type constraints at compile time:

```zig
{{#include ../../../code/03-advanced/07-functions/recipe_7_3.zig:constrained_types}}
```

### Tagged Parameters

Use enums to tag parameter purposes:

```zig
const ParamTag = enum {
    required,
    optional,
    deprecated,
};

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

            // Warn about deprecated parameters
            if (args_info == .@"struct") {
                inline for (args_info.@"struct".fields) |arg_field| {
                    inline for (@typeInfo(@TypeOf(params)).@"struct".fields) |param_field| {
                        if (std.mem.eql(u8, arg_field.name, param_field.name)) {
                            const param_info = @field(params, param_field.name);
                            if (param_info.tag == .deprecated) {
                                @compileLog("Warning: parameter '" ++ param_field.name ++ "' is deprecated");
                            }
                        }
                    }
                }
            }

            std.debug.print("API call successful\n", .{});
        }
    };
}

const MyApi = ApiFunction(.{
    .username = .{ .tag = .required, .type = []const u8 },
    .email = .{ .tag = .required, .type = []const u8 },
    .phone = .{ .tag = .optional, .type = []const u8 },
});

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
```

### Serialization Metadata

Add serialization hints to struct fields:

```zig
const SerializeInfo = struct {
    json_name: []const u8,
    omit_empty: bool = false,
    format: enum { default, timestamp, base64 } = .default,
};

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
```

### Runtime Parameter Inspection

Inspect parameters at runtime:

```zig
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

test "runtime inspection" {
    inspectParams(ApiParams);
}
```

### Best Practices

**Metadata Structure:**
```zig
// Good: Clear, reusable metadata type
const ParamMeta = struct {
    description: []const u8,
    min: ?i32 = null,
    max: ?i32 = null,
    deprecated: bool = false,
};

// Attach as pub const
pub const metadata = .{
    .field = ParamMeta{ .description = "Field description" },
};
```

**Compile-Time Validation:**
- Use `@compileError` for invalid configurations
- Validate metadata structure at comptime
- Provide clear error messages

**Documentation:**
- Use metadata for automatic documentation generation
- Include usage examples in metadata
- Document constraints and validation rules

**Performance:**
- Metadata is zero-cost at runtime
- Validation can be compile-time when possible
- Use comptime functions to process metadata

### Related Functions

- `@hasDecl()` - Check if type has declaration
- `@hasField()` - Check if struct has field
- `@typeInfo()` - Get type reflection information
- `@typeName()` - Get string name of type
- `@field()` - Access struct field by name
- `@compileError()` - Emit compile-time error
- `@compileLog()` - Emit compile-time warning
