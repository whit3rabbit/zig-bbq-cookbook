# Phase 0: Zig Bootcamp

Welcome to Zig! This phase is your starting point if you're new to Zig but have programmed in other languages before (Python, JavaScript, Go, C++, etc.).

Zig makes different choices than most languages you've used. It has no hidden memory allocations, no exceptions, and no garbage collector. This might feel strange at first, but it gives you complete control and predictable performance.

## What You'll Learn

By the end of this bootcamp, you'll understand:

- **Why Zig is different** - No magic, no hidden costs, explicit everything
- **Basic syntax** - Variables, types, functions, control flow
- **Critical concepts** - Arrays vs slices vs ArrayLists (the #1 confusion point!)
- **Pointers** - When and why to use them (unlike Java/Python where everything is a "reference")
- **Memory management** - Understanding allocators (uniquely Zig)
- **Error handling** - No exceptions, just values (using `!T` and `?T`)
- **Project structure** - Building and testing real programs

## The Four Critical Recipes

These recipes address the biggest hurdles for Zig newcomers:

1. **Recipe 0.1: Philosophy** - Why Zig makes the choices it does
2. **Recipe 0.6: Arrays/Slices/ArrayLists** - The #1 source of beginner confusion
3. **Recipe 0.9: Pointers** - Understanding `*T` vs `[*]T` vs `[]T`
4. **Recipe 0.12: Allocators** - Memory management without a garbage collector

## How to Use This Phase

Start at Recipe 0.1 and work through sequentially. Each recipe builds on previous ones. Don't skip ahead, especially not past the critical recipes.

Every recipe includes:
- Working code you can compile and run
- Comparisons to other languages you might know
- Common mistakes and how to avoid them
- Tests that prove the code works

## Prerequisites

You should know:
- Basic programming concepts (variables, loops, functions)
- How to use a terminal/command line
- Any programming language (we'll compare to what you know)

You don't need to know:
- C or systems programming
- Manual memory management
- Anything about compilers or build systems

Let's get started!

## Recipes in This Phase

1. Understanding Zig's Philosophy
2. Installing Zig and Verifying Your Toolchain
3. Your First Zig Program
4. Variables, Constants, and Type Inference
5. Primitive Data and Basic Arrays
6. Arrays, ArrayLists, and Slices (CRITICAL)
7. Functions and the Standard Library
8. Control Flow and Iteration
9. Understanding Pointers and References (CRITICAL)
10. Structs, Enums, and Simple Data Models
11. Optionals, Errors, and Resource Cleanup
12. Understanding Allocators (CRITICAL)
13. Testing and Debugging Fundamentals
14. Projects, Modules, and Dependencies
