## Problem

You need to model objects that change behavior based on state, enforce valid state transitions, or implement a finite state machine (FSM) for protocols, parsers, or game logic.

## Solution

Use Zig's enums and tagged unions to model states explicitly. Combine them with methods that enforce valid transitions and state-specific behavior.

### Basic State Machine

Use enums to define states and validate transitions:

```zig
{{#include ../../../code/03-advanced/08-structs-unions-objects/recipe_8_19.zig:basic_state_machine}}
```

Invalid transitions return errors at runtime.

### State Pattern with Behavior

Tagged unions carry state-specific data and behavior:

```zig
const DoorState = union(enum) {
    closed: void,
    opening: u32,    // progress percentage
    open: void,
    closing: u32,    // progress percentage

    pub fn handle(self: *DoorState) []const u8 {
        return switch (self.*) {
            .closed => "Door is closed",
            .opening => |progress| blk: {
                if (progress >= 100) {
                    self.* = .{ .open = {} };
                    break :blk "Door fully open";
                }
                break :blk "Door opening";
            },
            .open => "Door is open",
            .closing => |progress| blk: {
                if (progress >= 100) {
                    self.* = .{ .closed = {} };
                    break :blk "Door fully closed";
                }
                break :blk "Door closing";
            },
        };
    }

    pub fn advance(self: *DoorState, amount: u32) void {
        switch (self.*) {
            .opening => |*progress| {
                progress.* = @min(100, progress.* + amount);
            },
            .closing => |*progress| {
                progress.* = @min(100, progress.* + amount);
            },
            else => {},
        }
    }
};

const Door = struct {
    state: DoorState,

    pub fn open(self: *Door) void {
        switch (self.state) {
            .closed => self.state = .{ .opening = 0 },
            else => {},
        }
    }

    pub fn update(self: *Door, delta: u32) []const u8 {
        self.state.advance(delta);
        return self.state.handle();
    }
};
```

State behavior is encapsulated in the union's methods.

### Event-Driven FSM

Process events to trigger state transitions:

```zig
const TrafficLight = struct {
    const State = enum {
        red,
        yellow,
        green,
    };

    const Event = enum {
        timer_expired,
        emergency,
        reset,
    };

    state: State,
    timer: u32,

    pub fn handle(self: *TrafficLight, event: Event) void {
        switch (event) {
            .timer_expired => {
                self.state = switch (self.state) {
                    .red => .green,
                    .green => .yellow,
                    .yellow => .red,
                };
                self.timer = 0;
            },
            .emergency => {
                self.state = .red;
                self.timer = 0;
            },
            .reset => {
                self.state = .red;
                self.timer = 0;
            },
        }
    }

    pub fn tick(self: *TrafficLight) void {
        self.timer += 1;
        const duration: u32 = switch (self.state) {
            .red => 30,
            .green => 25,
            .yellow => 5,
        };
        if (self.timer >= duration) {
            self.handle(.timer_expired);
        }
    }
};
```

Events drive the state machine forward.

### State with Entry/Exit Actions

Execute code when entering or leaving states:

```zig
const OrderState = enum {
    pending,
    processing,
    shipped,
    delivered,
    cancelled,
};

const Order = struct {
    state: OrderState,
    notifications_sent: u32,

    fn onEnter(self: *Order, new_state: OrderState) void {
        switch (new_state) {
            .processing, .shipped, .delivered => {
                self.notifications_sent += 1;
            },
            else => {},
        }
    }

    fn onExit(self: *Order, old_state: OrderState) void {
        _ = self;
        _ = old_state;
        // Cleanup for old state
    }

    pub fn transition(self: *Order, new_state: OrderState) !void {
        const valid = switch (self.state) {
            .pending => new_state == .processing or new_state == .cancelled,
            .processing => new_state == .shipped or new_state == .cancelled,
            .shipped => new_state == .delivered,
            .delivered => false,
            .cancelled => false,
        };

        if (!valid) return error.InvalidTransition;

        self.onExit(self.state);
        self.state = new_state;
        self.onEnter(new_state);
    }
};
```

Entry and exit actions handle state lifecycle.

### Hierarchical State Machines

Nest states within states:

