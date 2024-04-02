const std = @import("std");
const vk = @import("vulkan-zig");
const dispatch = @import("dispatch.zig");
const math = @import("../math.zig");

const assert = std.debug.assert;

const vkd = dispatch.vkd;

pub const LayoutBuilder = struct {
    bindings: std.ArrayList(vk.DescriptorSetLayoutBinding),

    pub fn init(allocator: std.mem.Allocator) LayoutBuilder {
        return .{
            .bindings = std.ArrayList(vk.DescriptorSetLayoutBinding).init(allocator),
        };
    }

    pub fn deinit(self: LayoutBuilder) void {
        self.bindings.deinit();
    }

    pub fn clear(self: *LayoutBuilder) void {
        self.bindings.clearRetainingCapacity();
    }

    pub fn addBinding(self: *LayoutBuilder, binding: u32, descriptor_type: vk.DescriptorType) !void {
        const new_binding: vk.DescriptorSetLayoutBinding = .{
            .binding = binding,
            .descriptor_type = descriptor_type,
            .descriptor_count = 1,
            .stage_flags = .{},
        };
        try self.bindings.append(new_binding);
    }

    pub fn build(self: *const LayoutBuilder, device: vk.Device, shader_stages: vk.ShaderStageFlags) !vk.DescriptorSetLayout {
        for (self.bindings.items) |*binding| {
            binding.stage_flags = shader_stages;
        }

        const create_info: vk.DescriptorSetLayoutCreateInfo = .{
            .binding_count = @intCast(self.bindings.items.len),
            .p_bindings = self.bindings.items.ptr,
        };

        return vkd().createDescriptorSetLayout(device, &create_info, null);
    }
};

pub const Allocator = struct {
    pub const PoolSizeRatio = struct {
        type: vk.DescriptorType,
        ratio: f32,
    };

    pool: vk.DescriptorPool,

    pub fn init(
        allocator: std.mem.Allocator,
        device: vk.Device,
        max_sets: u32,
        pool_ratios: []const PoolSizeRatio,
    ) !Allocator {
        assert(device != .null_handle);

        const pool_sizes = try allocator.alloc(vk.DescriptorPoolSize, pool_ratios.len);

        for (0..pool_ratios.len) |i| {
            const count = math.scale(u32, max_sets, pool_ratios[i].ratio);
            pool_sizes[i] = .{ .type = pool_ratios[i].type, .descriptor_count = count };
        }

        const pool_info: vk.DescriptorPoolCreateInfo = .{
            .max_sets = max_sets,
            .pool_size_count = @intCast(pool_sizes.len),
            .p_pool_sizes = pool_sizes.ptr,
        };

        const pool = try vkd().createDescriptorPool(device, &pool_info, null);

        return .{ .pool = pool };
    }

    pub fn clearDescriptors(self: *Allocator, device: vk.Device) !void {
        assert(device != .null_handle);
        assert(self.pool != .null_handle);

        try vkd().resetDescriptorPool(device, self.pool, .{});
    }

    pub fn alloc(self: *const Allocator, device: vk.Device, layout: vk.DescriptorSetLayout) !vk.DescriptorSet {
        assert(device != .null_handle);
        assert(self.pool != .null_handle);
        assert(layout != .null_handle);

        const alloc_info: vk.DescriptorSetAllocateInfo = .{
            .descriptor_pool = self.pool,
            .descriptor_set_count = 1,
            .p_set_layouts = @ptrCast(&layout),
        };

        var descriptor_set: vk.DescriptorSet = undefined;
        try vkd().allocateDescriptorSets(device, &alloc_info, @ptrCast(&descriptor_set));
        return descriptor_set;
    }
};

