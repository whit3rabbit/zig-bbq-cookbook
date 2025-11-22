# Chapter 14: Testing, Debugging, and Exceptions

Master testing, debugging, and error handling in Zig.

## Topics

- Testing stdout output (capturing in tests)
- Patching objects in unit tests (dependency injection)
- Testing exceptional conditions (`std.testing.expectError`)
- Logging test output to files
- Skipping or anticipating test failures
- Handling multiple exceptions (error sets and `switch`)
- Catching all exceptions (`catch` with generic handling)
- Creating custom exceptions (custom error sets)
- Raising exceptions in response to others
- Reraising exceptions (`errdefer` or returning errors)
- Issuing warning messages (`std.log.warn`)
- Debugging crashes (stack traces, `gdb`/`lldb`)
- Profiling and timing programs
- Making programs faster (release modes: `-O ReleaseFast`, `-O ReleaseSafe`)

See TODO.md for complete recipe list (14 recipes planned).
