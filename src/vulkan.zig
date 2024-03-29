pub const dispatch = @import("vulkan/dispatch.zig");
pub const Instance = @import("vulkan/Instance.zig");
pub const PhysicalDevice = @import("vulkan/PhysicalDevice.zig");
pub const Device = @import("vulkan/Device.zig");
pub const Swapchain = @import("vulkan/Swapchain.zig");
pub const utils = @import("vulkan/utils.zig");
const vk = @import("vulkan-zig");

pub const AllocatedImage = struct {
    handle: vk.Image,
    view: vk.ImageView,
    format: vk.Format,
    extent: vk.Extent3D,
    memory: vk.DeviceMemory,
};

pub const AllocatedBuffer = struct {
    handle: vk.Buffer,
    memory: vk.DeviceMemory,
    size: vk.DeviceSize,
};

pub const AllocatedMemory = struct {
    handle: vk.DeviceMemory,
    size: vk.DeviceSize,
    alignment: vk.DeviceSize,
};