```zig
const PlayerState = union(enum) {
    idle: void,
    moving: struct {
        speed: f32,
        direction: enum { forward, backward },
    },
    combat: union(enum) {
        attacking: u32,
        defending: u32,
        dodging: u32,
    },

    pub fn isInCombat(self: *const PlayerState) bool {
        return switch (self.*) {
            .combat => true,
            else => false,
        };
    }

    pub fn isMoving(self: *const PlayerState) bool {
        return switch (self.*) {
            .moving => true,
            else => false,
        };
    }
};

const Player = struct {
    state: PlayerState,

    pub fn move(self: *Player, speed: f32) void {
        if (!self.state.isInCombat()) {
            self.state = .{ .moving = .{ .speed = speed, .direction = .forward } };
        }
    }

    pub fn attack(self: *Player) void {
        self.state = .{ .combat = .{ .attacking = 0 } };
    }
};
```

Hierarchical states model complex behavior naturally.

### State History

Track previous states for undo functionality:

```zig
const WorkflowState = enum {
    draft,
    review,
    approved,
    published,
    archived,
};

const Workflow = struct {
    current: WorkflowState,
    history: std.ArrayList(WorkflowState),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Workflow {
        return Workflow{
            .current = .draft,
            .history = std.ArrayList(WorkflowState){},
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Workflow) void {
        self.history.deinit(self.allocator);
    }

    pub fn transition(self: *Workflow, new_state: WorkflowState) !void {
        try self.history.append(self.allocator, self.current);
        self.current = new_state;
    }

    pub fn undo(self: *Workflow) !void {
        if (self.history.items.len == 0) return error.NoHistory;
        self.current = self.history.pop().?;
    }
};
```

State history enables undo/redo functionality.

### Guarded Transitions

Add conditions that must be met for transitions:

```zig
const ATM = struct {
    const State = enum {
        idle,
        card_inserted,
        pin_entered,
        authenticated,
        dispensing,
    };

    state: State,
    balance: u32,
    pin_attempts: u32,

    pub fn enterPin(self: *ATM, pin: u32) !void {
        if (self.state != .card_inserted and self.state != .pin_entered) {
            return error.InvalidState;
        }

        if (pin == 1234) {
            self.state = .authenticated;
            self.pin_attempts = 0;
        } else {
            self.pin_attempts += 1;
            if (self.pin_attempts >= 3) {
                self.state = .idle;
                return error.TooManyAttempts;
            }
            self.state = .pin_entered;
            return error.InvalidPin;
        }
    }

    pub fn withdraw(self: *ATM, amount: u32) !void {
        if (self.state != .authenticated) return error.NotAuthenticated;
        if (amount > self.balance) return error.InsufficientFunds;

        self.balance -= amount;
        self.state = .dispensing;
    }
};
```

Guards prevent invalid state changes based on conditions.

### Timeout States

Implement states that expire after a duration:

```zig
const Session = struct {
    const State = enum {
        inactive,
        active,
        idle_warning,
        expired,
    };

    state: State,
    last_activity: u64,
    timeout_ms: u64,

    pub fn activate(self: *Session, current_time: u64) void {
        self.state = .active;
        self.last_activity = current_time;
    }

    pub fn activity(self: *Session, current_time: u64) void {
        if (self.state == .active or self.state == .idle_warning) {
            self.last_activity = current_time;
            self.state = .active;
        }
    }

    pub fn update(self: *Session, current_time: u64) void {
        if (self.state == .inactive or self.state == .expired) {
            return;
        }

        const elapsed = current_time - self.last_activity;

        if (elapsed > self.timeout_ms) {
            self.state = .expired;
        } else if (elapsed > self.timeout_ms / 2) {
            self.state = .idle_warning;
        }
    }
};
```

Time-based state transitions for sessions, caches, and timeouts.

### Composite State Machine

Multiple independent state dimensions:

