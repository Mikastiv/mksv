const std = @import("std");
const builtin = @import("builtin");
const vk = @import("vulkan-zig");
const build_options = @import("build_options");
const dispatch = @import("dispatch.zig");
const Instance = @This();
const root = @import("root");

const log = @import("log.zig").vk_kickstart_log;
const vk_log = @import("log.zig").vulkan_log;

const vkb = dispatch.vkb;
const vki = dispatch.vki;

const BaseDispatch = dispatch.BaseDispatch;
const InstanceDispatch = dispatch.InstanceDispatch;

const validation_layers: []const [*:0]const u8 = &.{"VK_LAYER_KHRONOS_validation"};

const vk_options = if (@hasDecl(root, "vk_options")) root.vk_options else struct {};
const instance_override = if (@hasDecl(vk_options, "instance_override")) vk_options.instance_override else struct {};

/// Max number of available instance extensions.
///
/// Can be overriden in root.
const max_extensions = if (@hasDecl(instance_override, "max_extensions"))
    instance_override.max_extensions
else
    64;

/// Max number of available instance layers.
///
/// Can be overriden in root.
const max_layers = if (@hasDecl(instance_override, "max_layers"))
    instance_override.max_layers
else
    64;

const AvailableExtensionsArray = std.BoundedArray(vk.ExtensionProperties, max_extensions);
const AvailableLayersArray = std.BoundedArray(vk.LayerProperties, max_layers);
const RequiredExtensionsArray = std.BoundedArray([*:0]const u8, max_extensions);
const RequiredLayersArray = std.BoundedArray([*:0]const u8, max_layers);

handle: vk.Instance,
allocation_callbacks: ?*const vk.AllocationCallbacks,
debug_messenger: ?vk.DebugUtilsMessengerEXT,
api_version: u32,

const default_message_severity: vk.DebugUtilsMessageSeverityFlagsEXT = .{
    .warning_bit_ext = true,
    .error_bit_ext = true,
};
const default_message_type: vk.DebugUtilsMessageTypeFlagsEXT = .{
    .general_bit_ext = true,
    .validation_bit_ext = true,
    .performance_bit_ext = true,
};

pub const CreateOptions = struct {
    /// Application name.
    app_name: [*:0]const u8 = "",
    /// Application version.
    app_version: u32 = 0,
    /// Engine name.
    engine_name: [*:0]const u8 = "",
    /// Engine version.
    engine_version: u32 = 0,
    /// Required Vulkan version (minimum 1.1).
    required_api_version: u32 = vk.API_VERSION_1_1,
    /// Array of required extensions to enable.
    /// Note: VK_KHR_surface and the platform specific surface extension are automatically enabled.
    required_extensions: []const [*:0]const u8 = &.{},
    /// Array of required layers to enable.
    required_layers: []const [*:0]const u8 = &.{},
    /// Vulkan allocation callbacks.
    allocation_callbacks: ?*const vk.AllocationCallbacks = null,
    /// Custom debug callback function (or use default).
    debug_callback: vk.PfnDebugUtilsMessengerCallbackEXT = defaultDebugMessageCallback,
    /// Debug message severity filter.
    debug_message_severity: vk.DebugUtilsMessageSeverityFlagsEXT = default_message_severity,
    /// Debug message type filter.
    debug_message_type: vk.DebugUtilsMessageTypeFlagsEXT = default_message_type,
    /// Debug user data pointer.
    debug_user_data: ?*anyopaque = null,
    /// pNext chain.
    p_next_chain: ?*anyopaque = null,
};

const Error = error{
    Overflow,
    CommandLoadFailure,
    UnsupportedInstanceVersion,
    RequiredVersionNotAvailable,
    EnumerateExtensionsFailed,
    RequestedExtensionNotAvailable,
    EnumerateLayersFailed,
    RequestedLayerNotAvailable,
    ValidationLayersNotAvailable,
    DebugMessengerExtensionNotAvailable,
    SurfaceExtensionNotAvailable,
    WindowingExtensionNotAvailable,
};

pub const CreateError = Error ||
    BaseDispatch.EnumerateInstanceExtensionPropertiesError ||
    BaseDispatch.EnumerateInstanceLayerPropertiesError ||
    BaseDispatch.CreateInstanceError ||
    InstanceDispatch.CreateDebugUtilsMessengerEXTError;