pub const AllocatorGrowable = struct {
    pub const PoolSizeRatio = struct {
        type: vk.DescriptorType,
        ratio: f32,
    };

    allocator: std.mem.Allocator,
    ratios: []const PoolSizeRatio,
    full_pools: std.ArrayList(vk.DescriptorPool),
    ready_pools: std.ArrayList(vk.DescriptorPool),
    sets_per_pool: u32,

    pub fn init(
        allocator: std.mem.Allocator,
        device: vk.Device,
        initial_sets: u32,
        pool_ratios: []const PoolSizeRatio,
    ) !AllocatorGrowable {
        const ratios = try allocator.dupe(PoolSizeRatio, pool_ratios);
        errdefer allocator.free(ratios);

        var self: AllocatorGrowable = .{
            .allocator = allocator,
            .ratios = ratios,
            .full_pools = std.ArrayList(vk.DescriptorPool).init(allocator),
            .ready_pools = std.ArrayList(vk.DescriptorPool).init(allocator),
            .sets_per_pool = initial_sets,
        };
        errdefer self.deinit(device);

        const pool = try self.createPool(device);
        try self.ready_pools.append(pool);

        self.sets_per_pool = math.scale(u32, self.sets_per_pool, 1.5);

        return self;
    }

    pub fn deinit(self: *AllocatorGrowable, device: vk.Device) void {
        self.allocator.free(self.ratios);
        for (self.ready_pools.items) |pool| {
            vkd().destroyDescriptorPool(device, pool, null);
        }
        for (self.full_pools.items) |pool| {
            vkd().destroyDescriptorPool(device, pool, null);
        }
        self.full_pools.deinit();
        self.ready_pools.deinit();
    }

    pub fn clearPools(self: *AllocatorGrowable, device: vk.Device) !void {
        for (self.ready_pools.items) |pool| {
            try vkd().resetDescriptorPool(device, pool, .{});
        }
        for (self.full_pools.items) |pool| {
            try vkd().resetDescriptorPool(device, pool, .{});
            try self.ready_pools.append(pool);
        }
        self.full_pools.clearRetainingCapacity();
    }

    pub fn alloc(self: *AllocatorGrowable, device: vk.Device, layout: vk.DescriptorSetLayout) !vk.DescriptorSet {
        var pool = try self.getPool(device);

        var alloc_info: vk.DescriptorSetAllocateInfo = .{
            .descriptor_pool = pool,
            .descriptor_set_count = 1,
            .p_set_layouts = @ptrCast(&layout),
        };

        var descriptor_set: vk.DescriptorSet = undefined;
        vkd().allocateDescriptorSets(device, &alloc_info, @ptrCast(&descriptor_set)) catch |err| {
            if (err == error.OutOfPoolMemory or err == error.FragmentedPool) {
                try self.full_pools.append(pool);
                pool = try self.getPool(device);

                alloc_info.descriptor_pool = pool;

                try vkd().allocateDescriptorSets(device, &alloc_info, @ptrCast(&descriptor_set));
            } else {
                return err;
            }
        };

        try self.ready_pools.append(pool);

        return descriptor_set;
    }

    fn getPool(self: *AllocatorGrowable, device: vk.Device) !vk.DescriptorPool {
        if (self.ready_pools.items.len > 0) {
            return self.ready_pools.pop();
        } else {
            const pool = try self.createPool(device);
            self.sets_per_pool = math.scale(u32, self.sets_per_pool, 1.5);
            if (self.sets_per_pool > 4092)
                self.sets_per_pool = 4092;
            return pool;
        }
    }

    fn createPool(self: *AllocatorGrowable, device: vk.Device) !vk.DescriptorPool {
        const pool_sizes = try self.allocator.alloc(vk.DescriptorPoolSize, self.ratios.len);
        defer self.allocator.free(pool_sizes);

        for (0..pool_sizes.len) |i| {
            const count: f32 = @as(f32, @floatFromInt(self.sets_per_pool)) * self.ratios[i].ratio;
            pool_sizes[i] = .{ .type = self.ratios[i].type, .descriptor_count = @intFromFloat(count) };
        }

        const pool_info: vk.DescriptorPoolCreateInfo = .{
            .max_sets = self.sets_per_pool,
            .pool_size_count = @intCast(pool_sizes.len),
            .p_pool_sizes = pool_sizes.ptr,
        };

        return vkd().createDescriptorPool(device, &pool_info, null);
    }
};

