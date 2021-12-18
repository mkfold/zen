//! vulkan memory allocation
//! TODO: allocators for buffer memory, texture memory
//!       - suballocate from large VkDeviceMemory allocations

const c = @import("../../c.zig");
const check_success = @import("../vk.zig").check_success;

pub const VkBuffer = struct {
    buffer: c.VkBuffer,
    memory: c.VkDeviceMemory,
    size: c.VkDeviceSize,
    usage: c.VkBufferUsageFlags,

    pub fn alloc(
        self: VkBuffer,
        size: usize,
    ) !VkBuffer {}
};

pub const VkAllocator = struct {
    instance: c.VkInstance,
    physical_device: c.VkPhysicalDevice,
    device: c.VkDevice,
    mem_properties: c.VkPhysicalDeviceMemoryProperties,

    fn get_memory_type_index(
        mem_properties: c.VkPhysicalDeviceMemoryProperties,
        mem_type: u32,
        properties: c.VkMemoryPropertyFlags,
    ) !u32 {
        var i: u32 = 0;
        while (i < mem_properties.memoryTypeCount) : (i += 1) {
            if ((mem_type & (1 << i)) and (mem_properties.memoryTypes[i].propertyFlags & properties) == properties) {
                return i;
            }
        }
        return error.VkNoSuitableMemoryType;
    }

    pub fn init(
        instance: c.VkInstance,
        device: c.VkDevice,
        physical_device: c.VkPhysicalDevice,
    ) !VkAllocator {
        var mem_properties: c.VkPhysicalDeviceMemoryProperties = undefined;
        c.vkGetPhysicalDeviceMemoryProperties(_device, &mem_properties);
        return VkAllocator{
            .instance = instance,
            .device = device,
            .physical_device = physical_device,
            .mem_properties = mem_properties,
        };
    }

    pub fn alloc(
        self: VkAllocator,
        size: c.VkDeviceSize,
        usage_flags: c.VkBufferUsageFlags,
        share_flags: c.VkSharingMode,
        properties: c.VkMemoryPropertyFlags,
    ) !VkBuffer {
        var allocation: VkBuffer = undefined;
        const buf_create_info = c.VkBufferCreateInfo{
            .sType = c.VkStructureType.VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO,
            .pNext = null,
            .flags = 0,
            .size = size,
            .usage = usage_flags,
            .sharingMode = share_flags,
            .queueFamilyIndexCount = 0,
            .pQueueFamilyIndices = null,
        };

        check_success(c.vkCreateBuffer(
            device,
            &buf_create_info,
            null,
            &allocation.buffer,
        )) catch return error.VkCreateBufferFailed;

        var mem_requirements: c.VkMemoryRequirements = undefined;
        c.vkGetBufferMemoryRequirements(device, allocator.buffer, &mem_requirements);

        const alloc_info = c.VkMemoryAllocateInfo{
            .sType = c.VkStructureType.VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO,
            .pNext = null,
            .allocationSize = mem_requirements.size,
            .memoryTypeIndex = try get_memory_type_index(
                self.mem_properties,
                mem_requirements.memoryTypeBits,
                properties,
            ),
        };

        check_success(c.vkAllocateMemory(
            self.device,
            &alloc_info,
            null,
            &allocation.memory,
        )) catch return error.VkAllocateMemoryFailed;

        allocation.size = size;

        return allocation;
    }

    pub fn free(self: VkAllocator, allocation: VkAllocation) !void {
        c.vkDestroyBuffer(self.device, allocation.buffer, null);
        c.vkFreeMemory(self.device, allocation.memory, null);
    }
};
