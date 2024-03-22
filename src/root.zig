const std = @import("std");
const testing = std.testing;

const assert = std.debug.assert;
const expect = std.testing.expect;

pub const SpinLock = struct {
    const AtomicFlag = std.atomic.Value(bool);

    atomic_flag: AtomicFlag,

    pub fn init() SpinLock {
        return .{
            .atomic_flag = AtomicFlag.init(false),
        };
    }

    pub fn tryAcquire(self: *SpinLock) bool {
        const failed = self.atomic_flag.swap(true, .Acquire);
        return !failed;
    }

    pub fn acquire(self: *SpinLock) void {
        while (self.atomic_flag.cmpxchgWeak(false, true, .Acquire, .Monotonic) != null) {
            std.Thread.yield() catch {};
        }
    }

    pub fn release(self: *SpinLock) void {
        self.atomic_flag.store(false, .Release);
    }
};

pub const ReentrantLock = struct {
    const AtomicThreadId = std.atomic.Value(std.Thread.Id);

    atomic_tid: AtomicThreadId,
    ref_count: u32,

    pub fn init() ReentrantLock {
        return .{
            .atomic_tid = AtomicThreadId.init(0),
            .ref_count = 0,
        };
    }

    pub fn tryAcquire(self: *ReentrantLock) bool {
        const tid = std.Thread.getCurrentId();

        var acquired = false;

        if (self.atomic_tid.load(.Monotonic) == tid) {
            acquired = true;
        } else if (self.atomic_tid.cmpxchgWeak(0, tid, .Monotonic, .Monotonic) == null) {
            acquired = true;
        }

        if (acquired) {
            self.ref_count += 1;
            @fence(.Acquire);
        }

        return acquired;
    }

    pub fn acquire(self: *ReentrantLock) void {
        const tid = std.Thread.getCurrentId();

        if (self.atomic_tid.load(.Monotonic) != tid) {
            while (self.atomic_tid.cmpxchgWeak(0, tid, .Monotonic, .Monotonic) != null) {
                std.Thread.yield() catch {};
            }
        }

        self.ref_count += 1;

        @fence(.Acquire);
    }

    pub fn release(self: *ReentrantLock) void {
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

fn testSpinIncrement(lock: *SpinLock, value: *usize) void {
    for (0..1000000) |_| {
        lock.acquire();
        defer lock.release();

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
        lock.acquire();
        defer lock.release();

        lock.acquire();
        defer lock.release();
        lock.acquire();
        defer lock.release();
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