```zig
const MediaPlayer = struct {
    const PlaybackState = enum {
        stopped,
        playing,
        paused,
    };

    const RepeatMode = enum {
        none,
        one,
        all,
    };

    playback: PlaybackState,
    repeat: RepeatMode,
    volume: u8,
    track_index: usize,

    pub fn play(self: *MediaPlayer) void {
        self.playback = .playing;
    }

    pub fn next(self: *MediaPlayer, total_tracks: usize) void {
        if (self.track_index < total_tracks - 1) {
            self.track_index += 1;
        } else if (self.repeat == .all) {
            self.track_index = 0;
        }
    }

    pub fn setRepeat(self: *MediaPlayer, mode: RepeatMode) void {
        self.repeat = mode;
    }
};
```

Independent state variables model orthogonal concerns.

## Discussion

State machines make complex behavior manageable and testable.

### Why State Machines

**Explicit states**: All states are visible in the type system
```zig
const State = enum { idle, running, paused };
```

**Impossible states**: Type system prevents invalid combinations
```zig
// Can't be both running and paused
state: State,  // Only one value at a time
```

**Clear transitions**: Switch statements make logic obvious
```zig
self.state = switch (self.state) {
    .idle => .running,
    .running => .paused,
    .paused => .running,
};
```

**Testable**: Each state and transition can be tested independently
```zig
test "transition from idle to running" { ... }
```

### State Machine Patterns

**Enum-based**: Simple states without data
```zig
state: enum { off, on, error_state }
```

**Tagged union**: States with associated data
```zig
state: union(enum) {
    idle: void,
    running: struct { progress: u32 },
}
```

**Nested unions**: Hierarchical states
```zig
state: union(enum) {
    idle: void,
    active: union(enum) {
        reading: void,
        writing: struct { bytes: usize },
    },
}
```

**Multiple enums**: Orthogonal state dimensions
```zig
playback_state: PlaybackState,
repeat_mode: RepeatMode,
```

### Transition Validation

**Compile-time validation**: Use switch exhaustiveness
```zig
// Compiler ensures all states handled
const next = switch (current) {
    .idle => .running,
    .running => .paused,
    .paused => .stopped,
    // Forgot one? Compiler error!
};
```

**Runtime validation**: Return errors for invalid transitions
```zig
pub fn transition(from: State, to: State) !void {
    if (!validTransition(from, to)) {
        return error.InvalidTransition;
    }
}
```

**Transition table**: Explicit allowed transitions
```zig
pub fn canTransition(self: State, target: State) bool {
    return switch (self) {
        .idle => target == .running,
        .running => target == .paused or target == .stopped,
        // ...
    };
}
```

### Design Guidelines

**Keep states simple**: Each state should have a clear purpose

**Explicit transitions**: Make state changes obvious
```zig
self.state = .new_state;  // Clear
```

**Validate transitions**: Check if transition is valid before changing
```zig
if (!self.state.canTransition(.new_state)) {
    return error.InvalidTransition;
}
```

**Use entry/exit actions**: Handle initialization and cleanup
```zig
self.onExit(old_state);
self.state = new_state;
self.onEnter(new_state);
```

**Document state diagram**: Comment or document the state machine structure
```zig
// State diagram:
// idle -> connecting -> connected -> disconnected
//         |                |
//         +-> error <------+
```

### Performance

**Enum states**: Zero overhead
- Stored as integer (u8, u16, etc.)
- Switch compiles to jump table
- No allocation, no pointers

**Tagged unions**: Size of largest variant + tag
- Tag is an enum (small integer)
- Union is size of biggest state data
- Still no heap allocation

**State transitions**: Simple assignments
- No function calls unless you add them
- Inline validation checks
- Compiler optimizes switches

### Common Use Cases

**Protocol implementation**:
- Network connections (TCP state machine)
- HTTP request/response states
- WebSocket handshake

**Parsers**:
- Lexer states
- Parser states
- Format validators

**Game logic**:
- Player states (idle, moving, attacking)
- AI behavior trees
- Menu systems

**Business logic**:
- Order processing (pending, shipped, delivered)
- User registration flows
- Workflow engines

**UI state**:
- Form validation states
- Loading/error/success states
- Modal dialog states

## See Also

- Recipe 8.12: Defining an Interface or Abstract Base Class
- Recipe 8.20: Implementing the Visitor Pattern
- Recipe 9.11: Using comptime to Control Instance Creation
- Recipe 7.2: Using Enums for State Representation

Full compilable example: `code/03-advanced/08-structs-unions-objects/recipe_8_19.zig`
