const std = @import("std");
const testing = std.testing;

const assert = std.debug.assert;

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

fn takeLock(lock: *SpinLock) void {
    lock.acquire();
    std.time.sleep(std.time.ns_per_s);
    lock.release();
}

test "spinlock" {
    var lock = SpinLock.init();

    const t1 = try std.Thread.spawn(.{}, takeLock, .{&lock});
    const t2 = try std.Thread.spawn(.{}, takeLock, .{&lock});
    t1.join();
    t2.join();
}
