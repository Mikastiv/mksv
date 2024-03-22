const std = @import("std");
const testing = std.testing;

const assert = std.debug.assert;

pub const SpinLock = struct {
    atomic_flag: std.atomic.Value(bool),

    pub fn tryLock(self: *SpinLock) bool {
        const failed = self.atomic_flag.swap(true, .Acquire);
        return !failed;
    }

    pub fn lock(self: *SpinLock) void {
        while (self.atomic_flag.cmpxchgWeak(false, true, .Acquire, .Unordered) != null) {
            std.Thread.yield() catch {};
        }
    }

    pub fn unlock(self: *SpinLock) void {
        self.atomic_flag.store(false, .Release);
    }
};
