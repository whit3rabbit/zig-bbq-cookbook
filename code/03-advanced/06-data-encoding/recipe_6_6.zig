// Recipe 6.6: Interacting with a Relational Database (SQLite)
// Target Zig Version: 0.15.2
//
// This recipe demonstrates two approaches to SQLite database interaction:
// 1. Beginner: Using a simple wrapper library (zqlite.zig)
// 2. Expert: Using raw C bindings via @cImport
//
// NOTE: To run these examples, you need:
// - SQLite3 development library installed on your system
// - For beginner approach: zqlite dependency added to build.zig.zon
// - build.zig configured to link sqlite3 and libc

const std = @import("std");
const testing = std.testing;

// ============================================================================
// BEGINNER APPROACH: Using zqlite.zig wrapper
// ============================================================================
//
// To use this approach, add to build.zig.zon:
//   zig fetch --save git+https://github.com/karlseguin/zqlite.zig#master
//
// And in build.zig:
//   exe.linkSystemLibrary("sqlite3");
//   exe.linkLibC();
//   const zqlite = b.dependency("zqlite", .{
//       .target = target,
//       .optimize = optimize,
//   });
//   exe.root_module.addImport("zqlite", zqlite.module("zqlite"));

// Uncomment to use with actual zqlite dependency:
// const zqlite = @import("zqlite");

// ANCHOR: setup_beginner
// Beginner setup requires zqlite dependency
// This shows the import and basic types you would use
//
// const zqlite = @import("zqlite");
// const OpenFlags = zqlite.OpenFlags;
//
// Common flags:
// - OpenFlags.Create: Create database if it doesn't exist
// - OpenFlags.ReadWrite: Open for reading and writing
// - OpenFlags.EXResCode: Return extended error codes
// ANCHOR_END: setup_beginner

// ANCHOR: basic_crud_beginner
// Basic CRUD operations with zqlite wrapper
//
// This demonstrates the simple, beginner-friendly API:
//
// test "basic database operations with zqlite" {
//     const allocator = testing.allocator;
//
//     // Open in-memory database for testing
//     const flags = zqlite.OpenFlags.Create | zqlite.OpenFlags.EXResCode;
//     var conn = try zqlite.open(":memory:", flags);
//     defer conn.close(); // Always clean up resources
//
//     // CREATE TABLE
//     try conn.exec(
//         \\CREATE TABLE users (
//         \\    id INTEGER PRIMARY KEY,
//         \\    name TEXT NOT NULL,
//         \\    age INTEGER
//         \\)
//     , .{});
//
//     // INSERT data with parameters (prevents SQL injection)
//     try conn.exec(
//         "INSERT INTO users (name, age) VALUES (?1, ?2), (?3, ?4)",
//         .{ "Alice", 30, "Bob", 25 }
//     );
//
//     // SELECT single row
//     if (try conn.row("SELECT name, age FROM users WHERE name = ?1", .{"Alice"})) |row| {
//         defer row.deinit(); // Clean up row resources
//
//         const name = row.text(0);  // Get column 0 as text
//         const age = row.int(1);    // Get column 1 as integer
//
//         try testing.expectEqualStrings("Alice", name);
//         try testing.expectEqual(30, age);
//     }
//
//     // UPDATE
//     try conn.exec("UPDATE users SET age = ?1 WHERE name = ?2", .{ 31, "Alice" });
//
//     // DELETE
//     try conn.exec("DELETE FROM users WHERE name = ?1", .{"Bob"});
// }
// ANCHOR_END: basic_crud_beginner

// ANCHOR: query_multiple_beginner
// Querying multiple rows with iteration
//
// test "query multiple rows with zqlite" {
//     const allocator = testing.allocator;
//
//     const flags = zqlite.OpenFlags.Create;
//     var conn = try zqlite.open(":memory:", flags);
//     defer conn.close();
//
//     try conn.exec(
//         "CREATE TABLE products (id INTEGER, name TEXT, price REAL)",
//         .{}
//     );
//
//     try conn.exec(
//         "INSERT INTO products VALUES (1, 'Widget', 9.99), (2, 'Gadget', 19.99), (3, 'Doohickey', 4.99)",
//         .{}
//     );
//
//     // Query multiple rows
//     var rows = try conn.rows("SELECT name, price FROM products WHERE price < ?1 ORDER BY price", .{15.0});
//     defer rows.deinit();
//
//     var count: usize = 0;
//     while (rows.next()) |row| {
//         count += 1;
//         const name = row.text(0);
//         const price = row.float(1);
//         std.debug.print("{s}: ${d:.2}\n", .{ name, price });
//     }
//
//     try testing.expectEqual(2, count); // Widget and Doohickey
//
//     // Always check for iteration errors
//     if (rows.err) |err| return err;
// }
// ANCHOR_END: query_multiple_beginner

// ============================================================================
// EXPERT APPROACH: Raw C bindings with @cImport
// ============================================================================

