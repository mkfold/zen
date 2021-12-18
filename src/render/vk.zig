//! eden: vulkan rendering backend
//! abandon all hope, ye who render here
//!
//! TODO: fix depth buffer sync issue: additional subpass dependency should work
//! TODO: swap chain recreation on window resize/minimize/etc
//! TODO: main graphics pipeline init/deinit
//!       - fixed function ops
//!       - programmable ops
//!       - pipeline layout
//! TODO: render passes + commands for cascaded shadow maps
//! TODO: allocators for buffer memory, texture memory
//!       - suballocate from large VkDeviceMemory allocations
//! TODO: incorporate logging instead of using std.debug.warn
//! TODO: maybe put globals into a struct encapsulating vulkan state?

const std = @import("std");
const panic = std.debug.panic;
const log = std.log.scoped(.vk);
const glfw_log = std.log.scoped(.glfw);

const c_allocator = std.heap.c_allocator;

const c = @import("../c.zig");
const cc = @import("../cc.zig");

const pl = @import("vk/pipeline.zig");

fn debug_callback(
    severity: c.VkDebugUtilsMessageSeverityFlagBitsEXT,
    types: c.VkDebugUtilsMessageTypeFlagsEXT,
    callback_data: ?*const c.VkDebugUtilsMessengerCallbackDataEXT,
    userData: ?*c_void,
) callconv(.C) c.VkBool32 {
    switch (@enumToInt(severity)) {
        c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT => log.err("{s}", .{callback_data.?.pMessage}),
        c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT => log.warn("{s}", .{callback_data.?.pMessage}),
        else => log.info("{s}", .{callback_data.?.pMessage}),
    }
    return c.VK_FALSE;
}

fn create_debug_messenger(
    active_instance: c.VkInstance,
    p_create_info: *const c.VkDebugUtilsMessengerCreateInfoEXT,
    p_allocator: ?*const c.VkAllocationCallbacks,
    p_debug_messenger: *c.VkDebugUtilsMessengerEXT,
) c.VkResult {
    const func = @ptrCast(c.PFN_vkCreateDebugUtilsMessengerEXT, c.vkGetInstanceProcAddr(
        instance,
        "vkCreateDebugUtilsMessengerEXT",
    ) orelse return c.VkResult.VK_ERROR_EXTENSION_NOT_PRESENT);
    return func.?(active_instance, p_create_info, p_allocator, p_debug_messenger);
}

fn destroy_debug_messenger(
    active_instance: c.VkInstance,
    debug_msgr: c.VkDebugUtilsMessengerEXT,
    p_allocator: ?*const c.VkAllocationCallbacks,
) void {
    const func = @ptrCast(c.PFN_vkDestroyDebugUtilsMessengerEXT, c.vkGetInstanceProcAddr(
        instance,
        "vkDestroyDebugUtilsMessengerEXT",
    ) orelse unreachable);
    func.?(active_instance, debug_msgr, p_allocator);
}

pub fn check_success(result: c.VkResult) !void {
    switch (@enumToInt(result)) {
        c.VK_SUCCESS => {},
        else => {
            log.crit("{}", .{result});
            return error.VkCheckFailedError;
        },
    }
}

const GPU = struct {
    physical_device: c.VkPhysicalDevice,
    device_properties: c.VkPhysicalDeviceProperties,
    mem_properties: c.VkPhysicalDeviceMemoryProperties,
    queue_properties: []c.VkQueueFamilyProperties,
    extension_properties: []c.VkExtensionProperties,
    surface_capabilities: c.VkSurfaceCapabilitiesKHR,
    surface_formats: []c.VkSurfaceFormatKHR,
    present_modes: []c.VkPresentModeKHR,
};

const enable_validation_layers = std.debug.runtime_safety;
const validation_layers = [_][*:0]const u8{"VK_LAYER_KHRONOS_validation"};
const device_extensions = [_][*:0]const u8{c.VK_KHR_SWAPCHAIN_EXTENSION_NAME};

//! vulkan state
var available_gpus: []GPU = undefined;
var device_index: usize = undefined;

var instance: c.VkInstance = undefined;
var surface: c.VkSurfaceKHR = undefined;
var physical_device: c.VkPhysicalDevice = undefined;
var logical_device: c.VkDevice = undefined;

var graphics_queue_index: ?u32 = null;
var present_queue_index: ?u32 = null;
var graphics_queue: c.VkQueue = undefined;
var present_queue: c.VkQueue = undefined;

var swapchain: c.VkSwapchainKHR = undefined;
var swapchain_extent: c.VkExtent2D = undefined;
var swapchain_images: []c.VkImage = undefined;
var swapchain_image_views: []c.VkImageView = undefined;
var swapchain_image_format: c.VkFormat = undefined;
var swapchain_present_mode: c.VkPresentModeKHR = undefined;
var swapchain_framebuffers: []c.VkFramebuffer = undefined;
var current_framebuffer: u32 = 0;

var render_pass: c.VkRenderPass = undefined;
var static_pipeline_layout: c.VkPipelineLayout = undefined;
var static_pipeline: c.VkPipeline = undefined;
var command_pool: c.VkCommandPool = undefined;
var command_buffers: []c.VkCommandBuffer = undefined;
var pipeline_cache: c.VkPipelineCache = undefined;

