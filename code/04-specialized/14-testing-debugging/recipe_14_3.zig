const std = @import("std");
const testing = std.testing;

// ANCHOR: basic_error_testing
fn divide(a: i32, b: i32) !i32 {
    if (b == 0) return error.DivisionByZero;
    return @divTrunc(a, b);
}

test "expect specific error" {
    const result = divide(10, 0);
    try testing.expectError(error.DivisionByZero, result);
}

test "successful operation returns value" {
    const result = try divide(10, 2);
    try testing.expectEqual(@as(i32, 5), result);
}
// ANCHOR_END: basic_error_testing

// ANCHOR: multiple_errors
const FileError = error{
    NotFound,
    PermissionDenied,
    TooLarge,
    InvalidFormat,
};

fn readFile(path: []const u8, max_size: usize) FileError![]const u8 {
    if (path.len == 0) return error.NotFound;
    if (std.mem.startsWith(u8, path, "/restricted/")) return error.PermissionDenied;
    if (std.mem.startsWith(u8, path, "/large/")) return error.TooLarge;
    if (std.mem.endsWith(u8, path, ".bin")) return error.InvalidFormat;
    _ = max_size;
    return "file contents";
}

test "file not found error" {
    try testing.expectError(error.NotFound, readFile("", 1024));
}

test "permission denied error" {
    try testing.expectError(error.PermissionDenied, readFile("/restricted/secret.txt", 1024));
}

test "file too large error" {
    try testing.expectError(error.TooLarge, readFile("/large/data.txt", 1024));
}

test "invalid format error" {
    try testing.expectError(error.InvalidFormat, readFile("/data/file.bin", 1024));
}

test "successful file read" {
    const contents = try readFile("/data/file.txt", 1024);
    try testing.expectEqualStrings("file contents", contents);
}
// ANCHOR_END: multiple_errors

// ANCHOR: error_context
const ValidationError = error{ TooShort, TooLong, InvalidCharacter, EmptyString };

const ValidationResult = struct {
    valid: bool,
    error_msg: ?[]const u8 = null,
};

fn validatePassword(password: []const u8) ValidationError!ValidationResult {
    if (password.len == 0) {
        return error.EmptyString;
    }
    if (password.len < 8) {
        return error.TooShort;
    }
    if (password.len > 128) {
        return error.TooLong;
    }
    for (password) |char| {
        if (char < 32 or char > 126) {
            return error.InvalidCharacter;
        }
    }
    return .{ .valid = true };
}

test "password validation errors" {
    try testing.expectError(error.EmptyString, validatePassword(""));
    try testing.expectError(error.TooShort, validatePassword("short"));
    try testing.expectError(error.TooLong, validatePassword("a" ** 129));
    try testing.expectError(error.InvalidCharacter, validatePassword("pass\x00word"));
}

test "valid password" {
    const result = try validatePassword("ValidPass123!");
    try testing.expect(result.valid);
}
// ANCHOR_END: error_context

// ANCHOR: error_propagation
fn innerOperation(value: i32) !i32 {
    if (value < 0) return error.NegativeValue;
    return value * 2;
}

fn middleOperation(value: i32) !i32 {
    const result = try innerOperation(value);
    return result + 10;
}

fn outerOperation(value: i32) !i32 {
    const result = try middleOperation(value);
    return result * 3;
}

test "error propagates through call stack" {
    try testing.expectError(error.NegativeValue, outerOperation(-5));
}

test "successful propagation through stack" {
    // innerOperation(5) = 10, middleOperation = 20, outerOperation = 60
    const result = try outerOperation(5);
    try testing.expectEqual(@as(i32, 60), result);
}
// ANCHOR_END: error_propagation

// ANCHOR: error_union_checking
fn parseNumber(str: []const u8) !i32 {
    if (str.len == 0) return error.EmptyString;
    return std.fmt.parseInt(i32, str, 10);
}

test "check error union type" {
    const result = parseNumber("invalid");

    // Check if result is an error
    if (result) |value| {
        // This path shouldn't be taken
        _ = value;
        try testing.expect(false);
    } else |err| {
        // Verify it's a parse error
        try testing.expect(err == error.InvalidCharacter);
    }
}

test "check successful value" {
    const result = parseNumber("42");

    if (result) |value| {
        try testing.expectEqual(@as(i32, 42), value);
    } else |_| {
        try testing.expect(false);
    }
}
// ANCHOR_END: error_union_checking

