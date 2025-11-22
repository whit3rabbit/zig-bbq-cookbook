// Recipe 8.19: Implementing Stateful Objects or State Machines
// Target Zig Version: 0.15.2

const std = @import("std");
const testing = std.testing;

// ANCHOR: basic_state_machine
// Basic state machine with enum
const ConnectionState = enum {
    disconnected,
    connecting,
    connected,
    error_state,

    pub fn canTransition(self: ConnectionState, target: ConnectionState) bool {
        return switch (self) {
            .disconnected => target == .connecting,
            .connecting => target == .connected or target == .error_state,
            .connected => target == .disconnected or target == .error_state,
            .error_state => target == .disconnected,
        };
    }
};

const Connection = struct {
    state: ConnectionState,
    attempts: u32,

    pub fn init() Connection {
        return Connection{
            .state = .disconnected,
            .attempts = 0,
        };
    }

    pub fn connect(self: *Connection) !void {
        if (!self.state.canTransition(.connecting)) {
            return error.InvalidTransition;
        }
        self.state = .connecting;
        self.attempts += 1;
    }

    pub fn complete(self: *Connection) !void {
        if (!self.state.canTransition(.connected)) {
            return error.InvalidTransition;
        }
        self.state = .connected;
    }

    pub fn disconnect(self: *Connection) !void {
        if (!self.state.canTransition(.disconnected)) {
            return error.InvalidTransition;
        }
        self.state = .disconnected;
    }

    pub fn fail(self: *Connection) !void {
        if (!self.state.canTransition(.error_state)) {
            return error.InvalidTransition;
        }
        self.state = .error_state;
    }
};

test "basic state machine" {
    var conn = Connection.init();
    try testing.expectEqual(ConnectionState.disconnected, conn.state);

    try conn.connect();
    try testing.expectEqual(ConnectionState.connecting, conn.state);

    try conn.complete();
    try testing.expectEqual(ConnectionState.connected, conn.state);

    try conn.disconnect();
    try testing.expectEqual(ConnectionState.disconnected, conn.state);
}
// ANCHOR_END: basic_state_machine

// ANCHOR: state_pattern
// State pattern with behavior
const DoorState = union(enum) {
    closed: void,
    opening: u32,
    open: void,
    closing: u32,

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

    pub fn init() Door {
        return Door{ .state = .{ .closed = {} } };
    }

    pub fn open(self: *Door) void {
        switch (self.state) {
            .closed => self.state = .{ .opening = 0 },
            else => {},
        }
    }

    pub fn close(self: *Door) void {
        switch (self.state) {
            .open => self.state = .{ .closing = 0 },
            else => {},
        }
    }

    pub fn update(self: *Door, delta: u32) []const u8 {
        self.state.advance(delta);
        return self.state.handle();
    }
};

test "state pattern" {
    var door = Door.init();
    door.open();

    const msg1 = door.update(50);
    try testing.expectEqualStrings("Door opening", msg1);

    const msg2 = door.update(60);
    try testing.expectEqualStrings("Door fully open", msg2);

    door.close();
    _ = door.update(100);
    try testing.expect(std.meta.activeTag(door.state) == .closed);
}
// ANCHOR_END: state_pattern

// ANCHOR: event_driven_fsm
// Event-driven finite state machine
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

    pub fn init() TrafficLight {
        return TrafficLight{
            .state = .red,
            .timer = 0,
        };
    }

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

test "event driven fsm" {
    var light = TrafficLight.init();
    try testing.expectEqual(TrafficLight.State.red, light.state);

    // Simulate time passing
    var i: u32 = 0;
    while (i < 31) : (i += 1) {
        light.tick();
    }
    try testing.expectEqual(TrafficLight.State.green, light.state);

    light.handle(.emergency);
    try testing.expectEqual(TrafficLight.State.red, light.state);
}
// ANCHOR_END: event_driven_fsm

// ANCHOR: state_with_actions
// State machine with entry/exit actions
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

    pub fn init() Order {
        return Order{
            .state = .pending,
            .notifications_sent = 0,
        };
    }

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

test "state with actions" {
    var order = Order.init();

    try order.transition(.processing);
    try testing.expectEqual(@as(u32, 1), order.notifications_sent);

    try order.transition(.shipped);
    try testing.expectEqual(@as(u32, 2), order.notifications_sent);

    try order.transition(.delivered);
    try testing.expectEqual(OrderState.delivered, order.state);
}
// ANCHOR_END: state_with_actions

// ANCHOR: hierarchical_states
// Hierarchical state machine
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
    health: u32,

    pub fn init() Player {
        return Player{
            .state = .{ .idle = {} },
            .health = 100,
        };
    }

    pub fn move(self: *Player, speed: f32) void {
        if (!self.state.isInCombat()) {
            self.state = .{ .moving = .{ .speed = speed, .direction = .forward } };
        }
    }

    pub fn attack(self: *Player) void {
        self.state = .{ .combat = .{ .attacking = 0 } };
    }

    pub fn stopCombat(self: *Player) void {
        if (self.state.isInCombat()) {
            self.state = .{ .idle = {} };
        }
    }
};

