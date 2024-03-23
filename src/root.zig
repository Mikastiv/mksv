const std = @import("std");
const testing = std.testing;

const assert = std.debug.assert;
const expect = std.testing.expect;

pub const SpinLock = struct {
    const AtomicFlag = std.atomic.Value(bool);
    const locked = true;
    const unlocked = false;

    atomic_flag: AtomicFlag,

    pub fn init() SpinLock {
        return .{
            .atomic_flag = AtomicFlag.init(unlocked),
        };
    }

    pub fn tryLock(self: *SpinLock) bool {
        return self.atomic_flag.cmpxchgWeak(unlocked, locked, .Acquire, .Monotonic) == null;
    }

    pub fn lock(self: *SpinLock) void {
        while (!self.tryLock()) {
            std.atomic.spinLoopHint();
        }
    }

    pub fn unlock(self: *SpinLock) void {
        self.atomic_flag.store(unlocked, .Release);
    }
};

pub const ReentrantLock = struct {
    const AtomicThreadId = std.atomic.Value(std.Thread.Id);
    const unlocked = 0;

    atomic_tid: AtomicThreadId,
    ref_count: u32,

    pub fn init() ReentrantLock {
        return .{
            .atomic_tid = AtomicThreadId.init(unlocked),
            .ref_count = 0,
        };
    }

    pub fn tryLock(self: *ReentrantLock) bool {
        const tid = std.Thread.getCurrentId();

        var acquired = false;

        if (self.atomic_tid.load(.Monotonic) == tid) {
            acquired = true;
        } else if (self.atomic_tid.cmpxchgWeak(unlocked, tid, .Monotonic, .Monotonic) == null) {
            acquired = true;
        }

        if (acquired) {
            self.ref_count += 1;
            @fence(.Acquire);
        }

        return acquired;
    }

    pub fn lock(self: *ReentrantLock) void {
        const tid = std.Thread.getCurrentId();

        if (self.atomic_tid.load(.Monotonic) != tid) {
            while (self.atomic_tid.cmpxchgWeak(0, tid, .Monotonic, .Monotonic) != null) {
                std.atomic.spinLoopHint();
            }
        }

        self.ref_count += 1;

        @fence(.Acquire);
    }

    pub fn unlock(self: *ReentrantLock) void {
        @fence(.Release);

        const tid = std.Thread.getCurrentId();
        const cached_tid = self.atomic_tid.load(.Monotonic);
        assert(tid == cached_tid);

        self.ref_count -= 1;
        if (self.ref_count == 0) {
            self.atomic_tid.store(0, .Monotonic);
        }
    }
};

pub const RwLock = struct {
    const AtomicCounter = std.atomic.Value(u32);
    const exclusive_lock_bit = 1 << 31;
    const reader_mask = ~@as(u32, exclusive_lock_bit);
    const unlocked = 0;

    atomic_counter: AtomicCounter,

    pub fn init() RwLock {
        return .{
            .atomic_counter = AtomicCounter.init(0),
        };
    }

    pub fn tryLockShared(self: *RwLock) bool {
        const counter = self.atomic_counter.load(.Monotonic);
        if (counter & exclusive_lock_bit != 0) return false; // a writer has the lock

        return self.atomic_counter.cmpxchgWeak(counter, counter + 1, .Acquire, .Monotonic) == null;
    }

    pub fn tryLock(self: *RwLock) bool {
        return self.atomic_counter.cmpxchgWeak(unlocked, exclusive_lock_bit, .Acquire, .Monotonic) == null;
    }

    pub fn lockShared(self: *RwLock) void {
        while (!self.tryLockShared()) {
            std.atomic.spinLoopHint();
        }
    }

    pub fn unlockShared(self: *RwLock) void {
        const old = self.atomic_counter.rmw(.Sub, 1, .Release);
        assert(old != 0);
    }

    pub fn lock(self: *RwLock) void {
        while (true) {
            const counter = self.atomic_counter.load(.Monotonic);
            if (counter & exclusive_lock_bit != 0) {
                std.atomic.spinLoopHint();
                continue;
            }

            if (self.atomic_counter.cmpxchgWeak(counter, counter | exclusive_lock_bit, .Acquire, .Monotonic) == null) {
                if (counter == exclusive_lock_bit) return; // no readers to wait for

                break;
            }
        }

        // Wait for all the readers
        while (true) {
            const counter = self.atomic_counter.load(.Acquire);
            if (counter & reader_mask == 0) break;

            std.atomic.spinLoopHint();
        }
    }

    pub fn unlock(self: *RwLock) void {
        const old = self.atomic_counter.rmw(.Xchg, unlocked, .Release);
        assert(old == exclusive_lock_bit);
    }
};

