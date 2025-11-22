# Recipe 20.4: Implementing a Basic HTTP/1.1 Parser from Scratch

## Problem

You need to parse HTTP requests and build HTTP responses without relying on external libraries. Understanding the HTTP protocol at a low level is crucial for building custom servers, proxies, or debugging network issues.

## Solution

Build a state machine-based parser that processes HTTP requests line by line, extracting methods, paths, headers, and body content.

### HTTP Method Enum

```zig
{{#include ../../../code/05-zig-paradigms/20-high-perf-networking/recipe_20_4.zig:http_method}}
```

### HTTP Request Structure

```zig
{{#include ../../../code/05-zig-paradigms/20-high-perf-networking/recipe_20_4.zig:http_request}}
```

### Request Parser

```zig
{{#include ../../../code/05-zig-paradigms/20-high-perf-networking/recipe_20_4.zig:request_parser}}
```

### Response Builder

```zig
{{#include ../../../code/05-zig-paradigms/20-high-perf-networking/recipe_20_4.zig:response_builder}}
```

### Chunked Transfer Encoding

```zig
{{#include ../../../code/05-zig-paradigms/20-high-perf-networking/recipe_20_4.zig:chunked_parser}}
```

## Discussion

HTTP/1.1 is a text-based protocol designed to be human-readable. Parsing it requires careful state management and string processing.

### HTTP Request Format

```
METHOD PATH VERSION\r\n
Header1: Value1\r\n
Header2: Value2\r\n
\r\n
Body (optional)
```

Example:
```
GET /api/users HTTP/1.1\r\n
Host: example.com\r\n
Accept: application/json\r\n
\r\n
```

### Parsing Strategy

The parser uses a simple state machine:
1. **Request Line**: Parse method, path, and HTTP version
2. **Headers**: Parse key-value pairs until blank line
3. **Body**: Everything after blank line

This approach handles streaming data well - you can parse incrementally as data arrives.

### Header Storage

Headers are stored in a StringHashMap for O(1) lookup. Common headers:
- Host: Target host (required in HTTP/1.1)
- Content-Length: Body size in bytes
- Content-Type: MIME type of body
- Accept: Client's acceptable response types
- User-Agent: Client identifier

### Response Building

Build responses by:
1. Setting status code and text (200 OK, 404 Not Found, etc.)
2. Adding headers
3. Setting body
4. Calling build() to serialize

The builder automatically adds Content-Length when you set a body.

### Chunked Transfer Encoding

HTTP/1.1 supports chunked encoding for streaming responses of unknown length:

```
5\r\n
Hello\r\n
7\r\n
, World\r\n
0\r\n
\r\n
```

Each chunk starts with its size in hexadecimal, followed by `\r\n`, the data, and another `\r\n`. A zero-size chunk marks the end.

### Performance Considerations

**Memory allocation:**
- Parser uses allocator for headers hashmap
- Response builder pre-calculates total size for single allocation
- Avoid unnecessary copying

**Streaming:**
- Can parse partial requests as data arrives
- Useful for non-blocking servers
- Track parser state between recv() calls

### Common HTTP Status Codes

- **200 OK**: Success
- **201 Created**: Resource created
- **204 No Content**: Success with no body
- **301 Moved Permanently**: Redirect
- **400 Bad Request**: Client error
- **401 Unauthorized**: Authentication required
- **404 Not Found**: Resource doesn't exist
- **500 Internal Server Error**: Server error
- **503 Service Unavailable**: Server overloaded

### Security Considerations

**Always validate:**
- Method is a valid HTTP method
- Path doesn't contain `..` (directory traversal)
- Header names are valid (no colons or newlines)
- Content-Length matches actual body size
- Total request size is reasonable (prevent DoS)

**Limit sizes:**
```zig
if (path.len > 2048) return error.PathTooLong;
if (headers.count() > 100) return error.TooManyHeaders;
if (body.len > 1_000_000) return error.BodyTooLarge;
```

### HTTP/1.1 vs HTTP/2

HTTP/1.1:
- Text-based, human-readable
- Simple to parse and debug
- One request per connection (or pipelined)
- Headers uncompressed

HTTP/2:
- Binary protocol
- Multiplexed streams
- Header compression (HPACK)
- Server push

For most applications, HTTP/1.1 is sufficient and simpler to implement.

## See Also

- Recipe 11.4: Building a Simple HTTP Server - Complete server implementation
- Recipe 20.1: Non-Blocking TCP Servers - Event loop for HTTP server
- Recipe 6.2: Reading and Writing JSON Data - Parsing request bodies
- Recipe 11.6: Working with REST APIs - HTTP client usage

Full compilable example: `code/05-zig-paradigms/20-high-perf-networking/recipe_20_4.zig`
