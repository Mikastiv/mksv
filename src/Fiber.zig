const std = @import("std");
const builtin = @import("builtin");

const assert = std.debug.assert;

const stack_alignment = 16;
const red_zone_bytes = 128;

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

            argument = 8,
            stack_pointer = 9,
            program_counter = 10,
        },
        else => architectureUnsupported(),
    },
    .linux => switch (builtin.cpu.arch) {
        .x86_64 => enum(u8) {
            rbx = 0,
            rbp = 1,
            r12 = 2,
            r13 = 3,
            r14 = 4,
            r15 = 5,

            argument = 6,
            stack_pointer = 7,
            program_counter = 8,
        },
        else => architectureUnsupported(),
    },
    else => osUnsupported(),
};

pub const NonVolatileSimdRegister = switch (builtin.os.tag) {
    .windows => switch (builtin.cpu.arch) {
        .x86_64 => enum(u8) {
            xmm6 = 0,
            xmm7 = 1,
            xmm8 = 2,
            xmm9 = 3,
            xmm10 = 4,
            xmm11 = 5,
            xmm12 = 6,
            xmm13 = 7,
            xmm14 = 8,
            xmm15 = 9,
        },
        else => architectureUnsupported(),
    },
    .linux => switch (builtin.cpu.arch) {
        .x86_64 => enum(u8) {},
        else => architectureUnsupported(),
    },
    else => osUnsupported(),
};

pub const Registers = std.EnumArray(NonVolatileRegister, u64);
pub const SimdRegisters = std.EnumArray(NonVolatileSimdRegister, u64);
pub const Context = struct {
    registers: Registers,
    simd: if (builtin.os.tag == .windows) SimdRegisters else void,
};

const Fiber = @This();

comptime {
    assert(@offsetOf(Context, "registers") == 0);
    if (builtin.os.tag == .windows) {
        assert(@offsetOf(Context, "simd") == 88);
        assert(@offsetOf(SimdRegisters, "values") == 0);
    }
    assert(@offsetOf(Fiber, "context") == 0);
    assert(@offsetOf(Registers, "values") == 0);
}

context: Context,
stack_memory: ?[]u8,
allocator: ?std.mem.Allocator,

pub fn init(
    allocator: std.mem.Allocator,
    comptime stack_size: usize,
    func: *const fn (?*anyopaque) callconv(.C) noreturn,
    arg: ?*anyopaque,
) !Fiber {
    comptime assert(stack_size >= minimum_stack_size);

    const size = std.mem.alignForward(usize, stack_size, stack_alignment);
    const memory = try allocator.alignedAlloc(u8, stack_alignment, size);
    errdefer allocator.free(memory);

    const end = if (builtin.os.tag == .windows)
        memory.len
    else
        memory.len - red_zone_bytes;

    const stack_top: usize = @intFromPtr(memory.ptr + end);

    const context: Context = .{
        .registers = Registers.initDefault(0, .{
            .program_counter = @intFromPtr(func),
            .argument = @intFromPtr(arg),
            .stack_pointer = std.mem.alignBackward(usize, stack_top, stack_alignment) - 8,
        }),
        .simd = if (builtin.os.tag == .windows) SimdRegisters.initFill(0) else {},
    };

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
        .context = .{
            .registers = Registers.initFill(0),
            .simd = if (builtin.os.tag == .windows) SimdRegisters.initFill(0) else {},
        },
        .stack_memory = null,
        .allocator = null,
    };
}

