<p align="center">
  <img src="assets/zero_bbq_logo_500px.png" width="300" alt="Zig BBQ Logo" />
</p>

<h1 align="center">Zig BBQ Cookbook</h1>

<p align="center">
  <a href="https://whit3rabbit.github.io/zig-bbq-cookbook"><strong>Read the Cookbook Online</strong></a>
</p>

<p align="center">
  <strong>A comprehensive cookbook-style guide for Zig programming</strong>
</p>

<p align="center">
  <a href="https://whit3rabbit.github.io/zig-bbq-cookbook"><img src="https://img.shields.io/badge/docs-live-blue.svg" alt="Documentation"></a>
  <a href="https://github.com/whit3rabbit/zig-bbq-cookbook/actions"><img src="https://img.shields.io/github/actions/workflow/status/whit3rabbit/zig-bbq-cookbook/gh-pages.yml?branch=main" alt="Build Status"></a>
  <a href="https://ziglang.org/download/"><img src="https://img.shields.io/badge/zig-0.15.2-orange.svg" alt="Zig 0.15.2"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License"></a>
</p>

---

## About

The Zig BBQ Cookbook is a comprehensive, cookbook-style guide teaching Zig programming through practical, tested examples. Organized into 5 phases covering 20 chapters with over 200 recipes, this resource takes you from beginner basics to advanced Zig paradigms.

