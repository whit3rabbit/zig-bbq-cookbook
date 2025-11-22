# Installing Zig and Verifying Your Toolchain

## Problem

You want to start programming in Zig. You need to download it, install it, and make sure everything works before writing any code.

## Solution

### Step 1: Download Zig

Visit [https://ziglang.org/download/](https://ziglang.org/download/) and choose:

- **0.15.2** (stable - recommended for this cookbook)
- Or the latest development build if you want cutting-edge features

Download the archive for your platform:
- **macOS**: `zig-macos-aarch64-0.15.2.tar.xz` (Apple Silicon) or `zig-macos-x86_64-0.15.2.tar.xz` (Intel)
- **Linux**: `zig-linux-x86_64-0.15.2.tar.xz` or your architecture
- **Windows**: `zig-windows-x86_64-0.15.2.zip`

### Step 2: Extract and Add to PATH

**macOS/Linux:**
```bash
# Extract
tar xf zig-macos-aarch64-0.15.2.tar.xz

# Move to a permanent location
sudo mv zig-macos-aarch64-0.15.2 /usr/local/zig

# Add to PATH (add this to your ~/.zshrc or ~/.bashrc)
export PATH="/usr/local/zig:$PATH"

# Reload your shell
source ~/.zshrc  # or ~/.bashrc
```

**Windows:**
1. Extract the ZIP file to `C:\zig\`
2. Add `C:\zig\` to your PATH environment variable
3. Restart your terminal

### Step 3: Verify Installation

Run these commands to verify Zig is installed correctly:

```bash
# Check version
zig version
# Should output: 0.15.2 (or your installed version)

# Check environment
zig env
# Shows paths and configuration
```

### Step 4: Test Your Installation

Create a simple test file to make sure everything works:

```zig
{{#include ../../code/00-bootcamp/recipe_0_2.zig:verify_version}}
```

Run it:
```bash
zig test verify.zig
```

If you see "All 1 tests passed", you're ready to go!

## Discussion

### Understanding `zig version`

When you run `zig version`, you'll see output like:
```
0.15.2
```

This tells you exactly which version of Zig you're running. This matters because Zig is still evolving, and different versions have different features and APIs.

### Understanding `zig env`

The `zig env` command shows your environment configuration:

```json
{
  "zig_exe": "/usr/local/zig/zig",
  "lib_dir": "/usr/local/zig/lib",
  "std_dir": "/usr/local/zig/lib/std",
  "global_cache_dir": "/Users/you/.cache/zig",
  "version": "0.15.2"
}
```

This tells you:
- Where Zig is installed
- Where the standard library lives
- Where cached build artifacts go

You can check this information in code too:

```zig
{{#include ../../code/00-bootcamp/recipe_0_2.zig:environment_info}}
```

This is super useful for cross-compilation (we'll cover that later).

### Code Formatting with `zig fmt`

Zig includes an opinionated code formatter. You don't need to debate formatting styles - just use `zig fmt`:

```bash
# Format a single file
zig fmt myfile.zig

# Format all .zig files in current directory
zig fmt .

# Check if files are formatted (useful for CI)
zig fmt --check .
```

The formatter expects:
- 4-space indentation
- Opening braces on the same line
- Trailing commas in multi-line lists
- Consistent spacing

Example of properly formatted code:

```zig
{{#include ../../code/00-bootcamp/recipe_0_2.zig:format_check}}
```

**Pro tip**: Set up your editor to run `zig fmt` on save. This keeps your code clean automatically.

### Build Modes

Zig has four build modes that you can check at compile time:

```zig
{{#include ../../code/00-bootcamp/recipe_0_2.zig:build_modes}}
```

- **Debug**: Default mode, all safety checks, easier debugging
- **ReleaseSafe**: Optimized but keeps safety checks
- **ReleaseFast**: Maximum speed, some safety disabled
- **ReleaseSmall**: Smallest binary size

For learning, stick with Debug mode (the default).

### Common Commands Quick Reference

```bash
# Version and environment
zig version              # Show Zig version
zig env                  # Show environment settings

# Code formatting
zig fmt file.zig         # Format a file
zig fmt .                # Format all files in current directory
zig fmt --check .        # Check formatting without modifying

# Compilation and running
zig run file.zig         # Compile and run a program
zig build-exe file.zig   # Compile to executable
zig build-lib file.zig   # Compile to library
zig test file.zig        # Run tests

# Build system
zig build                # Run build.zig script
zig init-exe             # Create a new executable project
zig init-lib             # Create a new library project
```

### Troubleshooting

**Problem**: `zig: command not found`
- **Solution**: Zig isn't in your PATH. Double-check Step 2 above.

**Problem**: `zig version` shows old version
- **Solution**: You have multiple Zig installations. Check `which zig` (Unix) or `where zig` (Windows) to see which one is being used.

**Problem**: Tests fail with weird errors
- **Solution**: Make sure you're using Zig 0.15.2. Earlier versions have different APIs.

**Problem**: Editor doesn't recognize Zig
- **Solution**: Install the Zig Language Server (ZLS) for your editor. See [zigtools.org](https://zigtools.org/) for setup.

## See Also

- Recipe 0.3: Your First Zig Program - Now that Zig is installed, write your first program
- Recipe 0.14: Projects, Modules, and Dependencies - Using `zig init` and `build.zig`

Full compilable example: `code/00-bootcamp/recipe_0_2.zig`
