# Summary

[Introduction](README.md)

---

# Phase 0: Zig Bootcamp

- [Overview](00-bootcamp/index.md)
- [0.1: Understanding Zig's Philosophy](00-bootcamp/01-understanding-philosophy.md)
- [0.2: Installing Zig and Verifying Your Toolchain](00-bootcamp/02-installing-zig.md)
- [0.3: Your First Zig Program](00-bootcamp/03-hello-world.md)
- [0.4: Variables, Constants, and Type Inference](00-bootcamp/04-variables-constants.md)
- [0.5: Primitive Data and Basic Arrays](00-bootcamp/05-primitives-arrays.md)
- [0.6: Arrays, ArrayLists, and Slices](00-bootcamp/06-arrays-slices-lists.md)
- [0.7: Functions and the Standard Library](00-bootcamp/07-functions-stdlib.md)
- [0.8: Control Flow and Iteration](00-bootcamp/08-control-flow.md)
- [0.9: Understanding Pointers and References](00-bootcamp/09-pointers.md)
- [0.10: Structs, Enums, and Simple Data Models](00-bootcamp/10-structs-enums.md)
- [0.11: Optionals, Errors, and Resource Cleanup](00-bootcamp/11-optionals-errors-cleanup.md)
- [0.12: Understanding Allocators](00-bootcamp/12-allocators.md)
- [0.13: Testing and Debugging Fundamentals](00-bootcamp/13-testing-debugging.md)
- [0.14: Projects, Modules, and Dependencies](00-bootcamp/14-projects-modules-dependencies.md)

---

# Phase 1: Foundation & Philosophy

- [Overview](01-foundation/index.md)
- [1.1: Writing Idiomatic Zig Code](01-foundation/01-idiomatic-zig.md)
- [1.2: Error Handling Patterns](01-foundation/02-error-handling-patterns.md)
- [1.3: Testing Strategy](01-foundation/03-testing-strategy.md)
- [1.4: When to Pass by Pointer vs Value](01-foundation/04-pointer-vs-value.md)
- [1.5: Build Modes and Safety](01-foundation/05-build-modes-safety.md)

---

# Phase 2: Core Recipes

## Chapter 1: Data Structures

- [Overview](02-core/01-data-structures/index.md)
- [1.1: Unpacking Sequences into Separate Variables](02-core/01-data-structures/01-unpacking-destructuring.md)
- [1.2: Deque Operations with Slices](02-core/01-data-structures/02-slices.md)
- [1.3: Ring Buffers for Fixed-Size Sequences](02-core/01-data-structures/03-ring-buffers.md)
- [1.4: Finding the Largest or Smallest N Items](02-core/01-data-structures/04-largest-smallest-n.md)
- [1.5: Implementing a Priority Queue](02-core/01-data-structures/05-priority-queue.md)
- [1.6: Mapping Keys to Multiple Values in a Dictionary](02-core/01-data-structures/06-multimap.md)
- [1.7: Keeping Dictionaries in Order](02-core/01-data-structures/07-ordered-hashmap.md)
- [1.8: Calculating with Dictionaries](02-core/01-data-structures/08-hashmap-calculations.md)
- [1.9: Finding Commonalities and Differences in Sets](02-core/01-data-structures/09-set-operations.md)
- [1.10: Removing Duplicates from a Sequence](02-core/01-data-structures/10-remove-duplicates.md)
- [1.11: Naming a Slice](02-core/01-data-structures/11-naming-slices.md)
- [1.12: Determining the Most Frequently Occurring Items](02-core/01-data-structures/12-frequency-counting.md)
- [1.13: Sorting a List of Structs by a Common Field](02-core/01-data-structures/13-sorting-structs.md)
- [1.14: Sorting Objects Without Native Comparison Support](02-core/01-data-structures/14-sorting-without-comparison.md)
- [1.15: Grouping Records Together Based on a Field](02-core/01-data-structures/15-grouping-records.md)
- [1.16: Filtering Sequence Elements](02-core/01-data-structures/16-filtering-sequences.md)
- [1.17: Extracting a Subset of a Dictionary](02-core/01-data-structures/17-extracting-dictionary-subset.md)
- [1.18: Mapping Names to Sequence Elements](02-core/01-data-structures/18-mapping-names-to-elements.md)
- [1.19: Transforming and Reducing Data at the Same Time](02-core/01-data-structures/19-transforming-reducing-simultaneously.md)
- [1.20: Combining Multiple Mappings into a Single Mapping](02-core/01-data-structures/20-combining-mappings.md)

## Chapter 2: Strings and Text

- [Overview](02-core/02-strings-and-text/index.md)
- [2.1: Splitting Strings on Any of Multiple Delimiters](02-core/02-strings-and-text/01-splitting-strings.md)
- [2.2: Matching Text at the Start or End of a String](02-core/02-strings-and-text/02-matching-start-end.md)
- [2.3: Matching Strings Using Wildcard Patterns](02-core/02-strings-and-text/03-wildcard-patterns.md)
- [2.4: Searching and Matching Text Patterns](02-core/02-strings-and-text/04-text-pattern-searching.md)
- [2.5: Searching and Replacing Text](02-core/02-strings-and-text/05-searching-and-replacing-text.md)
- [2.6: Searching and Replacing Case-Insensitive Text](02-core/02-strings-and-text/06-case-insensitive-searching.md)
- [2.7: Stripping Unwanted Characters from Strings](02-core/02-strings-and-text/07-stripping-unwanted-characters.md)
- [2.8: Combining and Concatenating Strings](02-core/02-strings-and-text/08-combining-concatenating-strings.md)
- [2.9: Interpolating Variables in Strings](02-core/02-strings-and-text/09-interpolating-variables.md)
- [2.10: Aligning Text Strings](02-core/02-strings-and-text/10-aligning-text-strings.md)
- [2.11: Reformatting Text to a Fixed Number of Columns](02-core/02-strings-and-text/11-reformatting-text-columns.md)
- [2.12: Working with Byte Strings vs Unicode Text](02-core/02-strings-and-text/12-byte-strings-vs-unicode.md)
- [2.13: Sanitizing and Cleaning Up Text](02-core/02-strings-and-text/13-sanitizing-cleaning-text.md)
- [2.14: Standardizing Unicode Text to a Normal Form](02-core/02-strings-and-text/14-standardizing-unicode-text.md)

## Chapter 3: Numbers, Dates, and Times

- [Overview](02-core/03-numbers-dates-times/index.md)

## Chapter 4: Iterators and Generators

- [Overview](02-core/04-iterators-generators/index.md)
- [4.6: Defining Generator Functions with State](02-core/04-iterators-generators/06-stateful-iterators.md)
- [4.7: Taking a Slice of an Iterator](02-core/04-iterators-generators/07-slicing-iterators.md)
- [4.8: Skipping the First Part of an Iterable](02-core/04-iterators-generators/08-skipping-iterators.md)
- [4.9: Iterating Over All Possible Combinations or Permutations](02-core/04-iterators-generators/09-combinations-permutations.md)
- [4.10: Iterating Over the Index-Value Pairs of a Sequence](02-core/04-iterators-generators/10-enumerate-iteration.md)
- [4.11: Iterating Over Multiple Sequences Simultaneously](02-core/04-iterators-generators/11-zip-iterators.md)
- [4.12: Iterating on Items in Separate Containers](02-core/04-iterators-generators/12-chain-iterators.md)
- [4.13: Creating Data Processing Pipelines](02-core/04-iterators-generators/13-data-pipelines.md)

## Chapter 5: Files and I/O

- [Overview](02-core/05-files-io/index.md)
- [5.1: Reading and Writing Text Data](02-core/05-files-io/01-reading-writing-text.md)
- [5.2: Printing to a File](02-core/05-files-io/02-printing-to-file.md)
- [5.3: Printing with a Different Separator or Line Ending](02-core/05-files-io/03-print-custom-separator.md)
- [5.4: Reading and Writing Binary Data](02-core/05-files-io/04-binary-data.md)
- [5.5: Writing to a File That Doesn't Already Exist](02-core/05-files-io/05-exclusive-file-creation.md)
- [5.6: Performing I/O Operations on a String](02-core/05-files-io/06-string-io-operations.md)
- [5.7: Reading and Writing Compressed Datafiles](02-core/05-files-io/07-compressed-data.md)
- [5.8: Iterating Over Fixed-Sized Records](02-core/05-files-io/08-fixed-sized-records.md)
- [5.9: Reading Binary Data into a Mutable Buffer](02-core/05-files-io/09-mutable-buffer-reads.md)
- [5.10: Memory Mapping Binary Files](02-core/05-files-io/10-memory-mapped-files.md)
- [5.11: Manipulating Pathnames](02-core/05-files-io/11-pathname-manipulation.md)
- [5.12: Testing for the Existence of a File](02-core/05-files-io/12-file-existence.md)
- [5.13: Getting a Directory Listing](02-core/05-files-io/13-directory-listing.md)
- [5.14: Bypassing Filename Encoding](02-core/05-files-io/14-bypassing-encoding.md)
- [5.15: Printing Bad Filenames](02-core/05-files-io/15-printing-bad-filenames.md)
- [5.16: Adding or Changing the Encoding of an Already Open File](02-core/05-files-io/16-wrapping-file-descriptor.md)
- [5.17: Writing Bytes to a Text File](02-core/05-files-io/17-temporary-files.md)
- [5.18: Communicating with Serial Ports](02-core/05-files-io/18-communicating-serial.md)
- [5.19: Serializing Zig Objects](02-core/05-files-io/19-serializing-objects.md)

---

# Phase 3: Advanced Topics

## Chapter 6: Data Encoding and Processing

- [Overview](03-advanced/06-data-encoding/index.md)
- [6.1: Reading and Writing CSV Data](03-advanced/06-data-encoding/01-csv-data.md)
- [6.2: Reading and Writing JSON Data](03-advanced/06-data-encoding/02-json-data.md)
- [6.3: Parsing Simple XML Data](03-advanced/06-data-encoding/03-xml-data.md)
- [6.4: Parsing and Modifying XML](03-advanced/06-data-encoding/04-incremental-xml.md)
- [6.5: Turning a Dictionary into XML](03-advanced/06-data-encoding/05-dictionary-to-xml.md)
- [6.6: Interacting with a Relational Database](03-advanced/06-data-encoding/06-interacting-with-databases.md)
- [6.7: Decoding and Encoding Hexadecimal Digits](03-advanced/06-data-encoding/07-hexadecimal.md)
- [6.8: Decoding and Encoding Base64](03-advanced/06-data-encoding/08-base64.md)
- [6.9: Reading and Writing Binary Arrays of Structures](03-advanced/06-data-encoding/09-binary-structures.md)

## Chapter 7: Functions

- [Overview](03-advanced/07-functions/index.md)
- [7.1: Writing Functions That Accept Any Number of Arguments](03-advanced/07-functions/01-variadic-arguments.md)
- [7.2: Writing Functions That Only Accept Keyword Arguments](03-advanced/07-functions/02-keyword-arguments.md)
- [7.3: Attaching Informational Metadata to Function Arguments](03-advanced/07-functions/03-function-metadata.md)
- [7.4: Returning Multiple Values from a Function](03-advanced/07-functions/04-multiple-return-values.md)
- [7.5: Defining Functions with Default Arguments](03-advanced/07-functions/05-default-arguments.md)
- [7.6: Defining Anonymous or Inline Functions](03-advanced/07-functions/06-anonymous-functions.md)
- [7.7: Capturing Variables in Anonymous Functions](03-advanced/07-functions/07-closures.md)
- [7.8: Making an N-Argument Callable Work As a Callable with Fewer Arguments](03-advanced/07-functions/08-partial-application.md)
- [7.9: Replacing Single Method Classes with Functions](03-advanced/07-functions/09-single-method-classes.md)
- [7.10: Carrying Extra State with Callback Functions](03-advanced/07-functions/10-callback-state.md)
- [7.11: Inlining Callback Functions](03-advanced/07-functions/11-inline-callbacks.md)

## Chapter 8: Structs, Unions, and Objects

- [Overview](03-advanced/08-structs-unions-objects/index.md)
- [8.1: Changing the String Representation of Instances](03-advanced/08-structs-unions-objects/01-string-representation.md)
- [8.2: Customizing String Formatting](03-advanced/08-structs-unions-objects/02-customizing-formatting.md)
- [8.3: Making Objects Support the Context Management Protocol](03-advanced/08-structs-unions-objects/03-context-management-protocol.md)
- [8.4: Saving Memory When Creating a Large Number of Instances](03-advanced/08-structs-unions-objects/04-packed-struct-optimization.md)
- [8.5: Encapsulating Names in a Struct](03-advanced/08-structs-unions-objects/05-encapsulation.md)
- [8.6: Creating Managed Attributes](03-advanced/08-structs-unions-objects/06-managed-attributes.md)
- [8.7: Calling a Method on a Parent Struct](03-advanced/08-structs-unions-objects/07-parent-methods.md)
- [8.8: Extending a Property in a Subclass](03-advanced/08-structs-unions-objects/08-extending-properties.md)
- [8.9: Creating a New Kind of Struct or Instance Attribute](03-advanced/08-structs-unions-objects/09-custom-attributes.md)
- [8.10: Using Lazily Computed Properties](03-advanced/08-structs-unions-objects/10-lazy-properties.md)
- [8.11: Simplifying the Initialization of Data Structures](03-advanced/08-structs-unions-objects/11-simplified-initialization.md)
- [8.12: Defining an Interface or Abstract Base Struct](03-advanced/08-structs-unions-objects/12-interface-patterns.md)
- [8.13: Implementing a Data Model or Type System](03-advanced/08-structs-unions-objects/13-data-model-type-system.md)
- [8.14: Implementing Custom Containers](03-advanced/08-structs-unions-objects/14-custom-containers.md)
- [8.15: Delegating Attribute Access](03-advanced/08-structs-unions-objects/15-attribute-delegation.md)
- [8.16: Defining More Than One Constructor in a Struct](03-advanced/08-structs-unions-objects/16-multiple-constructors.md)
- [8.17: Creating an Instance Without Invoking init](03-advanced/08-structs-unions-objects/17-instance-without-init.md)
- [8.18: Extending Structs with Mixins](03-advanced/08-structs-unions-objects/18-extending-with-mixins.md)
- [8.19: Implementing Stateful Objects or State Machines](03-advanced/08-structs-unions-objects/19-state-machines.md)
- [8.20: Implementing the Visitor Pattern](03-advanced/08-structs-unions-objects/20-visitor-pattern.md)
- [8.21: Managing Memory in Cyclic Data Structures](03-advanced/08-structs-unions-objects/21-cyclic-memory.md)
- [8.22: Making Structs Support Comparison Operations](03-advanced/08-structs-unions-objects/22-comparison-operations.md)

## Chapter 9: Metaprogramming

- [Overview](03-advanced/09-metaprogramming/index.md)
- [9.1: Putting a Wrapper Around a Function](03-advanced/09-metaprogramming/01-function-wrapper.md)
- [9.2: Preserving Function Metadata When Writing Decorators](03-advanced/09-metaprogramming/02-preserving-metadata.md)
- [9.3: Unwrapping a Decorator](03-advanced/09-metaprogramming/03-unwrapping-decorator.md)
- [9.4: Defining a Decorator That Takes Arguments](03-advanced/09-metaprogramming/04-decorator-arguments.md)
- [9.5: Enforcing Type Checking on a Function Using a Decorator](03-advanced/09-metaprogramming/05-type-checking-decorator.md)
- [9.6: Defining Decorators As Part of a Struct](03-advanced/09-metaprogramming/06-struct-decorators.md)
- [9.7: Defining Decorators As Structs](03-advanced/09-metaprogramming/07-decorators-as-structs.md)
- [9.8: Applying Decorators to Struct and Static Methods](03-advanced/09-metaprogramming/08-method-decorators.md)
- [9.9: Writing Decorators That Add Arguments to Wrapped Functions](03-advanced/09-metaprogramming/09-adding-arguments.md)
- [9.10: Using Decorators to Patch Struct Definitions](03-advanced/09-metaprogramming/10-patching-structs.md)
- [9.11: Using a Metaclass to Control Instance Creation](03-advanced/09-metaprogramming/11-comptime-instance-creation.md)
- [9.12: Capturing Struct Attribute Definition Order](03-advanced/09-metaprogramming/12-field-order.md)
- [9.13: Defining a Metaclass That Takes Optional Arguments](03-advanced/09-metaprogramming/13-optional-arguments.md)
- [9.14: Enforcing an Argument Signature on Tuple Arguments](03-advanced/09-metaprogramming/14-argument-signatures.md)
- [9.15: Enforcing Coding Conventions in Structs](03-advanced/09-metaprogramming/15-coding-conventions.md)
- [9.16: Defining Structs Programmatically](03-advanced/09-metaprogramming/16-programmatic-structs.md)
- [9.17: Initializing Struct Members at Definition Time](03-advanced/09-metaprogramming/17-struct-initialization.md)

## Chapter 10: Modules and Build System

- [Overview](03-advanced/10-modules-build-system/index.md)
- [10.1: Making a Hierarchical Package of Modules](03-advanced/10-modules-build-system/01-hierarchical-modules.md)
- [10.2: Controlling the Import of Everything with pub](03-advanced/10-modules-build-system/02-export-control.md)
- [10.3: Importing Package Submodules Using Relative Names](03-advanced/10-modules-build-system/03-relative-imports.md)
- [10.4: Splitting a Module into Multiple Files](03-advanced/10-modules-build-system/04-splitting-modules.md)
- [10.5: Making Separate Directories of Code Import Under a Common Namespace](03-advanced/10-modules-build-system/05-common-namespace.md)
- [10.6: Reloading Modules](03-advanced/10-modules-build-system/06-reloading-modules.md)
- [10.7: Making a Directory or Archive File Runnable As a Main Script](03-advanced/10-modules-build-system/07-runnable-packages.md)
- [10.8: Reading Datafiles Within a Package](03-advanced/10-modules-build-system/08-reading-datafiles.md)
- [10.9: Adding Directories to the Module Search Path](03-advanced/10-modules-build-system/09-build-paths.md)
- [10.10: Importing Modules Using a Name Given in a String](03-advanced/10-modules-build-system/10-dynamic-imports.md)
- [10.11: Distributing Packages](03-advanced/10-modules-build-system/11-distributing-packages.md)

---

# Phase 4: Specialized Topics

## Chapter 11: Network and Web Programming

- [Overview](04-specialized/11-network-web/index.md)
- [11.1: Making HTTP Requests](04-specialized/11-network-web/01-http-requests.md)
- [11.2: Working with JSON APIs](04-specialized/11-network-web/02-json-apis.md)
- [11.3: WebSocket Communication](04-specialized/11-network-web/03-websocket-communication.md)
- [11.4: Building a Simple HTTP Server](04-specialized/11-network-web/04-http-server.md)
- [11.5: Parsing and Generating XML](04-specialized/11-network-web/05-xml-parsing.md)
- [11.6: Working with REST APIs](04-specialized/11-network-web/06-rest-apis.md)
- [11.7: Handling Cookies and Sessions](04-specialized/11-network-web/07-cookies-sessions.md)
- [11.8: SSL/TLS Connections](04-specialized/11-network-web/08-tls-connections.md)
- [11.9: Uploading and Downloading Files](04-specialized/11-network-web/09-file-transfers.md)
- [11.10: Rate Limiting and Throttling](04-specialized/11-network-web/10-rate-limiting.md)
- [11.11: GraphQL Client Implementation](04-specialized/11-network-web/11-graphql-client.md)
- [11.12: OAuth2 Authentication](04-specialized/11-network-web/12-oauth2-authentication.md)

## Chapter 12: Concurrency

- [Overview](04-specialized/12-concurrency/index.md)
- [12.1: Basic Threading and Thread Management](04-specialized/12-concurrency/01-basic-threading.md)
- [12.2: Mutexes and Basic Locking](04-specialized/12-concurrency/02-mutexes-locking.md)
- [12.3: Atomic Operations](04-specialized/12-concurrency/03-atomic-operations.md)
- [12.4: Thread Pools for Parallel Work](04-specialized/12-concurrency/04-thread-pools.md)
- [12.5: Thread-Safe Queues and Channels](04-specialized/12-concurrency/05-queues-channels.md)
- [12.6: Condition Variables and Signaling](04-specialized/12-concurrency/06-condition-variables.md)
- [12.7: Read-Write Locks](04-specialized/12-concurrency/07-read-write-locks.md)
- [12.10: Wait Groups for Synchronization](04-specialized/12-concurrency/10-wait-groups.md)

## Chapter 13: Utility Scripting and System Administration

- [Overview](04-specialized/13-utility-scripting/index.md)

## Chapter 14: Testing, Debugging, and Exceptions

- [Overview](04-specialized/14-testing-debugging/index.md)
- [14.1: Testing program output sent to stdout](04-specialized/14-testing-debugging/01-testing-output-to-stdout.md)
- [14.2: Patching objects in unit tests](04-specialized/14-testing-debugging/02-patching-objects-in-unit-tests.md)
- [14.3: Testing for exceptional conditions in unit tests](04-specialized/14-testing-debugging/03-testing-exceptional-conditions.md)
- [14.4: Logging test output to a file](04-specialized/14-testing-debugging/04-logging-test-output-to-file.md)
- [14.5: Skipping or anticipating test failures](04-specialized/14-testing-debugging/05-skipping-anticipating-test-failures.md)
- [14.6: Handling multiple exceptions at once](04-specialized/14-testing-debugging/06-handling-multiple-exceptions.md)
- [14.7: Catching all exceptions](04-specialized/14-testing-debugging/07-catching-all-exceptions.md)
- [14.8: Creating custom exception types](04-specialized/14-testing-debugging/08-creating-custom-exception-types.md)
- [14.9: Raising an exception in response to another exception](04-specialized/14-testing-debugging/09-raising-exception-in-response.md)
- [14.10: Reraising the last exception](04-specialized/14-testing-debugging/10-reraising-last-exception.md)
- [14.11: Issuing warning messages](04-specialized/14-testing-debugging/11-issuing-warning-messages.md)
- [14.12: Debugging basic program crashes](04-specialized/14-testing-debugging/12-debugging-basic-crashes.md)
- [14.13: Profiling and timing your program](04-specialized/14-testing-debugging/13-profiling-and-timing.md)
- [14.14: Making your programs run faster](04-specialized/14-testing-debugging/14-making-programs-faster.md)

## Chapter 15: C Interoperability

- [Overview](04-specialized/15-c-interoperability/index.md)
- [15.1: Accessing C code from Zig](04-specialized/15-c-interoperability/01-accessing-c-code.md)
- [15.2: Writing a Zig library callable from C](04-specialized/15-c-interoperability/02-writing-c-library.md)
- [15.3: Passing arrays between C and Zig](04-specialized/15-c-interoperability/03-passing-arrays.md)
- [15.4: Managing opaque types in C extensions](04-specialized/15-c-interoperability/04-managing-opaque-types.md)
- [15.5: Wrapping existing C libraries](04-specialized/15-c-interoperability/05-wrapping-c-libraries.md)
- [15.6: Passing NULL-terminated strings to C functions](04-specialized/15-c-interoperability/06-null-terminated-strings.md)
- [15.7: Calling C functions with variadic arguments](04-specialized/15-c-interoperability/07-variadic-arguments.md)

---

# Phase 5: Zig Paradigms

## Chapter 16: The Zig Build System

- [Overview](05-zig-paradigms/16-zig-build-system/index.md)
- [16.1: Basic build.zig setup](05-zig-paradigms/16-zig-build-system/01-basic-build-setup.md)
- [16.2: Multiple executables and libraries](05-zig-paradigms/16-zig-build-system/02-multiple-artifacts.md)
- [16.3: Managing dependencies](05-zig-paradigms/16-zig-build-system/03-managing-dependencies.md)
- [16.4: Custom build steps](05-zig-paradigms/16-zig-build-system/04-custom-build-steps.md)
- [16.5: Cross-compilation](05-zig-paradigms/16-zig-build-system/05-cross-compilation.md)
- [16.6: Build options and configurations](05-zig-paradigms/16-zig-build-system/06-build-options-configurations.md)
- [16.7: Testing in the build system](05-zig-paradigms/16-zig-build-system/07-testing-in-build-system.md)

## Chapter 17: Advanced Comptime Metaprogramming

- [Overview](05-zig-paradigms/17-advanced-comptime/index.md)
- [17.1: Type-Level Pattern Matching](05-zig-paradigms/17-advanced-comptime/01-type-level-pattern-matching.md)
- [17.2: Compile-Time String Processing](05-zig-paradigms/17-advanced-comptime/02-compile-time-string-processing.md)
- [17.3: Compile-Time Assertions](05-zig-paradigms/17-advanced-comptime/03-compile-time-assertions.md)
- [17.4: Generic Data Structure Generation](05-zig-paradigms/17-advanced-comptime/04-generic-data-structure-generation.md)
- [17.5: Compile-Time Dependency Injection](05-zig-paradigms/17-advanced-comptime/05-compile-time-dependency-injection.md)
- [17.6: Build-Time Resource Embedding](05-zig-paradigms/17-advanced-comptime/06-build-time-resource-embedding.md)
- [17.7: Comptime Function Memoization](05-zig-paradigms/17-advanced-comptime/07-comptime-function-memoization.md)

## Chapter 18: Explicit Memory Management Patterns

- [Overview](05-zig-paradigms/18-memory-management/index.md)
- [18.1: Custom Allocator Implementation](05-zig-paradigms/18-memory-management/01-custom-allocator-implementation.md)
- [18.2: Arena Allocator Patterns for Request Handling](05-zig-paradigms/18-memory-management/02-arena-allocator-patterns.md)
- [18.3: Memory-Mapped I/O for Large Files](05-zig-paradigms/18-memory-management/03-memory-mapped-io.md)
- [18.4: Object Pool Management](05-zig-paradigms/18-memory-management/04-object-pool-management.md)
- [18.5: Stack-Based Allocation with FixedBufferAllocator](05-zig-paradigms/18-memory-management/05-stack-based-allocation.md)
- [18.6: Tracking and Debugging Memory Usage](05-zig-paradigms/18-memory-management/06-tracking-debugging-memory.md)

## Chapter 19: WebAssembly and Freestanding Targets

- [Overview](05-zig-paradigms/19-webassembly-freestanding/index.md)
- [19.1: Building a Basic WebAssembly Module](05-zig-paradigms/19-webassembly-freestanding/01-basic-wasm-module.md)
- [19.2: Exporting Functions to JavaScript](05-zig-paradigms/19-webassembly-freestanding/02-exporting-functions.md)
- [19.3: Importing and Calling JavaScript Functions](05-zig-paradigms/19-webassembly-freestanding/03-importing-javascript-functions.md)
- [19.4: Passing Strings and Data Between Zig and JavaScript](05-zig-paradigms/19-webassembly-freestanding/04-passing-strings-and-data.md)
- [19.5: Custom Allocators for Freestanding Targets](05-zig-paradigms/19-webassembly-freestanding/05-custom-allocators.md)
- [19.6: Implementing a Panic Handler for WASM](05-zig-paradigms/19-webassembly-freestanding/06-panic-handler.md)

## Chapter 20: High-Performance & Low-Level Networking

- [Overview](05-zig-paradigms/20-high-perf-networking/index.md)
- [20.1: Non-Blocking TCP Servers with Poll](05-zig-paradigms/20-high-perf-networking/01-nonblocking-tcp-servers.md)
- [20.2: Zero-Copy Networking Using sendfile](05-zig-paradigms/20-high-perf-networking/02-zero-copy-sendfile.md)
- [20.3: Parsing Raw Packets with Packed Structs](05-zig-paradigms/20-high-perf-networking/03-parsing-raw-packets.md)
- [20.4: Implementing a Basic HTTP/1.1 Parser](05-zig-paradigms/20-high-perf-networking/04-http-parser.md)
- [20.5: Using UDP Multicast](05-zig-paradigms/20-high-perf-networking/05-udp-multicast.md)
- [20.6: Creating Raw Sockets](05-zig-paradigms/20-high-perf-networking/06-raw-sockets.md)
