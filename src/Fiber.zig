const std = @import("std");
const builtin = @import("builtin");

const assert = std.debug.assert;

const stack_alignment = 16;

pub const minimum_stack_size = std.mem.page_size;

pub const NonVolatileRegister = switch (builtin.os.tag) {
    .windows => switch (builtin.cpu.arch) {
        .x86_64 => enum(u8) {
            rbx = 0,
            rbp = 1,
            rdi = 2,
            rsi = 3,
            r12 = 4,
            r13 = 5,
            r14 = 6,
            r15 = 7,
            rcx = 8, // first function argument
            rsp = 9,
            rip = 10,
        },
        else => @compileError("fibers not implemented for architecture " ++ @tagName(builtin.os.tag)),
    },
    .linux => switch (builtin.cpu.arch) {
        .x86_64 => enum(u8) {
            rbx = 0,
            rbp = 1,
            r12 = 2,
            r13 = 3,
            r14 = 4,
            r15 = 5,
            rdi = 6, // first function argument
            rsp = 7,
            rip = 8,
        },
    },
    else => @compileError("fibers not implemented for os " ++ @tagName(builtin.os.tag)),
};

pub const Registers = std.EnumArray(NonVolatileRegister, u64);
pub const Fiber = @This();

comptime {
    assert(@offsetOf(Fiber, "context") == 0);
    assert(@offsetOf(Registers, "values") == 0);
}

context: Registers,
stack_memory: ?[]u8,
allocator: ?std.mem.Allocator,

pub fn init(
    allocator: std.mem.Allocator,
    comptime stack_size: usize,
    func: *const fn (?*anyopaque) callconv(.C) noreturn,
    arg: ?*anyopaque,
) !Fiber {
    comptime assert(stack_size >= minimum_stack_size);

    const memory = try allocator.alignedAlloc(u8, stack_alignment, minimum_stack_size);
    errdefer allocator.free(memory);

    const stack_top = &memory[memory.len - @sizeOf(usize)];
    const context = Registers.initDefault(0, .{
        .rip = @intFromPtr(func),
        .rcx = @intFromPtr(arg),
        .rsp = @intFromPtr(stack_top),
    });

    return .{
        .context = context,
        .stack_memory = memory,
        .allocator = allocator,
    };
}

pub fn deinit(self: *const Fiber) void {
    if (self.allocator) |allocator| {
        allocator.free(self.stack_memory.?);
    }
}

pub fn switchThreadToFiber() !Fiber {
    return .{
        .context = Registers.initFill(0),
        .stack_memory = null,
        .allocator = null,
    };
}

pub extern fn switchTo(from: *Fiber, to: *Fiber) callconv(.C) void;
comptime {
    switch (builtin.os.tag) {
        .windows => switch (builtin.cpu.arch) {
            .x86_64 => asm (
                \\.global switchTo;
                \\
                \\switchTo:
                \\
                // store non-volatile registers into "from"
                \\movq %rbx, 0x00(%rcx)
                \\movq %rbp, 0x08(%rcx)
                \\movq %rdi, 0x10(%rcx)
                \\movq %rsi, 0x18(%rcx)
                \\movq %r12, 0x20(%rcx)
                \\movq %r13, 0x28(%rcx)
                \\movq %r14, 0x30(%rcx)
                \\movq %r15, 0x38(%rcx)
                \\
                // store return address
                \\movq (%rsp), %r8
                \\movq %r8, 0x50(%rcx)
                \\
                // store stack pointer (skip return address)
                \\leaq 0x08(%rsp), %r8
                \\movq %r8, 0x48(%rcx)
                \\
                // load "to" registers
                \\movq 0x00(%rdx), %rbx
                \\movq 0x08(%rdx), %rbp
                \\movq 0x10(%rdx), %rdi
                \\movq 0x18(%rdx), %rsi
                \\movq 0x20(%rdx), %r12
                \\movq 0x28(%rdx), %r13
                \\movq 0x30(%rdx), %r14
                \\movq 0x38(%rdx), %r15
                \\
                // load function param
                \\movq 0x40(%rdx), %rcx
                \\
                // load stack pointer
                \\movq 0x48(%rdx), %rsp
                \\
                // jmp to instruction
                \\movq 0x50(%rdx), %rax
                \\jmpq *%rax
            ),
            else => @compileError("fibers not implemented for architecture " ++ @tagName(builtin.os.tag)),
        },
        .linux => switch (builtin.cpu.arch) {
            .x86_64 => asm (
                \\.global switchTo;
                \\
                \\switchTo:
                \\
                // store non-volatile registers into "from"
                \\movq %rbx, 0x00(%rdi)
                \\movq %rbp, 0x08(%rdi)
                \\movq %r12, 0x10(%rdi)
                \\movq %r13, 0x18(%rdi)
                \\movq %r14, 0x20(%rdi)
                \\movq %r15, 0x28(%rdi)
                \\
                // store return address
                \\movq (%rsp), %r8
                \\movq %r8, 0x40(%rdi)
                \\
                // store stack pointer (skip return address)
                \\leaq 0x08(%rsp), %r8
                \\movq %r8, 0x38(%rdi)
                \\
                // load "to" registers
                \\movq 0x00(%rsi), %rbx
                \\movq 0x08(%rsi), %rbp
                \\movq 0x10(%rsi), %r12
                \\movq 0x18(%rsi), %r13
                \\movq 0x20(%rsi), %r14
                \\movq 0x28(%rsi), %r15
                \\
                // load function param
                \\movq 30(%rsi), %rdi
                \\
                // load stack pointer
                \\movq 0x38(%rsi), %rsp
                \\
                // jmp to instruction
                \\movq 0x40(%rsi), %rax
                \\jmpq *%rax
            ),
        },
        else => @compileError("fibers not implemented for os " ++ @tagName(builtin.os.tag)),
    }
}