// ANCHOR: error_recovery
fn fetchDataWithRetry(url: []const u8, max_retries: u32) ![]const u8 {
    var retries: u32 = 0;
    while (retries < max_retries) : (retries += 1) {
        if (std.mem.eql(u8, url, "fail")) {
            if (retries < max_retries - 1) continue; // Retry
            return error.MaxRetriesExceeded;
        }
        return "success data";
    }
    return error.MaxRetriesExceeded;
}

test "error recovery with retries" {
    try testing.expectError(error.MaxRetriesExceeded, fetchDataWithRetry("fail", 3));
}

test "successful fetch" {
    const data = try fetchDataWithRetry("https://api.example.com", 3);
    try testing.expectEqualStrings("success data", data);
}
// ANCHOR_END: error_recovery

// ANCHOR: custom_error_messages
const Parser = struct {
    input: []const u8,
    pos: usize = 0,

    const Error = error{ UnexpectedToken, EndOfInput, InvalidSyntax };

    fn expect(self: *Parser, expected: u8) Error!void {
        if (self.pos >= self.input.len) return error.EndOfInput;
        if (self.input[self.pos] != expected) return error.UnexpectedToken;
        self.pos += 1;
    }

    fn parseList(self: *Parser) Error!void {
        try self.expect('[');
        if (self.pos >= self.input.len) return error.EndOfInput;
        if (self.input[self.pos] == ']') {
            self.pos += 1;
            return;
        }
        while (self.pos < self.input.len and self.input[self.pos] != ']') {
            self.pos += 1;
        }
        if (self.pos >= self.input.len) return error.InvalidSyntax;
        self.pos += 1;
    }
};

test "parser error conditions" {
    var parser1 = Parser{ .input = "hello" };
    try testing.expectError(error.UnexpectedToken, parser1.expect('['));

    var parser2 = Parser{ .input = "" };
    try testing.expectError(error.EndOfInput, parser2.expect('['));

    var parser3 = Parser{ .input = "[incomplete" };
    try testing.expectError(error.InvalidSyntax, parser3.parseList());
}

test "successful parsing" {
    var parser = Parser{ .input = "[items]" };
    try parser.parseList();
    try testing.expectEqual(@as(usize, 7), parser.pos);
}
// ANCHOR_END: custom_error_messages

// ANCHOR: anyerror_testing
fn dynamicOperation(op: []const u8, a: i32, b: i32) anyerror!i32 {
    if (std.mem.eql(u8, op, "add")) return a + b;
    if (std.mem.eql(u8, op, "sub")) return a - b;
    if (std.mem.eql(u8, op, "div")) {
        if (b == 0) return error.DivisionByZero;
        return @divTrunc(a, b);
    }
    return error.UnknownOperation;
}

test "anyerror operations" {
    try testing.expectError(error.UnknownOperation, dynamicOperation("mult", 5, 3));
    try testing.expectError(error.DivisionByZero, dynamicOperation("div", 10, 0));

    const add_result = try dynamicOperation("add", 5, 3);
    try testing.expectEqual(@as(i32, 8), add_result);
}
// ANCHOR_END: anyerror_testing

// ANCHOR: error_trace
const ProcessError = error{ InvalidInput, ProcessingFailed, OutputError };

fn processStep1(data: []const u8) ProcessError![]const u8 {
    if (data.len == 0) return error.InvalidInput;
    return data;
}

fn processStep2(data: []const u8) ProcessError![]const u8 {
    if (data.len < 3) return error.ProcessingFailed;
    return data;
}

fn processStep3(data: []const u8) ProcessError![]const u8 {
    if (!std.mem.startsWith(u8, data, "valid")) return error.OutputError;
    return data;
}

fn processData(input: []const u8) ProcessError![]const u8 {
    const step1 = try processStep1(input);
    const step2 = try processStep2(step1);
    return processStep3(step2);
}

test "error at different processing steps" {
    try testing.expectError(error.InvalidInput, processData(""));
    try testing.expectError(error.ProcessingFailed, processData("ab"));
    try testing.expectError(error.OutputError, processData("invalid"));
}

test "successful processing" {
    const result = try processData("valid data");
    try testing.expectEqualStrings("valid data", result);
}
// ANCHOR_END: error_trace