pub fn create(
    loader: anytype,
    options: CreateOptions,
) CreateError!Instance {
    try dispatch.initBaseDispatch(loader);

    const api_version = try getAppropriateApiVersion(options.required_api_version);
    if (api_version < vk.API_VERSION_1_1) return error.UnsupportedInstanceVersion;

    const app_info = vk.ApplicationInfo{
        .p_application_name = options.app_name,
        .application_version = options.app_version,
        .p_engine_name = options.engine_name,
        .engine_version = options.engine_version,
        .api_version = api_version,
    };

    const available_extensions = try getAvailableExtensions();
    const available_layers = try getAvailableLayers();
    const required_extensions = try getRequiredExtensions(options.required_extensions, available_extensions.constSlice());
    const required_layers = try getRequiredLayers(options.required_layers, available_layers.constSlice());

    const p_next = if (build_options.vk_enable_validation) &vk.DebugUtilsMessengerCreateInfoEXT{
        .p_next = options.p_next_chain,
        .message_severity = options.debug_message_severity,
        .message_type = options.debug_message_type,
        .pfn_user_callback = options.debug_callback,
        .p_user_data = options.debug_user_data,
    } else options.p_next_chain;

    const portability_enumeration_support = isExtensionAvailable(
        available_extensions.constSlice(),
        vk.extension_info.khr_portability_enumeration.name,
    );

    const instance_info = vk.InstanceCreateInfo{
        .flags = if (portability_enumeration_support) .{ .enumerate_portability_bit_khr = true } else .{},
        .p_application_info = &app_info,
        .enabled_extension_count = @as(u32, @intCast(required_extensions.len)),
        .pp_enabled_extension_names = &required_extensions.buffer,
        .enabled_layer_count = @as(u32, @intCast(required_layers.len)),
        .pp_enabled_layer_names = &required_layers.buffer,
        .p_next = p_next,
    };

    const instance = try vkb().createInstance(&instance_info, options.allocation_callbacks);
    try dispatch.initInstanceDispatch(instance);
    errdefer vki().destroyInstance(instance, options.allocation_callbacks);

    const debug_messenger = try createDebugMessenger(instance, options);
    errdefer destroyDebugMessenger(instance, debug_messenger, options.allocation_callbacks);

    if (build_options.vk_verbose) {
        log.debug("----- instance creation -----", .{});

        log.debug("api version: {d}.{d}.{d}", .{
            vk.apiVersionMajor(api_version),
            vk.apiVersionMinor(api_version),
            vk.apiVersionPatch(api_version),
        });

        log.debug("validation layers: {s}", .{if (build_options.vk_enable_validation) "enabled" else "disabled"});

        log.debug("available extensions:", .{});
        for (available_extensions.constSlice()) |ext| {
            const ext_name: [*:0]const u8 = @ptrCast(&ext.extension_name);
            log.debug("- {s}", .{ext_name});
        }

        log.debug("available layers:", .{});
        for (available_layers.constSlice()) |layer| {
            const layer_name: [*:0]const u8 = @ptrCast(&layer.layer_name);
            log.debug("- {s}", .{layer_name});
        }

        log.debug("enabled extensions:", .{});
        for (required_extensions.constSlice()) |ext| {
            log.debug("- {s}", .{ext});
        }

        log.debug("enabled layers:", .{});
        for (required_layers.constSlice()) |layer| {
            log.debug("- {s}", .{layer});
        }
    }

    return .{
        .handle = instance,
        .allocation_callbacks = options.allocation_callbacks,
        .debug_messenger = debug_messenger,
        .api_version = api_version,
    };
}

pub fn destroy(self: *const Instance) void {
    destroyDebugMessenger(self.handle, self.debug_messenger, self.allocation_callbacks);
    vki().destroyInstance(self.handle, self.allocation_callbacks);
}

fn defaultDebugMessageCallback(
    severity: vk.DebugUtilsMessageSeverityFlagsEXT,
    _: vk.DebugUtilsMessageTypeFlagsEXT,
    p_callback_data: ?*const vk.DebugUtilsMessengerCallbackDataEXT,
    _: ?*anyopaque,
) callconv(vk.vulkan_call_conv) vk.Bool32 {
    if (p_callback_data) |data| {
        const format = "{?s}";

        if (severity.error_bit_ext) {
            vk_log.err(format, .{data.p_message});
        } else if (severity.warning_bit_ext) {
            vk_log.warn(format, .{data.p_message});
        } else if (severity.info_bit_ext) {
            vk_log.info(format, .{data.p_message});
        } else {
            vk_log.debug(format, .{data.p_message});
        }
    }
    return vk.FALSE;
}

fn createDebugMessenger(instance: vk.Instance, options: CreateOptions) !?vk.DebugUtilsMessengerEXT {
    if (!build_options.vk_enable_validation) return null;

    const debug_info = vk.DebugUtilsMessengerCreateInfoEXT{
        .message_severity = options.debug_message_severity,
        .message_type = options.debug_message_type,
        .pfn_user_callback = options.debug_callback,
        .p_user_data = options.debug_user_data,
    };

    return try vki().createDebugUtilsMessengerEXT(instance, &debug_info, options.allocation_callbacks);
}

fn destroyDebugMessenger(
    instance: vk.Instance,
    debug_messenger: ?vk.DebugUtilsMessengerEXT,
    allocation_callbacks: ?*const vk.AllocationCallbacks,
) void {
    if (!build_options.vk_enable_validation) return;

    std.debug.assert(debug_messenger != null);
    vki().destroyDebugUtilsMessengerEXT(instance, debug_messenger.?, allocation_callbacks);
}