var depth_format: c.VkFormat = undefined;
var depth_image: c.VkImage = undefined;
var depth_image_view: c.VkImageView = undefined;
var depth_image_memory: c.VkDeviceMemory = undefined;

var debug_messenger: c.VkDebugUtilsMessengerEXT = undefined;

var current_frame: u32 = 0;
const max_frames: u32 = 2;

var image_available_semaphores: [max_frames]c.VkSemaphore = undefined;
var render_finished_semaphores: [max_frames]c.VkSemaphore = undefined;
var in_flight_fences: [max_frames]c.VkFence = undefined;
var images_in_flight: [max_frames]c.VkFence = undefined;

/// initialize the vulkan renderer backend
/// TODO: validate that functions to query counts return non-zero positive values
pub fn init(window: *c.GLFWwindow) !void {
    log.info("Initializing backend...", .{});
    try init_instance();
    try check_success(c.glfwCreateWindowSurface(instance, window, null, &surface));
    try enumerate_devices();
    try choose_device();
    try init_logical_device();
    try init_swapchain();
    try init_depth_resources();
    try init_render_pass();
    try init_framebuffers();
    try init_sync_primitives();
    try init_command_pool();
    try init_command_buffers();
    try pl.init_static_pipeline(
        logical_device,
        swapchain_extent,
        render_pass,
        &static_pipeline_layout,
        &static_pipeline,
    );
}



/// destroy vulkan objects and instance
pub fn deinit() void {
    _ = c.vkDeviceWaitIdle(logical_device);

    c.vkDestroyPipeline(logical_device, static_pipeline, null);
    c.vkDestroyPipelineLayout(logical_device, static_pipeline_layout, null);

    c.vkDestroyImageView(logical_device, depth_image_view, null);
    c.vkDestroyImage(logical_device, depth_image, null);
    c.vkFreeMemory(logical_device, depth_image_memory, null);

    for (swapchain_framebuffers) |framebuffer| {
        c.vkDestroyFramebuffer(logical_device, framebuffer, null);
    }

    c.vkFreeCommandBuffers(
        logical_device,
        command_pool,
        @intCast(u32, command_buffers.len),
        command_buffers.ptr,
    );

    c.vkDestroyRenderPass(logical_device, render_pass, null);

    for (swapchain_image_views) |view| {
        c.vkDestroyImageView(logical_device, view, null);
    }

    c.vkDestroySwapchainKHR(logical_device, swapchain, null);

    var i: u32 = 0;
    while (i < max_frames) : (i += 1) {
        c.vkDestroySemaphore(logical_device, render_finished_semaphores[i], null);
        c.vkDestroySemaphore(logical_device, image_available_semaphores[i], null);
        c.vkDestroyFence(logical_device, in_flight_fences[i], null);
    }

    c.vkDestroyCommandPool(logical_device, command_pool, null);

    c.vkDestroyDevice(logical_device, null);

    if (enable_validation_layers) {
        destroy_debug_messenger(instance, debug_messenger, null);
    }

    c_allocator.free(available_gpus);
    c.vkDestroySurfaceKHR(instance, surface, null);
    c.vkDestroyInstance(instance, null);
}

fn check_validation_layer_support() !void {
    var layer_count: u32 = undefined;
    try check_success(c.vkEnumerateInstanceLayerProperties(&layer_count, null));

    var available_layers = try c_allocator.alloc(c.VkLayerProperties, layer_count);
    defer c_allocator.free(available_layers);

    try check_success(c.vkEnumerateInstanceLayerProperties(&layer_count, available_layers.ptr));

    for (validation_layers) |layer_name| {
        for (available_layers) |layer_properties| {
            // fuck it, pointer cast
            if (std.cstr.cmp(layer_name, @ptrCast([*:0]const u8, &layer_properties.layerName)) == 0) {
                break;
            }
        } else return error.VkValidationLayerUnsupported;
    }
}

fn get_required_extensions() ![][*:0]const u8 {
    var glfw_extension_count: u32 = 0;
    var glfw_extensions = @ptrCast(
        [*]const [*:0]const u8,
        c.glfwGetRequiredInstanceExtensions(&glfw_extension_count),
    );

    var extensions = std.ArrayList([*:0]const u8).init(c_allocator);
    errdefer extensions.deinit();

    if (glfw_extension_count != 0) {
        try extensions.appendSlice(glfw_extensions[0..glfw_extension_count]);
    }

    if (enable_validation_layers) {
        try extensions.append(c.VK_EXT_DEBUG_UTILS_EXTENSION_NAME);
    }

    return extensions.toOwnedSlice();
}

