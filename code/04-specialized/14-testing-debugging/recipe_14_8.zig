const std = @import("std");
const testing = std.testing;

// ANCHOR: basic_error_set
const FileError = error{
    NotFound,
    PermissionDenied,
    AlreadyExists,
};

fn openFile(path: []const u8) FileError!void {
    if (std.mem.eql(u8, path, "missing.txt")) {
        return error.NotFound;
    }
    if (std.mem.eql(u8, path, "protected.txt")) {
        return error.PermissionDenied;
    }
    // Success
}

test "define and use custom error set" {
    try testing.expectError(error.NotFound, openFile("missing.txt"));
    try testing.expectError(error.PermissionDenied, openFile("protected.txt"));
    try openFile("valid.txt");
}
// ANCHOR_END: basic_error_set

// ANCHOR: composing_errors
const NetworkError = error{
    ConnectionRefused,
    Timeout,
    HostUnreachable,
};

const DatabaseError = error{
    QueryFailed,
    ConnectionLost,
    ConstraintViolation,
};

// Combine error sets with ||
const ServiceError = NetworkError || DatabaseError;

fn fetchData(source: u8) ServiceError![]const u8 {
    switch (source) {
        0 => return error.ConnectionRefused,
        1 => return error.QueryFailed,
        2 => return error.Timeout,
        else => return "data",
    }
}

test "compose multiple error sets" {
    try testing.expectError(error.ConnectionRefused, fetchData(0));
    try testing.expectError(error.QueryFailed, fetchData(1));
    try testing.expectError(error.Timeout, fetchData(2));
    try testing.expectEqualStrings("data", try fetchData(99));
}
// ANCHOR_END: composing_errors

// ANCHOR: inferred_errors
fn processValue(value: i32) !i32 {
    if (value < 0) return error.NegativeValue;
    if (value == 0) return error.ZeroValue;
    if (value > 100) return error.TooLarge;
    return value * 2;
}

test "error set inference" {
    try testing.expectError(error.NegativeValue, processValue(-1));
    try testing.expectError(error.ZeroValue, processValue(0));
    try testing.expectError(error.TooLarge, processValue(200));
    try testing.expectEqual(@as(i32, 20), try processValue(10));
}
// ANCHOR_END: inferred_errors

// ANCHOR: hierarchical_errors
const ValidationError = error{
    InvalidEmail,
    InvalidPhone,
    InvalidZipCode,
};

const AuthError = error{
    InvalidCredentials,
    SessionExpired,
    AccountLocked,
};

const UserError = ValidationError || AuthError;

const User = struct {
    email: []const u8,
    phone: []const u8,

    fn validate(self: User) ValidationError!void {
        if (!std.mem.containsAtLeast(u8, self.email, 1, "@")) {
            return error.InvalidEmail;
        }
        if (self.phone.len < 10) {
            return error.InvalidPhone;
        }
    }

    fn authenticate(self: User, password: []const u8) AuthError!void {
        _ = self;
        if (password.len < 8) {
            return error.InvalidCredentials;
        }
    }

    fn register(self: User, password: []const u8) UserError!void {
        try self.validate();
        try self.authenticate(password);
    }
};

test "hierarchical error sets" {
    const user1 = User{ .email = "invalid", .phone = "1234567890" };
    try testing.expectError(error.InvalidEmail, user1.validate());

    const user2 = User{ .email = "test@example.com", .phone = "123" };
    try testing.expectError(error.InvalidPhone, user2.validate());

    const user3 = User{ .email = "test@example.com", .phone = "1234567890" };
    try testing.expectError(error.InvalidCredentials, user3.register("short"));
}
// ANCHOR_END: hierarchical_errors

// ANCHOR: domain_errors
const OrderError = error{
    InsufficientInventory,
    InvalidQuantity,
    PriceMismatch,
};

const PaymentError = error{
    InsufficientFunds,
    CardDeclined,
    PaymentGatewayError,
};

const ShippingError = error{
    InvalidAddress,
    ShippingUnavailable,
    WeightExceeded,
};

const CheckoutError = OrderError || PaymentError || ShippingError;

fn placeOrder(step: u8) CheckoutError!void {
    switch (step) {
        0 => return error.InsufficientInventory,
        1 => return error.InsufficientFunds,
        2 => return error.InvalidAddress,
        else => {},
    }
}

test "domain-specific error sets" {
    try testing.expectError(error.InsufficientInventory, placeOrder(0));
    try testing.expectError(error.InsufficientFunds, placeOrder(1));
    try testing.expectError(error.InvalidAddress, placeOrder(2));
    try placeOrder(99);
}
// ANCHOR_END: domain_errors

// ANCHOR: error_context
const ParseError = error{
    UnexpectedToken,
    UnexpectedEOF,
    InvalidSyntax,
};