pub extern fn switchTo(from: *Fiber, to: *Fiber) callconv(.C) void;
comptime {
    switch (builtin.os.tag) {
        .windows => switch (builtin.cpu.arch) {
            // from -> rcx
            // to -> rdx
            .x86_64 => asm (
                \\.global switchTo
                \\
                \\switchTo:
                \\
                // store non-volatile registers into "from"
                \\movq %rbx, 0*8(%rcx)
                \\movq %rbp, 1*8(%rcx)
                \\movq %rdi, 2*8(%rcx)
                \\movq %rsi, 3*8(%rcx)
                \\movq %r12, 4*8(%rcx)
                \\movq %r13, 5*8(%rcx)
                \\movq %r14, 6*8(%rcx)
                \\movq %r15, 7*8(%rcx)
                \\movups %xmm6, 8*11+16*0(%rcx)
                \\movups %xmm7, 8*11+16*1(%rcx)
                \\movups %xmm8, 8*11+16*2(%rcx)
                \\movups %xmm9, 8*11+16*3(%rcx)
                \\movups %xmm10, 8*11+16*4(%rcx)
                \\movups %xmm11, 8*11+16*5(%rcx)
                \\movups %xmm12, 8*11+16*6(%rcx)
                \\movups %xmm13, 8*11+16*7(%rcx)
                \\movups %xmm14, 8*11+16*8(%rcx)
                \\movups %xmm15, 8*11+16*9(%rcx)
                \\
                // store return address
                \\movq 0*8(%rsp), %r8
                \\movq %r8, 10*8(%rcx)
                \\
                // store stack pointer (skip return address)
                \\leaq 1*8(%rsp), %r8
                \\movq %r8, 9*8(%rcx)
                \\
                // load "to" registers
                \\movq 0*8(%rdx), %rbx
                \\movq 1*8(%rdx), %rbp
                \\movq 2*8(%rdx), %rdi
                \\movq 3*8(%rdx), %rsi
                \\movq 4*8(%rdx), %r12
                \\movq 5*8(%rdx), %r13
                \\movq 6*8(%rdx), %r14
                \\movq 7*8(%rdx), %r15
                \\movq 8*8(%rdx), %rcx
                \\movq 9*8(%rdx), %rsp
                \\movups 8*11+16*0(%rdx), %xmm6
                \\movups 8*11+16*1(%rdx), %xmm7
                \\movups 8*11+16*2(%rdx), %xmm8
                \\movups 8*11+16*3(%rdx), %xmm9
                \\movups 8*11+16*4(%rdx), %xmm10
                \\movups 8*11+16*5(%rdx), %xmm11
                \\movups 8*11+16*6(%rdx), %xmm12
                \\movups 8*11+16*7(%rdx), %xmm13
                \\movups 8*11+16*8(%rdx), %xmm14
                \\movups 8*11+16*9(%rdx), %xmm15
                \\
                // jmp to instruction
                \\movq 10*8(%rdx), %r8
                \\pushq %r8
                \\xorq %rax, %rax
                \\ret
            ),
            else => architectureUnsupported(),
        },
        .linux => switch (builtin.cpu.arch) {
            // from -> rdi
            // to -> rsi
            .x86_64 => asm (
                \\.global switchTo
                \\
                \\switchTo:
                \\
                // store non-volatile registers into "from"
                \\movq %rbx, 0*8(%rdi)
                \\movq %rbp, 1*8(%rdi)
                \\movq %r12, 2*8(%rdi)
                \\movq %r13, 3*8(%rdi)
                \\movq %r14, 4*8(%rdi)
                \\movq %r15, 5*8(%rdi)
                \\
                // store return address
                \\movq 0*8(%rsp), %r8
                \\movq %r8, 8*8(%rdi)
                \\
                // store stack pointer (skip return address)
                \\leaq 1*8(%rsp), %r8
                \\movq %r8, 7*8(%rdi)
                \\
                // load "to" registers
                \\movq 0*8(%rdi), %rbx
                \\movq 1*8(%rdi), %rbp
                \\movq 2*8(%rdi), %r12
                \\movq 3*8(%rdi), %r13
                \\movq 4*8(%rdi), %r14
                \\movq 5*8(%rdi), %r15
                \\movq 6*8(%rsi), %rdi
                \\movq 7*8(%rsi), %rsp
                \\
                // jmp to instruction
                \\movq 8*8(%rsi), %r8
                \\pushq %r8
                \\xorq %rax, %rax
                \\ret
            ),
            else => architectureUnsupported(),
        },
        else => osUnsupported(),
    }
}

fn osUnsupported() void {
    @compileError("fibers not implemented for os " ++ @tagName(builtin.os.tag));
}

fn architectureUnsupported() void {
    @compileError("fibers not implemented for architecture " ++
        @tagName(builtin.cpu.arch) ++ " on os " ++ @tagName(builtin.os.tag));
}