fn init_instance() !void {
    if (enable_validation_layers) {
        try check_validation_layer_support();
    }

    const app_info: c.VkApplicationInfo = .{
        .sType = c.VkStructureType.VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pNext = null,
        .pApplicationName = "",
        .applicationVersion = c.VK_MAKE_VERSION(0, 0, 0),
        .pEngineName = "end",
        .engineVersion = c.VK_MAKE_VERSION(0, 0, 1),
        .apiVersion = c.VK_API_VERSION_1_0,
    };

    const extensions = try get_required_extensions();
    defer c_allocator.free(extensions);

    // validation layer setup
    var debug_create_info: c.VkDebugUtilsMessengerCreateInfoEXT = undefined;
    if (enable_validation_layers) {
        debug_create_info = c.VkDebugUtilsMessengerCreateInfoEXT{
            .sType = c.VkStructureType.VK_STRUCTURE_TYPE_DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
            .pNext = null,
            .flags = 0,
            .pUserData = null,
            .messageSeverity = c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_VERBOSE_BIT_EXT |
                c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_INFO_BIT_EXT |
                c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_WARNING_BIT_EXT |
                c.VK_DEBUG_UTILS_MESSAGE_SEVERITY_ERROR_BIT_EXT,
            .messageType = c.VK_DEBUG_UTILS_MESSAGE_TYPE_GENERAL_BIT_EXT |
                c.VK_DEBUG_UTILS_MESSAGE_TYPE_VALIDATION_BIT_EXT |
                c.VK_DEBUG_UTILS_MESSAGE_TYPE_PERFORMANCE_BIT_EXT,
            .pfnUserCallback = debug_callback,
        };
    }

    // populate instance creation info struct
    const instance_create_info: c.VkInstanceCreateInfo = .{
        .sType = c.VkStructureType.VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pApplicationInfo = &app_info,
        .enabledExtensionCount = @intCast(u32, extensions.len),
        .ppEnabledExtensionNames = extensions.ptr,
        .enabledLayerCount = if (enable_validation_layers) @intCast(u32, validation_layers.len) else 0,
        .ppEnabledLayerNames = if (enable_validation_layers) &validation_layers else null,
        .pNext = if (enable_validation_layers) &debug_create_info else null,
        .flags = 0,
    };

    try check_success(c.vkCreateInstance(&instance_create_info, null, &instance));

    // set up debug messenger
    if (enable_validation_layers) {
        try check_success(create_debug_messenger(
            instance,
            &debug_create_info,
            null,
            &debug_messenger,
        ));
    }
}

/// TODO: free memory allocated here in deinit!
fn enumerate_devices() !void {
    var num_devices: u32 = 0;
    check_success(c.vkEnumeratePhysicalDevices(instance, &num_devices, null)) catch
        return error.VkDeviceEnumerationFailed;

    if (num_devices == 0) {
        return error.VkNoSupportedDeviceError;
    }

    var available_devices = try c_allocator.alloc(c.VkPhysicalDevice, num_devices);
    defer c_allocator.free(available_devices);

    available_gpus = try c_allocator.alloc(GPU, num_devices);
    errdefer c_allocator.free(available_gpus);

    try check_success(c.vkEnumeratePhysicalDevices(instance, &num_devices, available_devices.ptr));

    for (available_devices) |device, i| {
        const candidate = &available_gpus[i];
        candidate.*.physical_device = device;
        c.vkGetPhysicalDeviceProperties(device, &candidate.*.device_properties);
        c.vkGetPhysicalDeviceMemoryProperties(device, &candidate.*.mem_properties);
        try check_success(c.vkGetPhysicalDeviceSurfaceCapabilitiesKHR(
            device,
            surface,
            &candidate.*.surface_capabilities,
        ));

        {
            var num_queues: u32 = undefined;
            c.vkGetPhysicalDeviceQueueFamilyProperties(device, &num_queues, null);
            if (num_queues == 0) continue;

            candidate.*.queue_properties = try c_allocator.alloc(c.VkQueueFamilyProperties, num_queues);
            errdefer c_allocator.free(candidate.*.queue_properties);

            c.vkGetPhysicalDeviceQueueFamilyProperties(device, &num_queues, candidate.*.queue_properties.ptr);
        }

        {
            var num_extension_properties: u32 = undefined;
            try check_success(c.vkEnumerateDeviceExtensionProperties(device, null, &num_extension_properties, null));
            if (num_extension_properties == 0) continue;

            candidate.*.extension_properties = try c_allocator.alloc(c.VkExtensionProperties, num_extension_properties);
            errdefer c_allocator.free(candidate.*.extension_properties);

            try check_success(c.vkEnumerateDeviceExtensionProperties(
                device,
                null,
                &num_extension_properties,
                candidate.*.extension_properties.ptr,
            ));
        }

        {
            var num_surface_formats: u32 = undefined;
            try check_success(c.vkGetPhysicalDeviceSurfaceFormatsKHR(device, surface, &num_surface_formats, null));
            if (num_surface_formats == 0) continue;

            candidate.*.surface_formats = try c_allocator.alloc(c.VkSurfaceFormatKHR, num_surface_formats);
            errdefer c_allocator.free(candidate.*.extension_properties);

            try check_success(c.vkGetPhysicalDeviceSurfaceFormatsKHR(
                device,
                surface,
                &num_surface_formats,
                candidate.*.surface_formats.ptr,
            ));
        }

        {
            var num_present_modes: u32 = undefined;
            try check_success(c.vkGetPhysicalDeviceSurfacePresentModesKHR(device, surface, &num_present_modes, null));
            if (num_present_modes == 0) continue;

            candidate.*.present_modes = try c_allocator.alloc(c.VkPresentModeKHR, num_present_modes);
            errdefer c_allocator.free(candidate.*.present_modes);

            try check_success(c.vkGetPhysicalDeviceSurfacePresentModesKHR(
                device,
                surface,
                &num_present_modes,
                candidate.*.present_modes.ptr,
            ));
        }
    }
    // device enumeration complete
}

