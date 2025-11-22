# Chapter 15: C Interoperability

Learn to seamlessly integrate Zig with C code.

## Topics

- Accessing C code with `@cImport`
- Writing C extension modules (exporting Zig functions with `export`)
- Array operations across boundaries (C pointers to multi-item pointers `[*]T`)
- Managing opaque pointers in extensions
- Wrapping existing C libraries with Zig
- Calling Zig from C
- Managing memory between C and Zig
- Passing NULL-terminated strings (`std.cstr`, sentinels `[*:0]u8`)
- Passing Unicode strings to C
- Wrapping C variadic functions

See TODO.md for complete recipe list (10 recipes planned).