// ANCHOR: setup_expert
// Expert setup using raw C bindings
// Requires sqlite3 development libraries installed
//
// In build.zig:
//   exe.linkSystemLibrary("sqlite3");
//   exe.linkLibC();

const c = @cImport({
    @cInclude("sqlite3.h");
});

// SQLite error codes we'll check
const SQLITE_OK = 0;
const SQLITE_ROW = 100;
const SQLITE_DONE = 101;
// ANCHOR_END: setup_expert

// ANCHOR: error_handling_expert
// Custom error handling for SQLite C API
const SqliteError = error{
    OpenFailed,
    PrepareFailed,
    ExecFailed,
    BindFailed,
    StepFailed,
    FinalizeFailed,
};

// Helper to check SQLite result codes
fn checkSqlite(result: c_int) SqliteError!void {
    if (result != SQLITE_OK) {
        return SqliteError.ExecFailed;
    }
}
// ANCHOR_END: error_handling_expert

// ANCHOR: basic_crud_expert
// Basic CRUD operations using raw C API
test "basic database operations with raw C API" {
    var db: ?*c.sqlite3 = null;

    // Open database - returns error code
    var result = c.sqlite3_open(":memory:", &db);
    if (result != SQLITE_OK) {
        std.debug.print("Failed to open database: {d}\n", .{result});
        return SqliteError.OpenFailed;
    }
    // Must close database when done
    defer _ = c.sqlite3_close(db);

    // CREATE TABLE
    const create_sql = "CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, age INTEGER)";
    result = c.sqlite3_exec(db, create_sql, null, null, null);
    try checkSqlite(result);

    // INSERT using prepared statement
    const insert_sql = "INSERT INTO users (name, age) VALUES (?1, ?2)";
    var insert_stmt: ?*c.sqlite3_stmt = null;

    result = c.sqlite3_prepare_v2(db, insert_sql, -1, &insert_stmt, null);
    if (result != SQLITE_OK) return SqliteError.PrepareFailed;
    defer _ = c.sqlite3_finalize(insert_stmt);

    // Bind parameters (indices start at 1)
    result = c.sqlite3_bind_text(insert_stmt, 1, "Alice", -1, null);
    try checkSqlite(result);
    result = c.sqlite3_bind_int(insert_stmt, 2, 30);
    try checkSqlite(result);

    // Execute
    result = c.sqlite3_step(insert_stmt);
    if (result != SQLITE_DONE) return SqliteError.StepFailed;

    // Reset and insert another row
    _ = c.sqlite3_reset(insert_stmt);
    result = c.sqlite3_bind_text(insert_stmt, 1, "Bob", -1, null);
    try checkSqlite(result);
    result = c.sqlite3_bind_int(insert_stmt, 2, 25);
    try checkSqlite(result);
    result = c.sqlite3_step(insert_stmt);
    if (result != SQLITE_DONE) return SqliteError.StepFailed;

    // SELECT query
    const select_sql = "SELECT name, age FROM users WHERE age > ?1";
    var select_stmt: ?*c.sqlite3_stmt = null;

    result = c.sqlite3_prepare_v2(db, select_sql, -1, &select_stmt, null);
    if (result != SQLITE_OK) return SqliteError.PrepareFailed;
    defer _ = c.sqlite3_finalize(select_stmt);

    result = c.sqlite3_bind_int(select_stmt, 1, 26);
    try checkSqlite(result);

    // Fetch results
    var found_alice = false;
    while (c.sqlite3_step(select_stmt) == SQLITE_ROW) {
        // Get column values (indices start at 0)
        const name_ptr = c.sqlite3_column_text(select_stmt, 0);
        const age = c.sqlite3_column_int(select_stmt, 1);

        // Convert C string to Zig slice
        const name = std.mem.span(@as([*:0]const u8, @ptrCast(name_ptr)));

        if (std.mem.eql(u8, name, "Alice")) {
            found_alice = true;
            try testing.expectEqual(30, age);
        }
    }

    try testing.expect(found_alice);
}
// ANCHOR_END: basic_crud_expert

