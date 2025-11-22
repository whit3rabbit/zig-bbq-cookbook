# Chapter 12: Concurrency

Master concurrent programming in Zig.

## Topics

- Starting and stopping threads (`std.Thread.spawn`)
- Thread state determination
- Inter-thread communication (thread-safe queues with Mutex)
- Locking critical sections (`std.Thread.Mutex`)
- Deadlock avoidance
- Thread-specific state (thread-local variables)
- Thread pools (`std.Thread.Pool`)
- Simple parallel programming
- GIL considerations (not applicable to Zig - explained why!)
- Actor task definition
- Publish/subscribe messaging
- Generators as thread alternatives (Zig `async`/`await` if applicable)

See TODO.md for complete recipe list (12 recipes planned).
