## Problem

You need to store and query structured data using a relational database, specifically SQLite. You want to know the best way to integrate SQLite into your Zig application, whether using a wrapper library for convenience or raw C bindings for maximum control.

## Solution

Zig offers two main approaches to working with SQLite databases:

### Beginner Approach: Using a Wrapper Library

For most applications, using a thin wrapper like `zqlite.zig` provides a clean, easy-to-use API while still staying close to SQLite's behavior.

#### Setup Beginner

```zig
{{#include ../../../code/03-advanced/06-data-encoding/recipe_6_6.zig:setup_beginner}}
```

#### Basic CRUD Beginner

```zig
{{#include ../../../code/03-advanced/06-data-encoding/recipe_6_6.zig:basic_crud_beginner}}
```

#### Query Multiple Beginner

```zig
{{#include ../../../code/03-advanced/06-data-encoding/recipe_6_6.zig:query_multiple_beginner}}
```

**Querying multiple rows:**

```zig
var rows = try conn.rows(
    "SELECT name, age FROM users WHERE age > ?1 ORDER BY name",
    .{20}
);
defer rows.deinit();

while (rows.next()) |row| {
    const name = row.text(0);
    const age = row.int(1);
    std.debug.print("{s}: {d}\n", .{ name, age });
}

// Always check for iteration errors
if (rows.err) |err| return err;
```

### Expert Approach: Raw C Bindings

For maximum control, educational purposes, or when you need direct access to all SQLite features, you can use `@cImport` to work with the C API directly.

**Setup** (in `build.zig`):

```zig
exe.linkSystemLibrary("sqlite3");
exe.linkLibC();
```

**Import SQLite C API:**

```zig
const c = @cImport({
    @cInclude("sqlite3.h");
});

const SQLITE_OK = 0;
const SQLITE_ROW = 100;
const SQLITE_DONE = 101;

const SqliteError = error{
    OpenFailed,
    PrepareFailed,
    ExecFailed,
    BindFailed,
    StepFailed,
};

fn checkSqlite(result: c_int) SqliteError!void {
    if (result != SQLITE_OK) {
        return SqliteError.ExecFailed;
    }
}
```

**Basic CRUD operations with raw C API:**

```zig
pub fn main() !void {
    var db: ?*c.sqlite3 = null;

    // Open database
    var result = c.sqlite3_open("myapp.db", &db);
    if (result != SQLITE_OK) return SqliteError.OpenFailed;
    defer _ = c.sqlite3_close(db);

    // CREATE TABLE
    const create_sql = "CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, name TEXT, age INTEGER)";
    result = c.sqlite3_exec(db, create_sql, null, null, null);
    try checkSqlite(result);

    // INSERT using prepared statement
    const insert_sql = "INSERT INTO users (name, age) VALUES (?1, ?2)";
    var stmt: ?*c.sqlite3_stmt = null;

    result = c.sqlite3_prepare_v2(db, insert_sql, -1, &stmt, null);
    if (result != SQLITE_OK) return SqliteError.PrepareFailed;
    defer _ = c.sqlite3_finalize(stmt);

    // Bind parameters (indices start at 1)
    result = c.sqlite3_bind_text(stmt, 1, "Alice", -1, null);
    try checkSqlite(result);
    result = c.sqlite3_bind_int(stmt, 2, 30);
    try checkSqlite(result);

    // Execute
    result = c.sqlite3_step(stmt);
    if (result != SQLITE_DONE) return SqliteError.StepFailed;

    // Reset and reuse for another insert
    _ = c.sqlite3_reset(stmt);
    result = c.sqlite3_bind_text(stmt, 1, "Bob", -1, null);
    try checkSqlite(result);
    result = c.sqlite3_bind_int(stmt, 2, 25);
    try checkSqlite(result);
    result = c.sqlite3_step(stmt);
    if (result != SQLITE_DONE) return SqliteError.StepFailed;
}
```

**Querying data:**

```zig
const select_sql = "SELECT name, age FROM users WHERE age > ?1";
var select_stmt: ?*c.sqlite3_stmt = null;

result = c.sqlite3_prepare_v2(db, select_sql, -1, &select_stmt, null);
if (result != SQLITE_OK) return SqliteError.PrepareFailed;
defer _ = c.sqlite3_finalize(select_stmt);

result = c.sqlite3_bind_int(select_stmt, 1, 20);
try checkSqlite(result);

// Iterate through results
while (c.sqlite3_step(select_stmt) == SQLITE_ROW) {
    // Get column values (indices start at 0)
    const name_ptr = c.sqlite3_column_text(select_stmt, 0);
    const age = c.sqlite3_column_int(select_stmt, 1);

    // Convert C string to Zig slice
    const name = std.mem.span(@as([*:0]const u8, @ptrCast(name_ptr)));

    std.debug.print("{s}: {d}\n", .{ name, age });
}
```

**Transactions with proper error handling:**