/// device selection
fn choose_device() !void {
    for (available_gpus) |candidate, i| {
        // ensure that device supports requested extensions
        const supported = try is_device_suitable(candidate);
        if (!supported) continue;

        var graphics_family: ?u32 = null;
        var present_family: ?u32 = null;

        // find appropriate queue families
        for (candidate.queue_properties) |queue_family, j| {
            if ((@bitCast(c_int, queue_family.queueFlags) & c.VK_QUEUE_GRAPHICS_BIT) != 0) {
                graphics_family = @intCast(u32, j);
            }

            var present_support: c.VkBool32 = c.VK_FALSE;
            try check_success(c.vkGetPhysicalDeviceSurfaceSupportKHR(
                candidate.physical_device,
                @intCast(u32, j),
                surface,
                &present_support,
            ));

            if (present_support == c.VK_TRUE) {
                present_family = @intCast(u32, j);
            }

            if (graphics_family != null and present_family != null) break;
        } else continue;

        physical_device = candidate.physical_device;
        graphics_queue_index = graphics_family;
        present_queue_index = present_family;
        device_index = i;
        break;
    } else return error.VkNoSupportedDevice;
}

/// logical device creation
fn init_logical_device() !void {
    // setup queue info structs, set device features, create device, and retrieve device queues
    const priority: f32 = 1.0;
    const queue_list = [_]c.VkDeviceQueueCreateInfo{
        .{
            .sType = c.VkStructureType.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .queueFamilyIndex = graphics_queue_index.?,
            .queueCount = 1,
            .pQueuePriorities = &priority,
        },
        .{
            .sType = c.VkStructureType.VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .queueFamilyIndex = present_queue_index.?,
            .queueCount = 1,
            .pQueuePriorities = &priority,
        },
    };

    const unique_queues: u32 = if (graphics_queue_index.? != present_queue_index.?) 2 else 1;

    var device_features: c.VkPhysicalDeviceFeatures = std.mem.zeroes(c.VkPhysicalDeviceFeatures);
    device_features.textureCompressionBC = c.VK_TRUE;
    // TODO: add other device features as needed (depth clamping, etc.)

    const device_create_info = c.VkDeviceCreateInfo{
        .sType = c.VkStructureType.VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .queueCreateInfoCount = unique_queues,
        .pQueueCreateInfos = &queue_list,
        .enabledExtensionCount = @intCast(u32, device_extensions.len),
        .ppEnabledExtensionNames = &device_extensions,
        .enabledLayerCount = if (enable_validation_layers) @intCast(u32, validation_layers.len) else 0,
        .ppEnabledLayerNames = if (enable_validation_layers) &validation_layers else null,
        .pEnabledFeatures = &device_features,
    };

    // create the device
    try check_success(c.vkCreateDevice(physical_device, &device_create_info, null, &logical_device));

    c.vkGetDeviceQueue(logical_device, graphics_queue_index.?, 0, &graphics_queue);
    c.vkGetDeviceQueue(logical_device, present_queue_index.?, 0, &present_queue);
    // logical device creation complete
}