fn testSpinIncrement(lock: *SpinLock, value: *usize) void {
    for (0..1000000) |_| {
        lock.lock();
        defer lock.unlock();

        value.* += 1;
    }
}

test "spinlock" {
    var lock = SpinLock.init();
    var value: usize = 0;

    const t1 = try std.Thread.spawn(.{}, testSpinIncrement, .{ &lock, &value });
    const t2 = try std.Thread.spawn(.{}, testSpinIncrement, .{ &lock, &value });
    t1.join();
    t2.join();

    try expect(value == 2000000);
}

fn testReentrantIncrement(lock: *ReentrantLock, value: *usize) void {
    for (0..10000) |_| {
        lock.lock();
        defer lock.unlock();

        lock.lock();
        defer lock.unlock();
        lock.lock();
        defer lock.unlock();
        value.* += 1;
    }
}

test "reentrant lock" {
    var lock = ReentrantLock.init();
    var value: usize = 0;

    const t1 = try std.Thread.spawn(.{}, testReentrantIncrement, .{ &lock, &value });
    const t2 = try std.Thread.spawn(.{}, testReentrantIncrement, .{ &lock, &value });
    t1.join();
    t2.join();

    try expect(value == 20000);
}

fn testRwLockReader(lock: *RwLock, value: *usize) !void {
    const read_count = 10000;

    var i: usize = 0;
    while (i < read_count) : (i += 1) {
        lock.lockShared();
        defer lock.unlockShared();

        if (value.* < 20000) {
            i += 1;
        }

        try std.Thread.yield();
    }
}

fn testRwLockWriter(lock: *RwLock, value: *usize) !void {
    const write_count = 10000;

    var i: usize = 0;
    while (i < write_count) : (i += 1) {
        lock.lock();
        defer lock.unlock();

        value.* += 1;

        try std.Thread.yield();
    }
}

test "rwlock" {
    var lock = RwLock.init();
    var value: usize = 0;

    const num_readers = 6;
    const num_writers = 2;

    var threads: [num_readers + num_writers]std.Thread = undefined;
    for (threads[0..num_readers]) |*t| t.* = try std.Thread.spawn(.{}, testRwLockReader, .{ &lock, &value });
    for (threads[num_readers..]) |*t| t.* = try std.Thread.spawn(.{}, testRwLockWriter, .{ &lock, &value });

    for (threads) |t| t.join();

    try expect(value == num_writers * 10000);

    lock.lock();
    try expect(!lock.tryLock());
    try expect(!lock.tryLockShared());
    lock.unlock();

    try expect(lock.tryLock());
    try expect(!lock.tryLock());
    try expect(!lock.tryLockShared());
    lock.unlock();

    lock.lockShared();
    try expect(!lock.tryLock());
    try expect(lock.tryLockShared());
    lock.lockShared();
    lock.unlockShared();
    lock.unlockShared();
    lock.unlockShared();

    try expect(lock.tryLockShared());
    try expect(!lock.tryLock());
    try expect(lock.tryLockShared());
    lock.unlockShared();
    lock.unlockShared();
}