```zig
// Begin transaction
result = c.sqlite3_exec(db, "BEGIN TRANSACTION", null, null, null);
try checkSqlite(result);

// Use errdefer to rollback on error
errdefer _ = c.sqlite3_exec(db, "ROLLBACK", null, null, null);

// Multiple operations...
try c.sqlite3_exec(db, "INSERT INTO logs (message) VALUES ('Started')", null, null, null);
try c.sqlite3_exec(db, "INSERT INTO logs (message) VALUES ('Processing')", null, null, null);
try c.sqlite3_exec(db, "INSERT INTO logs (message) VALUES ('Completed')", null, null, null);

// Commit if all succeeded
result = c.sqlite3_exec(db, "COMMIT", null, null, null);
try checkSqlite(result);
```

## Discussion

### When to Use Each Approach

**Use a wrapper library (like zqlite.zig) when:**
- You want cleaner, more idiomatic Zig code
- You're building a typical CRUD application
- You prefer type-safe row access with `.text()`, `.int()`, `.float()` methods
- You want less boilerplate and easier error handling
- You're new to Zig or SQLite

**Use raw C bindings when:**
- You need access to advanced SQLite features not exposed by wrappers
- You're learning C interoperability in Zig
- You want zero abstraction overhead
- You're integrating with existing C code
- You need precise control over memory and resource management

### Resource Management Patterns

Both approaches require careful resource management. Zig's `defer` and `errdefer` make this straightforward:

**Key patterns:**
1. Always pair resource acquisition with `defer` cleanup
2. Use `errdefer` for error-path cleanup (especially for transactions)
3. Check all return codes - SQLite uses integer codes, not Zig errors
4. Prepare statements once, reuse multiple times for efficiency
5. Use `:memory:` databases for tests to avoid filesystem dependencies

```zig
var db: ?*c.sqlite3 = null;
if (c.sqlite3_open(path, &db) != SQLITE_OK) return error.OpenFailed;
defer _ = c.sqlite3_close(db);  // Cleanup happens automatically

var stmt: ?*c.sqlite3_stmt = null;
if (c.sqlite3_prepare_v2(db, sql, -1, &stmt, null) != SQLITE_OK)
    return error.PrepareFailed;
defer _ = c.sqlite3_finalize(stmt);  // Statement cleanup
```

### Type Mapping

SQLite has dynamic typing, but you typically access values with specific types:

| SQLite Type | Zig Type | Wrapper Method | C API Function |
|-------------|----------|----------------|----------------|
| INTEGER | `i32`, `i64` | `row.int(i)` | `sqlite3_column_int()` |
| REAL | `f64` | `row.float(i)` | `sqlite3_column_double()` |
| TEXT | `[]const u8` | `row.text(i)` | `sqlite3_column_text()` |
| BLOB | `[]const u8` | `row.blob(i)` | `sqlite3_column_blob()` |
| NULL | `?T` | Check separately | `sqlite3_column_type()` |

### Comparison to Python's sqlite3

If you're coming from Python, here are the key differences:

**Python:**
```python
import sqlite3

conn = sqlite3.connect('myapp.db')
cursor = conn.cursor()
cursor.execute("INSERT INTO users VALUES (?, ?)", ("Alice", 30))
rows = cursor.execute("SELECT * FROM users").fetchall()
conn.commit()
conn.close()
```

**Zig (with wrapper):**
```zig
var conn = try zqlite.open("myapp.db", .{});
defer conn.close();
try conn.exec("INSERT INTO users VALUES (?1, ?2)", .{"Alice", 30});
var rows = try conn.rows("SELECT * FROM users", .{});
defer rows.deinit();
while (rows.next()) |row| { /* process */ }
```

**Key differences:**
- Zig requires explicit error handling with `try`
- Resources must be explicitly freed with `defer`
- Allocators must be passed explicitly when needed
- No automatic transactions - you control when to commit
- Type conversions are explicit
- No context managers - use `defer` instead

### Security: SQL Injection Prevention

Always use parameterized queries, never string concatenation:

**WRONG - Vulnerable to SQL injection:**
```zig
const name = getUserInput();
const sql = try std.fmt.allocPrint(allocator, "SELECT * FROM users WHERE name = '{s}'", .{name});
// DON'T DO THIS!
```

**RIGHT - Safe with parameters:**
```zig
const name = getUserInput();
try conn.exec("SELECT * FROM users WHERE name = ?1", .{name});
// SQLite handles escaping properly
```

### Testing Strategy

Use in-memory databases for unit tests to avoid filesystem dependencies:

```zig
test "database operations" {
    var conn = try zqlite.open(":memory:", .{});
    defer conn.close();

    // Your tests here - database is destroyed when conn.close() runs
}
```

## See Also

- Recipe 5.4: Reading and Writing Binary Data
- Recipe 6.2: Reading and Writing JSON Data
- Recipe 15.1: Accessing C Code Using @cImport
- Recipe 15.7: Managing Memory Between C and Zig Boundaries

Full compilable example: `code/03-advanced/06-data-encoding/recipe_6_6.zig`