/// swap chain creation
fn init_swapchain() !void {
    const gpu = available_gpus[device_index];
    const surface_format = for (gpu.surface_formats) |fmt| {
        if (fmt.format == c.VkFormat.VK_FORMAT_B8G8R8A8_SRGB and
            fmt.colorSpace == c.VkColorSpaceKHR.VK_COLOR_SPACE_SRGB_NONLINEAR_KHR)
        {
            break fmt;
        }
    } else gpu.surface_formats[0];

    const present_mode = for (gpu.present_modes) |mode| {
        if (mode == c.VkPresentModeKHR.VK_PRESENT_MODE_MAILBOX_KHR) {
            break mode;
        }
    } else c.VkPresentModeKHR.VK_PRESENT_MODE_FIFO_KHR;

    const extent = if (gpu.surface_capabilities.currentExtent.width == -1)
        .{ .width = 100, .height = 100 }
    else
        gpu.surface_capabilities.currentExtent;

    const image_count = cc.minimum(
        u32,
        gpu.surface_capabilities.minImageCount + 1,
        gpu.surface_capabilities.maxImageCount,
    );
    var swapchain_info = std.mem.zeroes(c.VkSwapchainCreateInfoKHR);
    swapchain_info.sType = c.VkStructureType.VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR;
    swapchain_info.surface = surface;
    swapchain_info.minImageCount = image_count;
    swapchain_info.imageFormat = surface_format.format;
    swapchain_info.imageColorSpace = surface_format.colorSpace;
    swapchain_info.imageExtent = extent;
    swapchain_info.imageArrayLayers = 1;
    swapchain_info.imageUsage = c.VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT | c.VK_IMAGE_USAGE_TRANSFER_SRC_BIT;
    swapchain_info.preTransform = c.VkSurfaceTransformFlagBitsKHR.VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR;
    swapchain_info.compositeAlpha = c.VkCompositeAlphaFlagBitsKHR.VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
    swapchain_info.presentMode = present_mode;
    swapchain_info.clipped = c.VK_TRUE;

    // embed queue info
    if (graphics_queue_index.? != present_queue_index.?) {
        const queue_indices = [_]u32{ graphics_queue_index.?, present_queue_index.? };
        swapchain_info.imageSharingMode = c.VkSharingMode.VK_SHARING_MODE_CONCURRENT;
        swapchain_info.queueFamilyIndexCount = 2;
        swapchain_info.pQueueFamilyIndices = &queue_indices;
    } else {
        swapchain_info.imageSharingMode = c.VkSharingMode.VK_SHARING_MODE_EXCLUSIVE;
    }

    try check_success(c.vkCreateSwapchainKHR(logical_device, &swapchain_info, null, &swapchain));

    swapchain_present_mode = present_mode;

    // get swapchain images
    var num_swapchain_images: u32 = undefined;
    try check_success(c.vkGetSwapchainImagesKHR(logical_device, swapchain, &num_swapchain_images, null));
    if (num_swapchain_images == 0) return error.VkNoSwapchainImages;

    swapchain_images = try c_allocator.alloc(c.VkImage, num_swapchain_images);
    errdefer c_allocator.free(swapchain_images);

    try check_success(c.vkGetSwapchainImagesKHR(
        logical_device,
        swapchain,
        &num_swapchain_images,
        swapchain_images.ptr,
    ));
    // swapchain creation complete

    swapchain_image_format = surface_format.format;
    swapchain_extent = extent;

    // image view creation
    swapchain_image_views = try c_allocator.alloc(c.VkImageView, num_swapchain_images);
    errdefer c_allocator.free(swapchain_image_views);
    for (swapchain_images) |img, i| {
        var image_view_info = std.mem.zeroes(c.VkImageViewCreateInfo);
        image_view_info.sType = c.VkStructureType.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
        image_view_info.image = img;
        image_view_info.viewType = c.VkImageViewType.VK_IMAGE_VIEW_TYPE_2D;
        image_view_info.format = surface_format.format;

        image_view_info.components.r = c.VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY;
        image_view_info.components.g = c.VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY;
        image_view_info.components.b = c.VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY;
        image_view_info.components.a = c.VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY;

        image_view_info.subresourceRange.aspectMask = c.VK_IMAGE_ASPECT_COLOR_BIT;
        image_view_info.subresourceRange.baseMipLevel = 0;
        image_view_info.subresourceRange.levelCount = 1;
        image_view_info.subresourceRange.baseArrayLayer = 0;
        image_view_info.subresourceRange.layerCount = 1;

        try check_success(c.vkCreateImageView(logical_device, &image_view_info, null, &swapchain_image_views[i]));
    }
    // image view creation complete
}

/// select a VkImage format which supports requested tiling mode and features
fn find_supported_format(
    candidates: []const c.VkFormat,
    tiling: c.VkImageTiling,
    features: c.VkFormatFeatureFlags,
) !c.VkFormat {
    return for (candidates) |candidate| {
        var props: c.VkFormatProperties = undefined;
        c.vkGetPhysicalDeviceFormatProperties(physical_device, candidate, &props);
        switch (@enumToInt(tiling)) {
            c.VK_IMAGE_TILING_LINEAR => {
                if ((props.linearTilingFeatures & features) == features) break candidate;
            },
            c.VK_IMAGE_TILING_OPTIMAL => {
                if ((props.optimalTilingFeatures & features) == features) break candidate;
            },
            else => break error.VkImageTilingNotSupported,
        }
    } else error.VkFormatNotSupported;
}

fn find_memory_type(type_filter: u32, props: c.VkMemoryPropertyFlags) !u32 {
    const mem_properties = available_gpus[device_index].mem_properties;

    var i: u5 = 0;
    return while (i < mem_properties.memoryTypeCount) : (i += 1) {
        if ((type_filter & (@intCast(u32, 1) << i)) != 0 and
            (mem_properties.memoryTypes[i].propertyFlags & props) == props)
        {
            break i;
        }
    } else error.VkRequestedMemTypeNotFound;
}

