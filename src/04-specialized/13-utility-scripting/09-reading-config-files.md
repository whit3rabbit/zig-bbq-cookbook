# Recipe 13.9: Reading Configuration Files

## Problem

You need to load configuration settings from files in various formats like key-value pairs, INI, or JSON.

## Solution

For simple key-value configuration files:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_9.zig:simple_config}}
```

## Discussion

Configuration files are essential for making applications customizable without recompilation. Zig provides flexible tools for parsing various config formats.

### INI-Style Configuration

Parse INI files with sections:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_9.zig:ini_config}}
```

INI files group related settings into sections, making configuration more organized.

### JSON Configuration

For structured configuration, use JSON with type safety:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_9.zig:json_config}}
```

JSON provides strong typing and nesting, perfect for complex configurations.

### Environment Variable Overrides

Allow runtime overrides via environment variables:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_9.zig:env_override}}
```

Environment variables let users customize settings without modifying files.

### Type-Safe Accessors

Provide typed accessors for configuration values:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_9.zig:typed_config}}
```

Type-safe accessors catch configuration errors early with clear error messages.

### Default Values

Provide sensible defaults for missing configuration:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_9.zig:default_values}}
```

Defaults make your application work out-of-the-box while remaining customizable.

### Configuration Validation

Validate configuration at load time:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_9.zig:validation}}
```

Early validation prevents runtime errors from invalid configuration.

### Merging Configurations

Combine multiple configuration sources:

```zig
{{#include ../../../code/04-specialized/13-utility-scripting/recipe_13_9.zig:config_merge}}
```

Merging enables layered configuration: defaults, system config, user config, command-line overrides.

### Best Practices

1. **Provide defaults** - Application should work with minimal configuration
2. **Validate early** - Check configuration at startup, not during execution
3. **Clear error messages** - Tell users exactly what's wrong and how to fix it
4. **Document format** - Provide example configuration files
5. **Support comments** - Allow users to document their configuration
6. **Use appropriate format** - Simple settings use key-value, complex use JSON/TOML
7. **Environment overrides** - Support env vars for deployment flexibility

### Configuration Priority

Common precedence order (highest to lowest):
1. Command-line arguments
2. Environment variables
3. User configuration file (`~/.config/app/config`)
4. System configuration file (`/etc/app/config`)
5. Built-in defaults

### File Formats Comparison

**Key-Value (Simple):**
- ✓ Easy to read and write
- ✓ Minimal syntax
- ✗ No nesting
- ✗ No types
- Best for: Simple applications, dotenv files

**INI:**
- ✓ Human-readable
- ✓ Sections for organization
- ✗ Limited nesting
- ✗ No standard for types
- Best for: Traditional desktop applications

**JSON:**
- ✓ Well-defined format
- ✓ Strong typing
- ✓ Nesting support
- ✗ No comments (standard)
- ✗ Verbose for simple configs
- Best for: Structured data, web applications

**TOML** (not shown, but popular):
- ✓ Human-friendly
- ✓ Strong typing
- ✓ Comments supported
- ✓ Good nesting
- Best for: Modern applications, Rust ecosystem

### Example Usage

```zig
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Load configuration
    var config = try SimpleConfig.loadFromFile(allocator, "config.txt");
    defer config.deinit();

    // Validate
    try validateConfig(&config);

    // Use configuration
    const port = try std.fmt.parseInt(u16, config.getRequired("port"), 10);
    const host = config.get("host") orelse "localhost";

    std.debug.print("Starting server on {s}:{d}\n", .{ host, port });
}
```

### Common Patterns

**Layered Configuration:**
```zig
var defaults = ConfigWithDefaults.init(allocator);
defer defaults.deinit();

try defaults.setDefault("port", "8080");
try defaults.setDefault("host", "0.0.0.0");
try defaults.setDefault("debug", "false");

// Load user config (overrides defaults)
var user_config = try SimpleConfig.loadFromFile(allocator, "config.txt");
defer user_config.deinit();

// Merge: user config overrides defaults
const configs = [_]SimpleConfig{ defaults.config, user_config };
var final_config = try mergeConfigs(allocator, &configs);
defer final_config.deinit();
```

**Development vs Production:**
```zig
const config_file = if (std.process.getEnvVarOwned(allocator, "ENV")) |env|
    if (std.mem.eql(u8, env, "production"))
        "config.prod.json"
    else
        "config.dev.json"
else
    "config.dev.json";

var config = try loadJsonConfig(allocator, AppConfig, config_file);
defer config.deinit();
```

**Hot Reload:**
```zig
var last_modified: i128 = 0;

while (true) {
    const stat = try std.fs.cwd().statFile("config.txt");
    if (stat.mtime > last_modified) {
        // Reload configuration
        var new_config = try SimpleConfig.loadFromFile(allocator, "config.txt");
        old_config.deinit();
        old_config = new_config;
        last_modified = stat.mtime;
        std.debug.print("Configuration reloaded\n", .{});
    }
    std.time.sleep(5 * std.time.ns_per_s); // Check every 5 seconds
}
```

### Security Considerations

**File Permissions:**
- Configuration files may contain secrets
- Ensure proper file permissions (0600 for sensitive configs)
- Never commit secrets to version control

**Path Traversal:**
- Validate configuration file paths
- Don't blindly trust user-provided paths
- Use absolute paths or carefully validate relative paths

**Injection:**
- Sanitize values used in commands or SQL
- Don't directly execute configuration values
- Validate all inputs

### Error Handling

```zig
const config = SimpleConfig.loadFromFile(allocator, "config.txt") catch |err| {
    switch (err) {
        error.FileNotFound => {
            std.debug.print("Config file not found, using defaults\n", .{});
            return SimpleConfig.init(allocator); // Use defaults
        },
        error.AccessDenied => {
            std.debug.print("Cannot read config file: permission denied\n", .{});
            return err;
        },
        else => return err,
    }
};
```

## See Also

- Recipe 13.15: Parsing command-line options
- Recipe 5.1: Reading and writing text data
- Recipe 6.2: Reading and writing JSON data

Full compilable example: `code/04-specialized/13-utility-scripting/recipe_13_9.zig`