**Live Documentation**: [https://whit3rabbit.github.io/zig-bbq-cookbook](https://whit3rabbit.github.io/zig-bbq-cookbook)

**Repository**: [https://github.com/whit3rabbit/zig-bbq-cookbook](https://github.com/whit3rabbit/zig-bbq-cookbook)

## Features

- **Code-First Approach**: Every code example is a fully compilable, tested `.zig` file
- **Single Source of Truth**: All markdown documentation uses mdBook's anchor system to include code directly from tested files
- **Comprehensive Testing**: All 239 recipes include tests using `std.testing` with memory leak detection via `testing.allocator`
- **Beginner to Advanced**: Progressive learning path from bootcamp basics to advanced metaprogramming
- **Tested Against Zig 0.15.2**: All code is written for and tested against Zig v0.15.2 (November 2025)

## Progress

**Total: 239 recipes complete (100%)**

### All Phases Complete
- **Phase 0: Zig Bootcamp** - 14/14 recipes (100%)
- **Phase 1: Foundation & Philosophy** - 5/5 recipes (100%)
- **Phase 2: Core Recipes** - 81/81 recipes (100%)
- **Phase 3: Advanced Topics** - 60/60 recipes (100%)
- **Phase 4: Specialized Topics** - 47/47 recipes (100%)
- **Phase 5: Zig Paradigms** - 32/32 recipes (100%)

## Quick Start

### Requirements

- **Zig 0.15.2** - [Download](https://ziglang.org/download/)
- **mdBook** (for building docs) - [Install instructions](https://rust-lang.github.io/mdBook/guide/installation.html)

### Running Tests

Test all recipes to verify everything compiles and works:

```bash
# Test all recipes
zig build test

# Test a specific recipe
zig test code/02-core/01-data-structures/recipe_1_1.zig
```

### Building the Documentation

```bash
# Install mdBook (one-time setup)
cargo install mdbook

# Build the static site
mdbook build

# Serve with live reload during development
mdbook serve

# Clean build artifacts
mdbook clean
```

The site will be built from:
- `src/` - Markdown recipe files
- `code/` - Compilable Zig test files
- `book.toml` - mdBook configuration
- `theme/` - Custom syntax highlighting

Built output appears in `book/` directory.

## Project Structure

```
zig-bbq-cookbook/
├── book.toml                    # mdBook configuration
├── build.zig                    # Zig build configuration (for testing)
├── build.zig.zon                # Package manifest
├── src/                         # Markdown recipes (documentation)
│   ├── SUMMARY.md              # Table of contents
│   ├── 00-bootcamp/            # Phase 0: Zig Bootcamp ✅
│   ├── 01-foundation/          # Phase 1: Foundation & Philosophy ✅
│   ├── 02-core/                # Phase 2: Core Recipes ✅
│   ├── 03-advanced/            # Phase 3: Advanced Topics ✅
│   ├── 04-specialized/         # Phase 4: Specialized Topics 🔄
│   └── 05-zig-paradigms/       # Phase 5: Zig Paradigms ⏳
├── code/                        # Compilable .zig files (mirroring src/)
│   ├── 00-bootcamp/            # Bootcamp code examples
│   ├── 01-foundation/          # Foundation code examples
│   ├── 02-core/                # Core recipes code
│   ├── 03-advanced/            # Advanced topics code
│   └── 04-specialized/         # Specialized topics code
├── theme/                       # Custom mdBook theme
├── assets/                      # Images and static assets
└── book/                        # Built documentation (generated)
```

## Recipe Format

Each recipe follows a consistent Problem/Solution/Discussion structure:

```markdown
# Recipe Title

## Problem
What problem this recipe solves.

## Solution
Zig code demonstrating the solution using `{{#include}}` directives.

\`\`\`zig
{{#include ../code/phase/chapter/recipe_x_y.zig:anchor_name}}
\`\`\`

## Discussion
How it works, Zig-specific considerations, and best practices.

## See Also
Links to related recipes.
```

All code examples are pulled directly from tested `.zig` files in the `code/` directory using mdBook's anchor system.

## Contributing

Contributions are welcome! When adding recipes:

1. **Write code first** - Create compilable `.zig` file in `code/` directory
2. **Add anchors** - Mark code sections with `// ANCHOR: name` comments
3. **Write tests** - Use `std.testing` and `testing.allocator` to catch memory leaks
4. **Test thoroughly** - Run `zig test` to ensure code compiles and passes
5. **Write markdown** - Create `.md` file in `src/` using `{{#include}}` directives
6. **Verify build** - Run `mdbook build` to ensure documentation renders correctly

## Book Structure

The cookbook is organized into 5 progressive phases:

### Phase 0: Zig Bootcamp (14 recipes)
Introduction to Zig fundamentals for absolute beginners.

### Phase 1: Foundation & Philosophy (5 recipes)
Idiomatic patterns, error handling, testing, and safety.

### Phase 2: Core Recipes (81 recipes)
Practical solutions for everyday programming tasks:
- Data structures and algorithms
- Strings and text processing
- Numbers, dates, and iterators
- Files and I/O operations

### Phase 3: Advanced Topics (60 recipes)
Deep dives into complex Zig features:
- Data encoding (CSV, JSON, XML)
- Functions and callbacks
- Structs, unions, and object patterns
- Metaprogramming with comptime
- Modules and build system

### Phase 4: Specialized Topics (40 recipes)
Domain-specific programming:
- Network and web programming
- Concurrency and parallelism
- System administration
- Testing and debugging
- C interoperability

### Phase 5: Zig Paradigms (30 recipes)
Advanced Zig-specific patterns:
- Build system mastery
- Advanced comptime metaprogramming
- Explicit memory management patterns
- WebAssembly and freestanding targets
- High-performance networking

## Writing Style

The cookbook aims for:
- Clear, beginner-friendly explanations without condescension
- Concise, practical examples that solve real problems
- Real, compilable code with comprehensive tests
- Fun and engaging tone, not academic or overly formal
- Comparisons to other languages (especially Python) where helpful

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

Built with:
- [mdBook](https://rust-lang.github.io/mdBook/) - Documentation generator
- [Zig](https://ziglang.org/) - The Zig programming language

Inspired by:
- [Zig Cookbook](https://github.com/zigcc/zig-cookbook) - Another excellent Zig cookbook worth checking out!

---

<p align="center">
  <strong>Happy Zigging! 🔥</strong>
</p>