/// chooses a depth format, allocates memory for the depth buffer, and creates an image view for it
/// depth buffer gets its own allocation
fn init_depth_resources() !void {
    const depth_format_candidates = [2]c.VkFormat{
        c.VkFormat.VK_FORMAT_D32_SFLOAT_S8_UINT,
        c.VkFormat.VK_FORMAT_D24_UNORM_S8_UINT,
    };

    depth_format = try find_supported_format(
        depth_format_candidates[0..2],
        c.VkImageTiling.VK_IMAGE_TILING_OPTIMAL,
        c.VK_FORMAT_FEATURE_DEPTH_STENCIL_ATTACHMENT_BIT,
    );

    var image_info = std.mem.zeroes(c.VkImageCreateInfo);
    image_info.sType = c.VkStructureType.VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO;
    image_info.imageType = c.VkImageType.VK_IMAGE_TYPE_2D;
    image_info.extent.width = swapchain_extent.width;
    image_info.extent.height = swapchain_extent.height;
    image_info.extent.depth = 1;
    image_info.mipLevels = 1;
    image_info.arrayLayers = 1;
    image_info.format = depth_format;
    image_info.tiling = c.VkImageTiling.VK_IMAGE_TILING_OPTIMAL;
    image_info.usage = c.VK_IMAGE_USAGE_DEPTH_STENCIL_ATTACHMENT_BIT;
    image_info.initialLayout = c.VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED;
    image_info.samples = c.VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT;
    image_info.sharingMode = c.VkSharingMode.VK_SHARING_MODE_EXCLUSIVE;

    try check_success(c.vkCreateImage(logical_device, &image_info, null, &depth_image));

    var mem_requirements: c.VkMemoryRequirements = undefined;
    c.vkGetImageMemoryRequirements(logical_device, depth_image, &mem_requirements);

    const alloc_info = c.VkMemoryAllocateInfo{
        .sType = c.VkStructureType.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
        .allocationSize = mem_requirements.size,
        .memoryTypeIndex = try find_memory_type(
            mem_requirements.memoryTypeBits,
            c.VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
        ),
        .pNext = null,
    };

    try check_success(c.vkAllocateMemory(logical_device, &alloc_info, null, &depth_image_memory));
    try check_success(c.vkBindImageMemory(logical_device, depth_image, depth_image_memory, 0));

    var image_view_info = std.mem.zeroes(c.VkImageViewCreateInfo);
    image_view_info.sType = c.VkStructureType.VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO;
    image_view_info.image = depth_image;
    image_view_info.viewType = c.VkImageViewType.VK_IMAGE_VIEW_TYPE_2D;
    image_view_info.format = depth_format;

    image_view_info.components.r = c.VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY;
    image_view_info.components.g = c.VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY;
    image_view_info.components.b = c.VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY;
    image_view_info.components.a = c.VkComponentSwizzle.VK_COMPONENT_SWIZZLE_IDENTITY;

    image_view_info.subresourceRange.aspectMask = c.VK_IMAGE_ASPECT_DEPTH_BIT;
    image_view_info.subresourceRange.baseMipLevel = 0;
    image_view_info.subresourceRange.levelCount = 1;
    image_view_info.subresourceRange.baseArrayLayer = 0;
    image_view_info.subresourceRange.layerCount = 1;

    try check_success(c.vkCreateImageView(logical_device, &image_view_info, null, &depth_image_view));
}

fn init_render_pass() !void {
    const color_attachment = c.VkAttachmentDescription{
        .format = swapchain_image_format,
        .samples = c.VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT,
        .loadOp = c.VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_CLEAR,
        .storeOp = c.VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_STORE,
        .stencilLoadOp = c.VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        .stencilStoreOp = c.VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_DONT_CARE,
        .initialLayout = c.VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
        .finalLayout = c.VkImageLayout.VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
        .flags = 0,
    };

    const depth_attachment = c.VkAttachmentDescription{
        .format = depth_format,
        .samples = c.VkSampleCountFlagBits.VK_SAMPLE_COUNT_1_BIT,
        .loadOp = c.VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_CLEAR,
        .storeOp = c.VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_STORE,
        .stencilLoadOp = c.VkAttachmentLoadOp.VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        .stencilStoreOp = c.VkAttachmentStoreOp.VK_ATTACHMENT_STORE_OP_DONT_CARE,
        .initialLayout = c.VkImageLayout.VK_IMAGE_LAYOUT_UNDEFINED,
        .finalLayout = c.VkImageLayout.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
        .flags = 0,
    };

    const color_reference = c.VkAttachmentReference{
        .attachment = 0,
        .layout = c.VkImageLayout.VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    };
    const depth_reference = c.VkAttachmentReference{
        .attachment = 1,
        .layout = c.VkImageLayout.VK_IMAGE_LAYOUT_DEPTH_STENCIL_ATTACHMENT_OPTIMAL,
    };

    var subpass = std.mem.zeroes(c.VkSubpassDescription);
    subpass.pipelineBindPoint = c.VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_GRAPHICS;
    subpass.colorAttachmentCount = 1;
    subpass.pColorAttachments = &color_reference;
    subpass.pDepthStencilAttachment = &depth_reference;

    const attachments = [2]c.VkAttachmentDescription{
        color_attachment,
        depth_attachment,
    };

    const dependency = c.VkSubpassDependency{
        .srcSubpass = c.VK_SUBPASS_EXTERNAL,
        .dstSubpass = 0,
        .srcStageMask = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        .srcAccessMask = 0,
        .dstStageMask = c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        .dstAccessMask = c.VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
        .dependencyFlags = 0,
    };

    const render_pass_info = c.VkRenderPassCreateInfo{
        .sType = c.VkStructureType.VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
        .attachmentCount = 2,
        .pAttachments = &attachments,
        .subpassCount = 1,
        .pSubpasses = &subpass,
        .dependencyCount = 1,
        .pDependencies = &dependency,
        .pNext = null,
        .flags = 0,
    };

    try check_success(c.vkCreateRenderPass(logical_device, &render_pass_info, null, &render_pass));
}

/// swapchain framebuffer creation
fn init_framebuffers() !void {
    swapchain_framebuffers = try c_allocator.alloc(c.VkFramebuffer, swapchain_images.len);
    for (swapchain_framebuffers) |*fbuf, i| {
        const fbuf_info = c.VkFramebufferCreateInfo{
            .sType = c.VkStructureType.VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .renderPass = render_pass,
            .attachmentCount = 2,
            .pAttachments = &[2]c.VkImageView{ swapchain_image_views[i], depth_image_view },
            .width = swapchain_extent.width,
            .height = swapchain_extent.height,
            .layers = 1,
        };

        try check_success(c.vkCreateFramebuffer(logical_device, &fbuf_info, null, fbuf));
    }
}