const ParseResult = struct {
    error_type: ?ParseError,
    line: usize,
    column: usize,
    message: []const u8,

    fn fromError(err: ParseError, line: usize, column: usize) ParseResult {
        const message = switch (err) {
            error.UnexpectedToken => "Unexpected token",
            error.UnexpectedEOF => "Unexpected end of file",
            error.InvalidSyntax => "Invalid syntax",
        };
        return .{
            .error_type = err,
            .line = line,
            .column = column,
            .message = message,
        };
    }

    fn success() ParseResult {
        return .{
            .error_type = null,
            .line = 0,
            .column = 0,
            .message = "Success",
        };
    }
};

fn parseWithContext(input: []const u8) ParseError!ParseResult {
    if (input.len == 0) return error.UnexpectedEOF;
    if (input[0] == '!') return error.UnexpectedToken;
    return ParseResult.success();
}

test "error context and metadata" {
    const result = parseWithContext("!invalid") catch |err| {
        const context = ParseResult.fromError(err, 1, 5);
        try testing.expectEqual(error.UnexpectedToken, context.error_type.?);
        try testing.expectEqual(@as(usize, 1), context.line);
        try testing.expectEqualStrings("Unexpected token", context.message);
        return;
    };
    try testing.expect(result.error_type == null);
}
// ANCHOR_END: error_context

// ANCHOR: error_conversion
fn convertNetworkError(err: NetworkError) DatabaseError {
    // Convert network errors to database errors
    return switch (err) {
        error.ConnectionRefused, error.HostUnreachable => error.ConnectionLost,
        error.Timeout => error.QueryFailed,
    };
}

test "convert between error sets" {
    try testing.expectEqual(error.ConnectionLost, convertNetworkError(error.ConnectionRefused));
    try testing.expectEqual(error.QueryFailed, convertNetworkError(error.Timeout));
}
// ANCHOR_END: error_conversion

// ANCHOR: error_namespacing
const Http = struct {
    pub const Error = error{
        BadRequest,
        Unauthorized,
        NotFound,
        ServerError,
    };

    pub fn request(status: u16) Error!void {
        switch (status) {
            400 => return error.BadRequest,
            401 => return error.Unauthorized,
            404 => return error.NotFound,
            500 => return error.ServerError,
            else => {},
        }
    }
};

const Db = struct {
    pub const Error = error{
        NotFound,
        Duplicate,
        ConstraintViolation,
    };

    pub fn query(id: u32) Error!void {
        if (id == 0) return error.NotFound;
        if (id == 999) return error.Duplicate;
    }
};

test "namespaced error sets" {
    try testing.expectError(error.NotFound, Http.request(404));
    try testing.expectError(error.NotFound, Db.query(0));
    try testing.expectError(error.BadRequest, Http.request(400));
}
// ANCHOR_END: error_namespacing

// ANCHOR: error_documentation
/// Errors that can occur during file operations
const IoError = error{
    /// File or directory not found
    NotFound,
    /// Insufficient permissions to access resource
    AccessDenied,
    /// Disk is full or quota exceeded
    NoSpaceLeft,
    /// File or directory already exists
    AlreadyExists,
};

/// Opens a file for reading
/// Returns IoError if the file cannot be opened
fn readFile(path: []const u8) IoError!void {
    if (std.mem.eql(u8, path, "missing")) {
        return error.NotFound;
    }
}

test "documented error sets" {
    try testing.expectError(error.NotFound, readFile("missing"));
}
// ANCHOR_END: error_documentation

// ANCHOR: generic_errors
fn GenericResult(comptime T: type, comptime ErrorSet: type) type {
    return struct {
        data: T,
        err: ?ErrorSet,

        pub fn ok(value: T) @This() {
            return .{ .data = value, .err = null };
        }

        pub fn fail(err: ErrorSet) @This() {
            return .{ .data = undefined, .err = err };
        }

        pub fn unwrap(self: @This()) ErrorSet!T {
            if (self.err) |e| return e;
            return self.data;
        }
    };
}

fn processGeneric(comptime ErrorSet: type, value: i32) ErrorSet!i32 {
    if (value < 0) return error.NotFound;
    return value * 2;
}

test "generic error handling" {
    // Generic result type with FileError
    const FileResult = GenericResult(i32, FileError);
    const success = FileResult.ok(42);
    try testing.expectEqual(@as(i32, 42), try success.unwrap());

    const failure = FileResult.fail(error.NotFound);
    try testing.expectError(error.NotFound, failure.unwrap());

    // Generic function with FileError (which contains NotFound)
    try testing.expectEqual(@as(i32, 20), try processGeneric(FileError, 10));
    try testing.expectError(error.NotFound, processGeneric(FileError, -1));
}
// ANCHOR_END: generic_errors