test "hierarchical states" {
    var player = Player.init();
    try testing.expect(!player.state.isInCombat());

    player.move(5.0);
    try testing.expect(player.state.isMoving());

    player.attack();
    try testing.expect(player.state.isInCombat());

    player.stopCombat();
    try testing.expect(!player.state.isInCombat());
}
// ANCHOR_END: hierarchical_states

// ANCHOR: state_history
// State machine with history
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

    pub fn getHistoryCount(self: *const Workflow) usize {
        return self.history.items.len;
    }
};

test "state history" {
    var workflow = Workflow.init(testing.allocator);
    defer workflow.deinit();

    try workflow.transition(.review);
    try workflow.transition(.approved);
    try testing.expectEqual(WorkflowState.approved, workflow.current);
    try testing.expectEqual(@as(usize, 2), workflow.getHistoryCount());

    try workflow.undo();
    try testing.expectEqual(WorkflowState.review, workflow.current);

    try workflow.undo();
    try testing.expectEqual(WorkflowState.draft, workflow.current);
}
// ANCHOR_END: state_history

// ANCHOR: guarded_transitions
// State machine with guards
const ATMState = enum {
    idle,
    card_inserted,
    pin_entered,
    authenticated,
    dispensing,
};

const ATM = struct {
    state: ATMState,
    balance: u32,
    pin_attempts: u32,

    pub fn init(balance: u32) ATM {
        return ATM{
            .state = .idle,
            .balance = balance,
            .pin_attempts = 0,
        };
    }

    pub fn insertCard(self: *ATM) !void {
        if (self.state != .idle) return error.InvalidState;
        self.state = .card_inserted;
        self.pin_attempts = 0;
    }

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

    pub fn complete(self: *ATM) void {
        self.state = .idle;
    }
};

test "guarded transitions" {
    var atm = ATM.init(1000);

    try atm.insertCard();
    try testing.expectEqual(ATMState.card_inserted, atm.state);

    const wrong_pin = atm.enterPin(9999);
    try testing.expectError(error.InvalidPin, wrong_pin);
    try testing.expectEqual(@as(u32, 1), atm.pin_attempts);

    try atm.enterPin(1234);
    try testing.expectEqual(ATMState.authenticated, atm.state);

    try atm.withdraw(500);
    try testing.expectEqual(@as(u32, 500), atm.balance);
}
// ANCHOR_END: guarded_transitions

// ANCHOR: timeout_states
// State machine with timeouts
const SessionState = enum {
    inactive,
    active,
    idle_warning,
    expired,
};

const Session = struct {
    state: SessionState,
    last_activity: u64,
    timeout_ms: u64,

    pub fn init(timeout_ms: u64) Session {
        return Session{
            .state = .inactive,
            .last_activity = 0,
            .timeout_ms = timeout_ms,
        };
    }

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

test "timeout states" {
    var session = Session.init(1000);

    session.activate(0);
    try testing.expectEqual(SessionState.active, session.state);

    session.update(600);
    try testing.expectEqual(SessionState.idle_warning, session.state);

    session.activity(600);
    try testing.expectEqual(SessionState.active, session.state);

    session.update(2000);
    try testing.expectEqual(SessionState.expired, session.state);
}
// ANCHOR_END: timeout_states

// ANCHOR: composite_state
// Composite state machine
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

    pub fn init() MediaPlayer {
        return MediaPlayer{
            .playback = .stopped,
            .repeat = .none,
            .volume = 50,
            .track_index = 0,
        };
    }

    pub fn play(self: *MediaPlayer) void {
        self.playback = .playing;
    }

    pub fn pause(self: *MediaPlayer) void {
        if (self.playback == .playing) {
            self.playback = .paused;
        }
    }

    pub fn stop(self: *MediaPlayer) void {
        self.playback = .stopped;
        self.track_index = 0;
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

test "composite state" {
    var player = MediaPlayer.init();

    player.play();
    try testing.expectEqual(MediaPlayer.PlaybackState.playing, player.playback);

    player.next(10);
    try testing.expectEqual(@as(usize, 1), player.track_index);

    player.setRepeat(.all);
    player.track_index = 9;
    player.next(10);
    try testing.expectEqual(@as(usize, 0), player.track_index);
}
// ANCHOR_END: composite_state

// Comprehensive test
test "comprehensive state machines" {
    // Basic FSM
    var conn = Connection.init();
    try conn.connect();
    try testing.expectEqual(ConnectionState.connecting, conn.state);

    // State pattern
    var door = Door.init();
    door.open();
    _ = door.update(100);
    try testing.expect(std.meta.activeTag(door.state) == .open);

    // Event-driven
    var light = TrafficLight.init();
    light.handle(.emergency);
    try testing.expectEqual(TrafficLight.State.red, light.state);

    // Hierarchical
    var player = Player.init();
    player.attack();
    try testing.expect(player.state.isInCombat());

    // With history
    var workflow = Workflow.init(testing.allocator);
    defer workflow.deinit();
    try workflow.transition(.review);
    try workflow.undo();
    try testing.expectEqual(WorkflowState.draft, workflow.current);
}