/// initializes synchronization objects for framebuffers
fn init_sync_primitives() !void {
    const semaphore_info = c.VkSemaphoreCreateInfo{
        .sType = c.VkStructureType.VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
    };

    const fence_info = c.VkFenceCreateInfo{
        .sType = c.VkStructureType.VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
        .pNext = null,
        .flags = c.VK_FENCE_CREATE_SIGNALED_BIT,
    };

    var i: u32 = 0;
    while (i < max_frames) : (i += 1) {
        try check_success(c.vkCreateSemaphore(logical_device, &semaphore_info, null, &image_available_semaphores[i]));
        try check_success(c.vkCreateSemaphore(logical_device, &semaphore_info, null, &render_finished_semaphores[i]));
        try check_success(c.vkCreateFence(logical_device, &fence_info, null, &in_flight_fences[i]));
        images_in_flight[i] = std.mem.zeroes(c.VkFence);
    }
}

/// initialize command pool for main thread
/// TODO: multithreading support?
fn init_command_pool() !void {
    const cmd_pool_info = c.VkCommandPoolCreateInfo{
        .sType = c.VkStructureType.VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        .pNext = null,
        .flags = c.VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
        .queueFamilyIndex = graphics_queue_index.?,
    };

    try check_success(c.vkCreateCommandPool(logical_device, &cmd_pool_info, null, &command_pool));
}

/// allocate command buffers
fn init_command_buffers() !void {
    command_buffers = try c_allocator.alloc(c.VkCommandBuffer, swapchain_framebuffers.len);
    errdefer c_allocator.free(command_buffers);

    var alloc_info = std.mem.zeroes(c.VkCommandBufferAllocateInfo);
    alloc_info.sType = c.VkStructureType.VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO;
    alloc_info.commandPool = command_pool;
    alloc_info.level = c.VkCommandBufferLevel.VK_COMMAND_BUFFER_LEVEL_PRIMARY;
    alloc_info.commandBufferCount = @intCast(u32, command_buffers.len);

    try check_success(c.vkAllocateCommandBuffers(logical_device, &alloc_info, command_buffers.ptr));
}

pub fn create_pipeline_cache() !void {
    const pcache_info = c.VkPipelineCacheCreateInfo{
        .sType = c.VkStructureType.VK_STRUCTURE_TYPE_PIPELINE_CACHE_CREATE_INFO,
        .pNext = null,
        .flags = 0,
        .initialDataSize = 0,
        .pInitialData = null,
    };
    try check_success(c.vkCreatePipelineCache(logical_device, &pcache_info, null, &pipeline_cache));
} 

/// for now, this function will permit any graphics device, irrespective of its
/// features or capabilities. this will most likely change in the future to ensure
/// that discrete GPUs are preferred, minimum feature requirements are met, etc.
fn is_device_suitable(candidate: GPU) !bool {
    const extensions_supported = try check_device_extension_support(candidate.physical_device);
    return extensions_supported and candidate.surface_formats.len != 0 and candidate.present_modes.len != 0;
}

fn check_device_extension_support(candidate: c.VkPhysicalDevice) !bool {
    var extension_count: u32 = undefined;
    try check_success(c.vkEnumerateDeviceExtensionProperties(candidate, null, &extension_count, null));

    var available_extensions = try c_allocator.alloc(c.VkExtensionProperties, extension_count);
    defer c_allocator.free(available_extensions);

    try check_success(c.vkEnumerateDeviceExtensionProperties(
        candidate,
        null,
        &extension_count,
        available_extensions.ptr,
    ));

    // naive linear search for supported extensions
    // TODO: make this more efficient if it ever calls for it
    for (device_extensions) |required_extension| {
        for (available_extensions) |available_extension| {
            if (std.cstr.cmp(@ptrCast([*:0]const u8, &available_extension.extensionName), required_extension) == 0) {
                break;
            }
        } else return false; // early out if no match was made for required_extension
    }

    return true;
}

//!
//! drawing subroutines
//!

