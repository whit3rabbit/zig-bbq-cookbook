# Recipe 18.3: Memory-Mapped I/O for Large Files

## Problem

You need to efficiently access large files, perform zero-copy operations, or share memory between processes. You want to treat file contents as memory without explicit read/write calls, and you need better performance for random access patterns.

## Solution

Zig's `std.posix.mmap` function maps files directly into your process's address space, allowing you to access file contents as if they were in-memory arrays.

### Basic Memory-Mapped File

Map a file into memory and access it directly:

```zig
{{#include ../../../code/05-zig-paradigms/18-memory-management/recipe_18_3.zig:basic_mmap}}
```

### Writing to Memory-Mapped Files

Create writable mappings to modify file contents:

```zig
{{#include ../../../code/05-zig-paradigms/18-memory-management/recipe_18_3.zig:write_mmap}}
```

### Efficient File Searching

Search large files without loading them entirely into memory:

```zig
{{#include ../../../code/05-zig-paradigms/18-memory-management/recipe_18_3.zig:large_file_search}}
```

### Binary File Processing

Process structured binary data directly from mapped memory:

```zig
{{#include ../../../code/05-zig-paradigms/18-memory-management/recipe_18_3.zig:binary_file_processing}}
```

### Safe Wrapper Pattern

Create a RAII wrapper for safer memory-mapped file usage:

```zig
{{#include ../../../code/05-zig-paradigms/18-memory-management/recipe_18_3.zig:safe_mmap_wrapper}}
```

### Performance Comparison

Compare memory-mapped I/O with traditional read operations:

```zig
{{#include ../../../code/05-zig-paradigms/18-memory-management/recipe_18_3.zig:performance_comparison}}
```

## Discussion

Memory-mapped I/O provides direct access to file contents through virtual memory, eliminating explicit read/write calls and enabling zero-copy operations for improved performance.

### How Memory Mapping Works

Memory mapping creates a mapping between a file and your process's virtual address space:

1. **mmap** system call creates the mapping
2. Operating system manages page faults and data transfer
3. File contents appear as normal memory
4. Reads and writes happen through memory access
5. **munmap** removes the mapping

The OS handles all I/O automatically using demand paging - only accessed portions are actually loaded into physical memory.

### Protection Modes

The `PROT` flags control access permissions:

**`PROT.READ`**: Read-only access - attempts to write cause segmentation faults
**`PROT.WRITE`**: Write access - changes are visible in the file
**`PROT.EXEC`**: Execute permission - for loading code pages
**`PROT.READ | PROT.WRITE`**: Read-write access for both operations

Always use the minimum necessary permissions for security and correctness.

### Mapping Types

The `MAP` flags control sharing behavior:

**`MAP.SHARED`**: Changes are visible to other processes and written to the file
**`MAP.PRIVATE`**: Copy-on-write - changes are private and not written back

Use `SHARED` for inter-process communication and file updates, `PRIVATE` for read-only snapshots with local modifications.

### When to Use Memory Mapping

**Ideal For:**
- Large files (> 100 MB) with random access patterns
- Files accessed multiple times
- Zero-copy operations on file data
- Shared memory between processes
- Memory-efficient processing of huge datasets
- Binary file formats with structured data

**Avoid When:**
- Files are small (< 1 MB) - traditional I/O is simpler
- Sequential access only - buffered I/O may be faster
- Files larger than available address space (32-bit systems)
- Frequent modifications to small portions
- Platform portability is critical (Windows differs)

### Performance Characteristics

**Sequential Access**: Similar to buffered I/O, slight overhead from page faults

**Random Access**: Much faster than seek+read, especially for sparse access patterns

**Repeated Access**: Second access is instant (already in page cache)

**Memory Pressure**: OS can evict pages, causing slowdown if memory is scarce

**Large Files**: Scale to files larger than physical RAM (virtual memory)

For the 1 MB test file in the example, mmap shows minimal advantage because the entire file fits easily in cache and is accessed sequentially. For multi-GB files with random access, mmap typically shows 2-10x speedups.

### Address Space Alignment

Memory mappings must be page-aligned:

```zig
[]align(std.heap.page_size_min) u8
```

The alignment ensures proper interaction with the virtual memory system. Attempting to use incorrect alignment causes runtime errors.

### Error Handling

Common mmap errors:

**`error.AccessDenied`**: Insufficient file permissions for requested protection
**`error.OutOfMemory`**: Address space exhausted (common on 32-bit)
**`error.InvalidArgument`**: Invalid flags or alignment
**`error.PermissionDenied`**: File doesn't support mapping (e.g., pipes)

Always check file permissions before attempting to create a writable mapping.

### Binary Data Access

For structured binary data, use `std.mem.bytesAsSlice`:

```zig
const records = std.mem.bytesAsSlice(Record, @alignCast(mapped));
```

This provides zero-copy access to structures directly from the mapped file. Ensure proper alignment with `@alignCast` when necessary.

### Modifying Mapped Files

When writing to a mapped file:

1. **Ensure write permissions**: Open file with `.mode = .read_write`
2. **Set file size first**: Use `setEndPos()` to allocate space
3. **Use `PROT.WRITE`**: Include write protection in mmap flags
4. **Sync if needed**: Changes may not be immediately visible on disk

The OS writes changes back asynchronously. For guaranteed persistence, use `msync` (platform-specific) or close the file.

### File Size Considerations

**Growing Files**: Can't grow a mapped file - the mapping size is fixed at creation time. To add data, unmap, resize, and remap.

**Shrinking Files**: Truncating a mapped file causes undefined behavior for pages beyond the new size. Unmap before truncating.

**Empty Files**: Cannot map empty files (size 0). Check file size first.

### Platform Differences

Memory mapping is POSIX on Unix/Linux/macOS but uses different APIs on Windows:

- Unix: `mmap`, `munmap`, `msync`, `mprotect`
- Windows: `CreateFileMapping`, `MapViewOfFile`, `UnmapViewOfFile`

Zig's `std.posix.mmap` abstracts these differences, but behavior may vary slightly. Test on target platforms.

### Common Pitfalls

**Accessing After Unmap**: Unmapped memory access causes segmentation faults. Always use `defer munmap` or RAII wrappers.

**Race Conditions**: Multiple processes can map the same file. Use file locking or synchronization primitives.

**Partial Writes**: The OS may write dirty pages at any time. Don't rely on write ordering without explicit synchronization.

**Address Space Exhaustion**: On 32-bit systems, address space is limited (~4 GB). Use smaller mappings or 64-bit builds.

**Page Cache Contention**: Very large mappings can evict other pages, degrading system performance.

### Best Practices

**RAII Wrappers**: Encapsulate mmap/munmap in structs with init/deinit for automatic cleanup.

**Check File Size**: Validate file size before mapping to avoid empty or invalid mappings.

**Appropriate Permissions**: Use read-only mappings unless modification is necessary.

**Unmap When Done**: Don't keep mappings open longer than needed - they consume address space.

**Handle Page Faults**: First access to each page causes a page fault. Pre-fault critical sections if latency matters.

**Align Offsets**: When mapping portions of a file, ensure offsets are page-aligned.

### Zero-Copy Operations

Memory mapping enables true zero-copy:

```zig
// Read file and hash without copying
const mapped = try mmap(...);
defer munmap(mapped);

var hasher = std.crypto.hash.Sha256.init(.{});
hasher.update(mapped);
const hash = hasher.finalResult();
```

No intermediate buffer needed - the hash function operates directly on mapped memory.

### Inter-Process Communication

Shared memory via mmap:

1. One process creates a file
2. Multiple processes map the same file with `MAP.SHARED`
3. Changes by any process are visible to all
4. Use semaphores or mutexes for synchronization

This provides faster IPC than pipes or sockets for large data transfers.

### Large File Strategies

For files larger than address space:

**Windowing**: Map portions of the file, process, unmap, and map the next portion.

**Multiple Mappings**: Create separate mappings for different file regions as needed.

**64-bit Build**: Use 64-bit builds for virtually unlimited address space.

### Security Considerations

**Sensitive Data**: Mapped memory may be swapped to disk. Use `mlock` for sensitive data or avoid mapping.

**Input Validation**: Validate file contents before treating as structures - malicious files can cause crashes or exploits.

**Write Protection**: Use read-only mappings when possible to prevent accidental corruption.

**Access Control**: Check file permissions - mapping bypasses normal I/O permission checks.

### Debugging Mapped Files

**Segmentation Faults**: Usually caused by:
- Accessing after `munmap`
- Writing to read-only mappings
- Alignment errors
- Out-of-bounds access

**Performance Issues**:
- Monitor page faults with OS tools
- Check if mappings fit in physical RAM
- Profile to see if buffered I/O would be better

### Advanced Patterns

**Lazy Loading**: Map huge files but only access needed portions - OS loads pages on demand.

**Append-Only Logs**: Map file, write to end, remap when full.

**Read-Modify-Write**: Map file, modify in place, unmap (faster than read+write for large files).

**Database-Style Access**: Map file containing B-tree or hash table, access structures directly.

### Comparison to Other Approaches

**Buffered I/O (read/write)**:
- Pro: Simple, portable, works for all file types
- Con: Requires copying data, slower for random access

**Memory Mapping**:
- Pro: Zero-copy, fast random access, automatic caching
- Con: Platform-specific, requires virtual memory, fixed size

**Direct I/O (O_DIRECT)**:
- Pro: Bypasses OS cache for deterministic performance
- Con: Must manage alignment, buffers; only for specific use cases

**Streaming I/O**:
- Pro: Handles arbitrarily large files, minimal memory
- Con: Only sequential access, requires buffer management

## See Also

- Recipe 18.1: Custom Allocator Implementation
- Recipe 5.10: Memory-Mapped Files (file I/O basics)
- Recipe 5.8: Fixed-Sized Records (structured binary I/O)

Full compilable example: `code/05-zig-paradigms/18-memory-management/recipe_18_3.zig`