pub const Writer = struct {
    const ImageInfoList = std.DoublyLinkedList(vk.DescriptorImageInfo);
    const BufferInfoList = std.DoublyLinkedList(vk.DescriptorBufferInfo);
    allocator: std.mem.Allocator,
    image_infos: ImageInfoList,
    buffer_infos: BufferInfoList,
    writes: std.ArrayList(vk.WriteDescriptorSet),

    pub fn init(allocator: std.mem.Allocator) Writer {
        return .{
            .allocator = allocator,
            .image_infos = ImageInfoList{},
            .buffer_infos = BufferInfoList{},
            .writes = std.ArrayList(vk.WriteDescriptorSet).init(allocator),
        };
    }

    pub fn deinit(self: *Writer) void {
        self.clear();
        self.writes.deinit();
    }

    pub fn writeImage(
        self: *Writer,
        binding: u32,
        image_view: vk.ImageView,
        layout: vk.ImageLayout,
        sampler: vk.Sampler,
        descriptor_type: vk.DescriptorType,
    ) !void {
        switch (descriptor_type) {
            .sampler => std.debug.assert(sampler != .null_handle and image_view == .null_handle and layout == .undefined),
            .combined_image_sampler => std.debug.assert(sampler != .null_handle and image_view != .null_handle and layout != .undefined),
            .sampled_image => std.debug.assert(image_view != .null_handle and layout != .undefined and sampler == .null_handle),
            .storage_image => std.debug.assert(image_view != .null_handle and layout != .undefined and sampler == .null_handle),
            else => @panic("invalid type"),
        }

        const node = try self.allocator.create(ImageInfoList.Node);
        errdefer self.allocator.destroy(node);

        self.image_infos.append(node);

        node.data = .{
            .image_view = image_view,
            .sampler = sampler,
            .image_layout = layout,
        };

        const write: vk.WriteDescriptorSet = .{
            .dst_binding = binding,
            .dst_set = .null_handle,
            .dst_array_element = 0,
            .descriptor_count = 1,
            .descriptor_type = descriptor_type,
            .p_image_info = @ptrCast(&node.data),
            .p_buffer_info = undefined,
            .p_texel_buffer_view = undefined,
        };
        try self.writes.append(write);
    }

    pub fn writeBuffer(
        self: *Writer,
        binding: u32,
        buffer: vk.Buffer,
        size: vk.DeviceSize,
        offset: vk.DeviceSize,
        descriptor_type: vk.DescriptorType,
    ) !void {
        std.debug.assert(descriptor_type == .uniform_buffer or
            descriptor_type == .storage_buffer or
            descriptor_type == .uniform_buffer_dynamic or
            descriptor_type == .storage_buffer_dynamic);

        const node = try self.allocator.create(BufferInfoList.Node);
        errdefer self.allocator.destroy(node);

        self.buffer_infos.append(node);

        node.data = .{
            .buffer = buffer,
            .range = size,
            .offset = offset,
        };

        const write: vk.WriteDescriptorSet = .{
            .dst_binding = binding,
            .dst_set = .null_handle,
            .dst_array_element = 0,
            .descriptor_count = 1,
            .descriptor_type = descriptor_type,
            .p_image_info = undefined,
            .p_buffer_info = @ptrCast(&node.data),
            .p_texel_buffer_view = undefined,
        };
        try self.writes.append(write);
    }

    pub fn clear(self: *Writer) void {
        while (self.image_infos.pop()) |node| {
            self.allocator.destroy(node);
        }
        while (self.buffer_infos.pop()) |node| {
            self.allocator.destroy(node);
        }
        self.writes.clearRetainingCapacity();
    }

    pub fn updateSet(self: *Writer, device: vk.Device, set: vk.DescriptorSet) void {
        for (self.writes.items) |*write| {
            write.dst_set = set;
        }

        vkd().updateDescriptorSets(device, @intCast(self.writes.items.len), self.writes.items.ptr, 0, null);
    }
};