fn isExtensionAvailable(
    available_extensions: []const vk.ExtensionProperties,
    extension: [*:0]const u8,
) bool {
    for (available_extensions) |ext| {
        const name: [*:0]const u8 = @ptrCast(&ext.extension_name);
        if (std.mem.orderZ(u8, name, extension) == .eq) {
            return true;
        }
    }
    return false;
}

fn addExtension(
    available_extensions: []const vk.ExtensionProperties,
    new_extension: [*:0]const u8,
    buffer: *RequiredExtensionsArray,
) !bool {
    if (isExtensionAvailable(available_extensions, new_extension)) {
        try buffer.append(new_extension);
        return true;
    }
    return false;
}

fn getRequiredExtensions(
    config_extensions: []const [*:0]const u8,
    available_extensions: []const vk.ExtensionProperties,
) !RequiredExtensionsArray {
    var required_extensions = try RequiredExtensionsArray.init(0);
    std.debug.assert(required_extensions.buffer.len >= max_extensions);

    for (config_extensions) |ext| {
        if (!try addExtension(available_extensions, ext, &required_extensions)) {
            return error.RequestedExtensionNotAvailable;
        }
    }

    if (!try addExtension(available_extensions, vk.extension_info.khr_surface.name, &required_extensions)) {
        return error.SurfaceExtensionNotAvailable;
    }

    const windowing_extensions: []const [*:0]const u8 = switch (builtin.os.tag) {
        .windows => &.{vk.extension_info.khr_win_32_surface.name},
        .macos => &.{vk.extension_info.ext_metal_surface.name},
        .linux => &.{
            vk.extension_info.khr_xlib_surface,
            vk.extension_info.khr_xcb_surface,
            vk.extension_info.khr_wayland_surface,
        },
        else => @compileError("unsupported platform"),
    };

    var added_one = false;
    for (windowing_extensions) |ext| {
        added_one = try addExtension(available_extensions, ext, &required_extensions) or added_one;
    }

    if (!added_one) return error.WindowingExtensionNotAvailable;

    if (build_options.vk_enable_validation) {
        if (!try addExtension(available_extensions, vk.extension_info.ext_debug_utils.name, &required_extensions)) {
            return error.DebugMessengerExtensionNotAvailable;
        }
    }

    _ = addExtension(available_extensions, vk.extension_info.khr_portability_enumeration.name, &required_extensions) catch {};

    return required_extensions;
}

fn isLayerAvailable(
    available_layers: []const vk.LayerProperties,
    layer: [*:0]const u8,
) bool {
    for (available_layers) |l| {
        const name: [*:0]const u8 = @ptrCast(&l.layer_name);
        if (std.mem.orderZ(u8, name, layer) == .eq) {
            return true;
        }
    }
    return false;
}

fn addLayer(
    available_layers: []const vk.LayerProperties,
    new_layer: [*:0]const u8,
    buffer: *RequiredLayersArray,
) !bool {
    if (isLayerAvailable(available_layers, new_layer)) {
        try buffer.append(new_layer);
        return true;
    }
    return false;
}

fn getRequiredLayers(
    config_layers: []const [*:0]const u8,
    available_layers: []const vk.LayerProperties,
) !RequiredLayersArray {
    var required_layers = try RequiredLayersArray.init(0);
    std.debug.assert(required_layers.buffer.len >= max_layers);

    for (config_layers) |layer| {
        if (!try addLayer(available_layers, layer, &required_layers)) {
            return error.RequestedLayerNotAvailable;
        }
    }

    if (build_options.vk_enable_validation) {
        for (validation_layers) |layer| {
            if (!try addLayer(available_layers, layer, &required_layers)) {
                return error.ValidationLayersNotAvailable;
            }
        }
    }

    return required_layers;
}

fn getAvailableExtensions() !AvailableExtensionsArray {
    var extension_count: u32 = 0;
    var result = try vkb().enumerateInstanceExtensionProperties(null, &extension_count, null);
    if (result != .success) return error.EnumerateExtensionsFailed;

    var extensions = try AvailableExtensionsArray.init(extension_count);

    while (true) {
        result = try vkb().enumerateInstanceExtensionProperties(null, &extension_count, &extensions.buffer);
        if (result == .success) break;
    }

    return extensions;
}

fn getAvailableLayers() !AvailableLayersArray {
    var layer_count: u32 = 0;
    var result = try vkb().enumerateInstanceLayerProperties(&layer_count, null);
    if (result != .success) return error.EnumerateLayersFailed;

    var layers = try AvailableLayersArray.init(layer_count);

    while (true) {
        result = try vkb().enumerateInstanceLayerProperties(&layer_count, &layers.buffer);
        if (result == .success) break;
    }

    return layers;
}

fn getAppropriateApiVersion(required_version: u32) !u32 {
    const instance_version = try vkb().enumerateInstanceVersion();

    if (instance_version < required_version)
        return error.RequiredVersionNotAvailable;
    return instance_version;
}
