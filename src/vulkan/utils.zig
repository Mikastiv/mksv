const std = @import("std");
const vk = @import("vulkan-zig");
const dispatch = @import("dispatch.zig");
const vulkan = @import("../vulkan.zig");

const assert = std.debug.assert;

const vki = dispatch.vki;
const vkd = dispatch.vkd;

const HandleType = enum {
    image,
    image_view,
    fence,
    command_pool,
    memory,
    render_pass,
    pipeline_layout,
    pipeline,
    semaphore,
    buffer,
    descriptor_set_layout,
    descriptor_pool,
    sampler,
};

const DeletionEntry = struct {
    handle: usize,
    type: HandleType,
};

pub const DeletionQueue = struct {
    entries: std.ArrayList(DeletionEntry),

    pub fn init(allocator: std.mem.Allocator, initial_size: usize) !DeletionQueue {
        return .{
            .entries = try std.ArrayList(DeletionEntry).initCapacity(allocator, initial_size),
        };
    }

    pub fn append(self: *DeletionQueue, handle: anytype) !void {
        const T = @TypeOf(handle);
        const handle_type: HandleType = switch (T) {
            vk.Image => .image,
            vk.ImageView => .image_view,
            vk.Fence => .fence,
            vk.CommandPool => .command_pool,
            vk.DeviceMemory => .memory,
            vk.RenderPass => .render_pass,
            vk.PipelineLayout => .pipeline_layout,
            vk.Pipeline => .pipeline,
            vk.Semaphore => .semaphore,
            vk.Buffer => .buffer,
            vk.DescriptorSetLayout => .descriptor_set_layout,
            vk.DescriptorPool => .descriptor_pool,
            vk.Sampler => .sampler,
            else => @compileError("unsupported type: " ++ @typeName(T)),
        };
        const handle_raw: usize = @intFromEnum(handle);
        assert(handle_raw != 0);

        try self.entries.append(.{ .handle = handle_raw, .type = handle_type });
    }

    pub fn flush(self: *DeletionQueue, device: vk.Device) void {
        assert(device != .null_handle);

        var it = std.mem.reverseIterator(self.entries.items);
        while (it.next()) |entry| {
            switch (entry.type) {
                .image => vkd().destroyImage(device, @enumFromInt(entry.handle), null),
                .image_view => vkd().destroyImageView(device, @enumFromInt(entry.handle), null),
                .fence => vkd().destroyFence(device, @enumFromInt(entry.handle), null),
                .command_pool => vkd().destroyCommandPool(device, @enumFromInt(entry.handle), null),
                .memory => vkd().freeMemory(device, @enumFromInt(entry.handle), null),
                .render_pass => vkd().destroyRenderPass(device, @enumFromInt(entry.handle), null),
                .pipeline_layout => vkd().destroyPipelineLayout(device, @enumFromInt(entry.handle), null),
                .pipeline => vkd().destroyPipeline(device, @enumFromInt(entry.handle), null),
                .semaphore => vkd().destroySemaphore(device, @enumFromInt(entry.handle), null),
                .buffer => vkd().destroyBuffer(device, @enumFromInt(entry.handle), null),
                .descriptor_set_layout => vkd().destroyDescriptorSetLayout(device, @enumFromInt(entry.handle), null),
                .descriptor_pool => vkd().destroyDescriptorPool(device, @enumFromInt(entry.handle), null),
                .sampler => vkd().destroySampler(device, @enumFromInt(entry.handle), null),
            }
        }
        self.entries.clearRetainingCapacity();
    }
};

pub fn createShaderModule(device: vk.Device, bytecode: []align(4) const u8) !vk.ShaderModule {
    assert(device != .null_handle);

    const create_info = vk.ShaderModuleCreateInfo{
        .code_size = bytecode.len,
        .p_code = std.mem.bytesAsSlice(u32, bytecode).ptr,
    };

    return vkd().createShaderModule(device, &create_info, null);
}

pub fn destroyImageViews(device: vk.Device, image_views: []const vk.ImageView) void {
    assert(device != .null_handle);

    for (image_views) |view| {
        assert(view != .null_handle);
        vkd().destroyImageView(device, view, null);
    }
}

pub fn destroyImage(device: vk.Device, image: vulkan.AllocatedImage) void {
    vkd().destroyImageView(device, image.view, null);
    vkd().destroyImage(device, image.handle, null);
    vkd().freeMemory(device, image.memory, null);
}

pub fn allocateMemory(
    device: vk.Device,
    physical_device: vk.PhysicalDevice,
    requirements: vk.MemoryRequirements,
    property_flags: vk.MemoryPropertyFlags,
) !vulkan.AllocatedMemory {
    const memory_properties = vki().getPhysicalDeviceMemoryProperties(physical_device);

    const memory_type = findMemoryType(
        memory_properties,
        requirements.memory_type_bits,
        property_flags,
    ) orelse return error.NoSuitableMemoryType;

    const alloc_info: vk.MemoryAllocateInfo = .{
        .allocation_size = requirements.size,
        .memory_type_index = memory_type,
    };
    const memory = try vkd().allocateMemory(device, &alloc_info, null);

    return .{
        .handle = memory,
        .size = requirements.size,
        .alignment = requirements.alignment,
    };
}

pub fn findMemoryType(
    memory_properties: vk.PhysicalDeviceMemoryProperties,
    type_filter: u32,
    properties: vk.MemoryPropertyFlags,
) ?u32 {
    for (0..memory_properties.memory_type_count) |i| {
        const memory_type = memory_properties.memory_types[i];
        const property_flags = memory_type.property_flags;
        const mask = @as(u32, 1) << @intCast(i);
        if (type_filter & mask != 0 and property_flags.contains(properties)) {
            return @intCast(i);
        }
    }

    return null;
}