/// prepare the next frame for drawing: updates current_framebuffer and initiates recording for corresponding
/// command buffer
pub fn begin_frame() !void {
    _ = c.vkWaitForFences(
        logical_device,
        1,
        &in_flight_fences[current_frame],
        c.VK_TRUE,
        std.math.maxInt(u32),
    );

    const r = c.vkAcquireNextImageKHR(
        logical_device,
        swapchain,
        std.math.maxInt(u32),
        image_available_semaphores[current_frame],
        null,
        &current_framebuffer,
    );

    if (r == c.VkResult.VK_ERROR_OUT_OF_DATE_KHR or r == c.VkResult.VK_SUBOPTIMAL_KHR) {
        // TODO: reinitialize back buffers on resize
    } else {
        try check_success(r);
    }

    if (images_in_flight[current_framebuffer] != null) {
        _ = c.vkWaitForFences(
            logical_device,
            1,
            &images_in_flight[current_framebuffer],
            c.VK_TRUE,
            std.math.maxInt(u32),
        );
    }
    images_in_flight[current_framebuffer] = in_flight_fences[current_frame];

    const begin_info = c.VkCommandBufferBeginInfo{
        .sType = c.VkStructureType.VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .pNext = null,
        .flags = 0,
        .pInheritanceInfo = null,
    };

    try check_success(c.vkBeginCommandBuffer(command_buffers[current_frame], &begin_info));

    // TODO: figure out if this is needed
    // const barrier_info = c.VkMemoryBarrier{
    //     .sType = c.VkStructureType.VK_STRUCTURE_TYPE_MEMORY_BARRIER,
    //     .pNext = null,
    //     .srcAccessMask = c.VK_ACCESS_HOST_WRITE_BIT,
    //     .dstAccessMask = c.VK_ACCESS_INDEX_READ_BIT | c.VK_ACCESS_VERTEX_ATTRIBUTE_READ_BIT |
    //         c.VK_ACCESS_SHADER_READ_BIT | c.VK_ACCESS_SHADER_WRITE_BIT |
    //         c.VK_ACCESS_TRANSFER_READ_BIT | c.VK_ACCESS_TRANSFER_WRITE_BIT |
    //         c.VK_ACCESS_UNIFORM_READ_BIT,
    // };
}

/// present the current frame: stop recording to command buffer, wait for target swapchain image to become
/// available, then submit command buffer to queue and present
pub fn end_frame() !void {
    try check_success(c.vkEndCommandBuffer(command_buffers[current_frame]));

    const wait_semaphores = [1]c.VkSemaphore{image_available_semaphores[current_framebuffer]};
    const wait_stages = [1]c.VkPipelineStageFlags{c.VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT};
    const signal_semaphores = [1]c.VkSemaphore{render_finished_semaphores[current_framebuffer]};

    const submit_info = c.VkSubmitInfo{
        .sType = c.VkStructureType.VK_STRUCTURE_TYPE_SUBMIT_INFO,
        .pNext = null,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &wait_semaphores,
        .pWaitDstStageMask = &wait_stages,
        .commandBufferCount = 1,
        .pCommandBuffers = &command_buffers[current_framebuffer],
        .signalSemaphoreCount = 1,
        .pSignalSemaphores = &signal_semaphores,
    };

    _ = c.vkResetFences(logical_device, 1, &in_flight_fences[current_framebuffer]);

    try check_success(c.vkQueueSubmit(graphics_queue, 1, &submit_info, in_flight_fences[current_framebuffer]));

    const swapchains = [1]c.VkSwapchainKHR{swapchain};
    const present_info = c.VkPresentInfoKHR{
        .sType = c.VkStructureType.VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
        .pNext = null,
        .waitSemaphoreCount = 1,
        .pWaitSemaphores = &signal_semaphores,
        .swapchainCount = 1,
        .pSwapchains = &swapchains,
        .pImageIndices = &current_framebuffer,
        .pResults = null,
    };

    const r = c.vkQueuePresentKHR(present_queue, &present_info);

    if (r == c.VkResult.VK_ERROR_OUT_OF_DATE_KHR or r == c.VkResult.VK_SUBOPTIMAL_KHR) {
        // TODO: recreate swapchain
    } else if (r != c.VkResult.VK_SUCCESS) {
        return error.VkPresentFailed;
    }

    current_frame = (current_frame + 1) % max_frames;
}

/// a test which clears the active frame buffer
fn clear_test() !void {
    const clear_colors = [2]c.VkClearValue{
        c.VkClearValue{ .color = c.VkClearColorValue{ .float32 = [4]f32{ 0.0, 0.0, 1.0, 1.0 } } },
        c.VkClearValue{ .depthStencil = c.VkClearDepthStencilValue{ .depth = 0.0, .stencil = 0 } },
    };

    const render_area = c.VkRect2D{
        .offset = c.VkOffset2D{ .x = 0, .y = 0 },
        .extent = swapchain_extent,
    };
    const render_pass_info = c.VkRenderPassBeginInfo{
        .sType = c.VkStructureType.VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
        .pNext = null,
        .renderPass = render_pass,
        .framebuffer = swapchain_framebuffers[current_framebuffer],
        .renderArea = render_area,
        .clearValueCount = 2,
        .pClearValues = &clear_colors,
    };

    c.vkCmdBeginRenderPass(
        command_buffers[current_framebuffer],
        &render_pass_info,
        c.VkSubpassContents.VK_SUBPASS_CONTENTS_INLINE,
    );

    //c.vkCmdBindPipeline(
    //   command_buffers[current_framebuffer],
    //    c.VkPipelineBindPoint.VK_PIPELINE_BIND_POINT_GRAPHICS,
    //    graphics_pipeline,
    //);

    //c.vkCmdDraw(command_buffers[current_framebuffer], 0, 0, 0, 0);

    c.vkCmdEndRenderPass(command_buffers[current_framebuffer]);
}

test "vk: blue screen of life" {
    const app = @import("../app.zig");
    _ = c.glfwInit();
    const window = try app.create_window(app.GraphicsBackend.Vulkan);

    try init(window);
    try begin_frame();

    try clear_test();

    try end_frame();
    deinit();

    c.glfwDestroyWindow(window);
    c.glfwTerminate();
}