// ANCHOR: transactions_expert
// Transaction handling with errdefer for automatic rollback
test "transactions with raw C API" {
    var db: ?*c.sqlite3 = null;
    var result = c.sqlite3_open(":memory:", &db);
    if (result != SQLITE_OK) return SqliteError.OpenFailed;
    defer _ = c.sqlite3_close(db);

    // Create table
    const create_sql = "CREATE TABLE logs (id INTEGER PRIMARY KEY, message TEXT)";
    result = c.sqlite3_exec(db, create_sql, null, null, null);
    try checkSqlite(result);

    // Begin transaction
    result = c.sqlite3_exec(db, "BEGIN TRANSACTION", null, null, null);
    try checkSqlite(result);

    // Use errdefer to rollback on error
    errdefer _ = c.sqlite3_exec(db, "ROLLBACK", null, null, null);

    // Multiple inserts in transaction
    const insert1 = "INSERT INTO logs (message) VALUES ('Started')";
    result = c.sqlite3_exec(db, insert1, null, null, null);
    try checkSqlite(result);

    const insert2 = "INSERT INTO logs (message) VALUES ('Processing')";
    result = c.sqlite3_exec(db, insert2, null, null, null);
    try checkSqlite(result);

    const insert3 = "INSERT INTO logs (message) VALUES ('Completed')";
    result = c.sqlite3_exec(db, insert3, null, null, null);
    try checkSqlite(result);

    // Commit transaction
    result = c.sqlite3_exec(db, "COMMIT", null, null, null);
    try checkSqlite(result);

    // Verify all rows were inserted
    const count_sql = "SELECT COUNT(*) FROM logs";
    var stmt: ?*c.sqlite3_stmt = null;
    result = c.sqlite3_prepare_v2(db, count_sql, -1, &stmt, null);
    if (result != SQLITE_OK) return SqliteError.PrepareFailed;
    defer _ = c.sqlite3_finalize(stmt);

    if (c.sqlite3_step(stmt) == SQLITE_ROW) {
        const count = c.sqlite3_column_int(stmt, 0);
        try testing.expectEqual(3, count);
    }
}
// ANCHOR_END: transactions_expert

// ANCHOR: prepared_statements_expert
// Reusing prepared statements efficiently
test "reusable prepared statements" {
    var db: ?*c.sqlite3 = null;
    var result = c.sqlite3_open(":memory:", &db);
    if (result != SQLITE_OK) return SqliteError.OpenFailed;
    defer _ = c.sqlite3_close(db);

    const create_sql = "CREATE TABLE scores (player TEXT, score INTEGER)";
    result = c.sqlite3_exec(db, create_sql, null, null, null);
    try checkSqlite(result);

    // Prepare statement once
    const insert_sql = "INSERT INTO scores (player, score) VALUES (?1, ?2)";
    var stmt: ?*c.sqlite3_stmt = null;
    result = c.sqlite3_prepare_v2(db, insert_sql, -1, &stmt, null);
    if (result != SQLITE_OK) return SqliteError.PrepareFailed;
    defer _ = c.sqlite3_finalize(stmt);

    // Reuse statement for multiple inserts
    const players = [_][]const u8{ "Alice", "Bob", "Charlie" };
    const scores = [_]i32{ 100, 85, 92 };

    for (players, scores) |player, score| {
        // Reset statement for reuse
        _ = c.sqlite3_reset(stmt);
        _ = c.sqlite3_clear_bindings(stmt);

        // Bind new values
        result = c.sqlite3_bind_text(stmt, 1, player.ptr, @intCast(player.len), null);
        try checkSqlite(result);
        result = c.sqlite3_bind_int(stmt, 2, score);
        try checkSqlite(result);

        // Execute
        result = c.sqlite3_step(stmt);
        if (result != SQLITE_DONE) return SqliteError.StepFailed;
    }

    // Verify inserts
    const count_sql = "SELECT COUNT(*) FROM scores";
    var count_stmt: ?*c.sqlite3_stmt = null;
    result = c.sqlite3_prepare_v2(db, count_sql, -1, &count_stmt, null);
    if (result != SQLITE_OK) return SqliteError.PrepareFailed;
    defer _ = c.sqlite3_finalize(count_stmt);

    if (c.sqlite3_step(count_stmt) == SQLITE_ROW) {
        const count = c.sqlite3_column_int(count_stmt, 0);
        try testing.expectEqual(3, count);
    }
}
// ANCHOR_END: prepared_statements_expert

// ANCHOR: resource_management_pattern
// Pattern for safe resource management in Zig with SQLite
//
// Key principles:
// 1. Always use defer for cleanup immediately after resource acquisition
// 2. Use errdefer for error-path cleanup (e.g., transaction rollback)
// 3. Check all return codes - SQLite uses integers, not Zig errors
// 4. Prepare statements once, reuse multiple times
// 5. Use :memory: databases for tests to avoid filesystem dependencies
//
// Example pattern:
//
// var db: ?*c.sqlite3 = null;
// if (c.sqlite3_open(path, &db) != SQLITE_OK) return error.OpenFailed;
// defer _ = c.sqlite3_close(db);
//
// var stmt: ?*c.sqlite3_stmt = null;
// if (c.sqlite3_prepare_v2(db, sql, -1, &stmt, null) != SQLITE_OK)
//     return error.PrepareFailed;
// defer _ = c.sqlite3_finalize(stmt);
//
// // Use errdefer for transactions
// _ = c.sqlite3_exec(db, "BEGIN", null, null, null);
// errdefer _ = c.sqlite3_exec(db, "ROLLBACK", null, null, null);
// // ... operations ...
// _ = c.sqlite3_exec(db, "COMMIT", null, null, null);
// ANCHOR_END: resource_management_pattern
